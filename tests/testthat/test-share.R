# Link previews, the "Suggest a song" link, and the tempos that need songs.

test_that("link previews: title, text and an absolute image address", {
  html <- as.character(social_meta_tags("https://example.shinyapps.io/dance/"))
  expect_match(html, 'property="og:title" content="Beats per Million', fixed = TRUE)
  expect_match(html, 'property="og:description"', fixed = TRUE)
  expect_match(html, 'property="og:image" content="https://example.shinyapps.io/dance/og-image.png"',
               fixed = TRUE)
  expect_match(html, 'property="og:url" content="https://example.shinyapps.io/dance/"', fixed = TRUE)
  expect_match(html, 'name="twitter:card" content="summary_large_image"', fixed = TRUE)

  # with or without the trailing slash
  expect_match(as.character(social_meta_tags("https://example.shinyapps.io/dance")),
               "https://example.shinyapps.io/dance/og-image.png", fixed = TRUE)

  # locally (address unknown): same tags, relative image, no og:url
  local <- as.character(social_meta_tags(""))
  expect_match(local, 'property="og:image" content="og-image.png"', fixed = TRUE)
  expect_no_match(local, "og:url", fixed = TRUE)
})

test_that("the preview image exists and is 1200 x 630, as the tags say", {
  img <- test_path("..", "..", "www", OG_IMAGE)
  skip_if_not(file.exists(img), "www/og-image.png not made yet")
  con <- file(img, "rb")
  on.exit(close(con))
  hdr <- readBin(con, "raw", 24)
  expect_equal(rawToChar(hdr[2:4]), "PNG")
  px <- function(b) sum(as.integer(b) * 256^(3:0))     # IHDR: width, height
  expect_equal(c(px(hdr[17:20]), px(hdr[21:24])), c(1200, 630))
})

test_that("Suggest a song: a form if set, else a pre-filled email, else nothing", {
  form <- suggest_song_link(list(suggest_url = "https://forms.example/x",
                                 contact = "me@example.org"))
  expect_equal(form$href, "https://forms.example/x")
  expect_true(form$external)

  mail <- suggest_song_link(list(suggest_url = "", contact = " me@example.org "))
  expect_match(mail$href, "^mailto:me@example\\.org\\?subject=Song%20suggestion")
  expect_match(mail$href, "&body=Song%3A%0AArtist%3A%0ALink", fixed = TRUE)
  expect_false(mail$external)

  expect_equal(suggest_song_link(list(contact = "https://example.org/contact"))$href,
               "https://example.org/contact")
  expect_null(suggest_song_link(list(contact = "")))
  expect_null(suggest_song_link(list(contact = "ask at the desk")))

  expect_null(suggest_song_tag(list(contact = "")))
  tag <- as.character(suggest_song_tag(list(suggest_url = "https://forms.example/x")))
  expect_match(tag, 'target="_blank"', fixed = TRUE)
  expect_match(tag, "Suggest a song", fixed = TRUE)
})

test_that("the song pool follows the player visitors start with", {
  expect_equal(pool_for_player("spotify"), "spotify")
  expect_equal(pool_for_player("YouTube"), "youtube")
  expect_equal(pool_for_player("soundcloud"), "soundcloud")
  expect_equal(pool_for_player(NULL), "spotify")       # the default player
  expect_true(all(c("spotify", "youtube", "soundcloud") %in% names(LIBRARY_POOLS)))
})

gap_rows <- function(pool, bin, add) tibble::tibble(pool = pool, bin = bin, add_at_least = add)

test_that("touching BPM bins merge into ranges; zeros and other pools are ignored", {
  gaps <- dplyr::bind_rows(
    gap_rows("spotify", c("65-69", "60-64", "70-74", "100-104", "145-150"),
             c(2L, 1L, 0L, 3L, 1L)),
    gap_rows("youtube", "80-84", 9L))
  r <- wanted_bpm_ranges(gaps, "spotify")
  expect_equal(r$lo, c(60, 100, 145))
  expect_equal(r$hi, c(69, 104, 150))
  expect_equal(r$add, c(3L, 3L, 1L))
  expect_equal(wanted_bpm_labels(r),
               c("60–69 BPM (slow)", "100–104 BPM (mid-tempo)", "145–150 BPM (fast)"))

  expect_equal(nrow(wanted_bpm_ranges(gap_rows("spotify", "60-64", 0L))), 0)
  expect_equal(nrow(wanted_bpm_ranges(NULL)), 0)
  expect_equal(wanted_bpm_labels(wanted_bpm_ranges(NULL)), character(0))
})

test_that("wanted ranges come straight from the library check's gaps", {
  sp <- "https://open.spotify.com/track/0COqiPhxzoWICwFCS4eZcp"
  slots <- tibble::tibble(song_number = 1:4, bpm = c(60, 62, 100, 150))
  pls <- list(per_period = list(test = list(songs = slots)))
  lib <- tibble::tibble(song_title = paste("S", 1:4), artist = "A", spotify_uri = sp,
                        soundcloud_url = NA_character_, youtube_url = NA_character_,
                        bpm = c(100, 101, 102, 149), notes = NA_character_)
  pools <- list(spotify = lib)
  gaps <- library_gaps(library_coverage(pls, pools, shuffles = 0), pools)
  r <- wanted_bpm_ranges(gaps, "spotify")
  expect_equal(r$lo[1], 60)        # nothing near 60 BPM in this library
  expect_false(any(r$lo <= 100 & r$hi >= 100 & r$hi < 105))   # 100-104 is well stocked
})

test_that("wanted tempos survive the round trip through data/wanted_bpm.csv", {
  path <- withr::local_tempfile(fileext = ".csv")
  expect_null(read_wanted_bpms(path))                      # not worked out yet

  r <- wanted_bpm_ranges(gap_rows("spotify", c("60-64", "65-69"), c(1L, 2L)))
  write_wanted_bpms(r, "spotify", path)
  back <- read_wanted_bpms(path)
  expect_equal(back$lo, 60)
  expect_equal(back$hi, 69)
  expect_equal(back$add, 3L)
  expect_equal(back$pool, "spotify")

  write_wanted_bpms(wanted_bpm_ranges(NULL), "spotify", path)   # every tempo covered
  none <- read_wanted_bpms(path)
  expect_false(is.null(none))
  expect_equal(nrow(none), 0)

  writeLines("not,a,wanted,file", path)
  expect_null(read_wanted_bpms(path))
})
