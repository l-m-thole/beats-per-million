# Song-library check: row issues, link checks (faked, offline), coverage.

lib_row <- function(song_title = "Song", artist = "Artist", spotify_uri = "",
                    youtube_url = "", soundcloud_url = "", bpm = "100", notes = "") {
  tibble::tibble(song_title, artist, spotify_uri, soundcloud_url, youtube_url, bpm, notes)
}
SP <- "https://open.spotify.com/track/0COqiPhxzoWICwFCS4eZcp"     # 22-char id
YT <- "https://www.youtube.com/watch?v=Yhwal9i1uyw"

test_that("a clean library has no issues", {
  lib <- dplyr::bind_rows(
    lib_row("Bring Me To Life", "Evanescence", spotify_uri = SP, bpm = "95"),
    lib_row("Other Song", "Other Artist", youtube_url = YT, bpm = "120")
  )
  expect_equal(nrow(check_song_library(lib)), 0)
})

test_that("row problems are found and explained", {
  lib <- dplyr::bind_rows(
    lib_row("No BPM", spotify_uri = SP, bpm = ""),                          # line 2
    lib_row("Text BPM", spotify_uri = SP, bpm = "fast"),                    # line 3
    lib_row("Too Fast", spotify_uri = SP, bpm = "164"),                     # line 4
    lib_row("No Link"),                                                     # line 5
    lib_row("Album Link", spotify_uri = "https://open.spotify.com/album/abc"),  # 6
    lib_row("Bad YT", youtube_url = "https://vimeo.com/123"),               # line 7
    lib_row("Blocked", youtube_url = YT),                                   # line 8
    lib_row("", spotify_uri = SP)                                           # line 9
  )
  iss <- check_song_library(lib, blocked_youtube = "Yhwal9i1uyw")
  has <- function(line, issue) any(iss$line == line & iss$issue == issue)

  expect_true(has(2, "missing_bpm"))
  expect_true(has(3, "bpm_not_a_number"))
  expect_true(has(4, "bpm_out_of_range"))
  expect_match(iss$detail[iss$line == 4 & iss$issue == "bpm_out_of_range"], "82 BPM")
  expect_true(has(5, "no_link"))
  expect_true(has(6, "bad_spotify_link"))
  expect_true(has(7, "bad_youtube_link"))
  expect_true(has(8, "youtube_blocked"))
  expect_true(has(9, "missing_title"))
  # errors come first
  expect_equal(iss$severity[1], "error")
  expect_false(is.unsorted(match(iss$severity, c("error", "warning", "info"))))
})

test_that("duplicates: same song, same title, same link", {
  lib <- dplyr::bind_rows(
    lib_row("Hello", "Adele", spotify_uri = SP),
    lib_row("Hello (Remastered)", "ADELE", youtube_url = YT),
    lib_row("Hello", "Lionel Richie", youtube_url = YT)
  )
  iss <- check_song_library(lib)
  expect_equal(sum(iss$issue == "duplicate_song"), 2)       # Adele twice
  expect_true(any(iss$issue == "same_title" & iss$line == 4))
  expect_equal(sum(iss$issue == "duplicate_youtube"), 2)
})

test_that("link check reads oEmbed answers (faked, no network)", {
  lib <- dplyr::bind_rows(
    lib_row("Bring Me To Life", "Evanescence", spotify_uri = SP, youtube_url = YT),
    lib_row("Wrong Song", "X", youtube_url = "https://youtu.be/AAAAAAAAAAA"),
    lib_row("Gone", "Y", youtube_url = "https://youtu.be/BBBBBBBBBBB")
  )
  fake <- function(service, link) {
    if (service == "spotify") return(list(status = 200L, title = "Bring Me To Life"))
    if (grepl("Yhwal9i1uyw", link)) return(list(status = 401L, title = NA))
    if (grepl("AAAAAAAAAAA", link)) return(list(status = 200L, title = "Never Gonna Give You Up"))
    list(status = NA_integer_, title = NA)
  }
  res <- check_song_links(lib, fetch = fake, progress = FALSE)
  expect_equal(nrow(res), 4)
  sp <- res[res$service == "spotify", ]
  expect_true(sp$ok)
  expect_true(sp$title_match)
  blocked <- res[grepl("Yhwal9i1uyw", res$link), ]
  expect_false(blocked$ok)
  expect_match(blocked$detail, "other websites")
  wrong <- res[grepl("AAAAAAAAAAA", res$link), ]
  expect_true(wrong$ok)
  expect_false(wrong$title_match)
  offline <- res[grepl("BBBBBBBBBBB", res$link), ]
  expect_true(is.na(offline$ok))
  expect_true(all(is.na(res$official)))                 # no channel names in this fake
})

test_that("link check flags YouTube uploads from channels that don't look official", {
  lib <- dplyr::bind_rows(
    lib_row("Dancing On My Own", "Robyn", youtube_url = "https://youtu.be/AAAAAAAAAAA"),
    lib_row("Ho Hey", "The Lumineers", youtube_url = "https://youtu.be/BBBBBBBBBBB"),
    lib_row("Titanium", "David Guetta feat. Sia", youtube_url = "https://youtu.be/CCCCCCCCCCC"),
    lib_row("Cheer Up, My Brother", "HNNY", youtube_url = "https://youtu.be/DDDDDDDDDDD",
            notes = "YouTube: label upload (Omena Records)")
  )
  fake <- function(service, link) {
    ch <- c(AAAAAAAAAAA = "7clouds", BBBBBBBBBBB = "The Lumineers",
            CCCCCCCCCCC = "David Guetta", DDDDDDDDDDD = "Omena Records")[[sub(".*v=", "", link)]]
    list(status = 200L, title = "x", author = ch)
  }
  res <- check_song_links(lib, services = "youtube", fetch = fake, progress = FALSE)
  expect_equal(res$channel, c("7clouds", "The Lumineers", "David Guetta", "Omena Records"))
  expect_equal(res$official, c(FALSE, TRUE, TRUE, TRUE))   # label checked by hand (notes)
})

test_that("official channels: Topic, VEVO, or named like the artist", {
  expect_equal(
    youtube_channel_official(
      c("Robyn - Topic", "RobynVEVO", "alt-J", "ratatatmusic", "francisandthelights",
        "7clouds", "Lounge Lyrics", "electronaut", "asiancoverstation", NA, ""),
      c("Robyn", "Robyn", "Alt-J", "Ratatat", "Francis and the Lights",
        "Robyn", "The Lumineers", "Sia", "Sia", "Sia", "Sia")),
    c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, NA, NA))
  expect_equal(youtube_channel_official(character(0), character(0)), logical(0))
})

test_that("pools: one per service, never mixed", {
  lib <- dplyr::bind_rows(
    lib_row("A", spotify_uri = SP, bpm = "100"),
    lib_row("B", youtube_url = YT, bpm = "100"),
    lib_row("C", spotify_uri = SP, youtube_url = "https://youtu.be/CCCCCCCCCCC", bpm = "100"),
    lib_row("D", bpm = "100")                                   # unplayable
  )
  lib$bpm <- as.numeric(lib$bpm)
  p <- library_pools(lib, blocked_youtube = "CCCCCCCCCCC")
  expect_equal(p$spotify$song_title, c("A", "C"))
  expect_equal(p$youtube$song_title, "B")                       # C's video is blocked
  expect_equal(nrow(p$soundcloud), 0)
  expect_setequal(names(p), names(LIBRARY_POOLS))
})

test_that("coverage uses the app's matcher and reports gaps", {
  slots <- tibble::tibble(song_number = 1:4, bpm = c(60, 62, 100, 150))
  pls <- list(per_period = list(test = list(songs = slots)))
  mk <- function(bpm) {
    tibble::tibble(song_title = paste("S", seq_along(bpm)), artist = "A",
                   spotify_uri = SP, soundcloud_url = NA_character_,
                   youtube_url = NA_character_, bpm = bpm, notes = NA_character_)
  }
  pools <- list(good = mk(c(59, 61, 63, 64, 100, 101, 102, 148, 149, 150)),
                thin = mk(c(100)),
                empty = mk(numeric(0)))
  cov <- library_coverage(pls, pools, shuffles = 0:1)

  good <- cov[cov$pool == "good", ]
  expect_true(all(good$status == "within 3"))
  expect_true(all(good$good_match))
  expect_true(all(good$choice >= 3))

  # one song: the first slot takes it as its "nearest" match, the rest get none
  # (the matcher walks the slots in order and never repeats a song)
  thin <- cov[cov$pool == "thin", ]
  expect_equal(thin$status, c("nearest", "none", "none", "none"))

  expect_true(all(cov$status[cov$pool == "empty"] == "none"))

  gaps <- library_gaps(cov, pools, variety = 3)
  g60 <- gaps[gaps$pool == "thin" & gaps$bin == "60-64", ]
  expect_equal(g60$busiest, 2L)
  expect_gte(g60$add_at_least, 2)
  expect_equal(gaps$add_at_least[gaps$pool == "good" & gaps$bin == "60-64"], 0)

  v_good <- library_verdict(tibble::tibble(line = integer(), severity = character()),
                            cov, pool = "good")
  expect_true(v_good$ready)
  v_thin <- library_verdict(tibble::tibble(line = 5L, severity = "error"), cov, pool = "thin")
  expect_false(v_thin$ready)
  expect_length(v_thin$lines, 3)
})

test_that("match_status names the narrowest window that holds the gap", {
  expect_equal(match_status(c(0, 3, 3.5, 5, 7, 10, 12, NA)),
               c("within 3", "within 3", "within 5", "within 5", "within 10", "within 10",
                 "nearest", "none"))
  expect_equal(match_status(c(4, 6), tols = c(5, 10)), c("within 5", "within 10"))
})

test_that("a pool that only reaches ±5 BPM counts as falling back from ±3", {
  slots <- tibble::tibble(song_number = 1:4, bpm = c(60, 62, 100, 150))
  pls <- list(per_period = list(test = list(songs = slots)))
  lib <- tibble::tibble(song_title = paste("S", 1:4), artist = "A", spotify_uri = SP,
                        soundcloud_url = NA_character_, youtube_url = NA_character_,
                        bpm = c(56, 66, 96, 146), notes = NA_character_)   # all 4 BPM off
  pools <- list(spotify = lib)
  cov <- library_coverage(pls, pools, shuffles = 0:1)
  expect_equal(cov$status, rep("within 5", 4))
  expect_false(any(cov$good_match))
  expect_equal(cov$worst_gap, rep(4, 4))

  s <- coverage_summary(cov)
  expect_equal(c(s$good_matches, s$fallbacks, s$wide, s$pct_good), c(0, 4, 0, 0))

  v <- library_verdict(tibble::tibble(line = integer(), severity = character()), cov,
                       pool = "spotify")
  expect_false(v$ready)
  expect_match(v$lines[2], "4 of 4 slots fall back to ±5 BPM or wider", fixed = TRUE)
  expect_match(v$lines[3], "within ±3 BPM", fixed = TRUE)

  g <- library_gaps(cov, pools)
  expect_equal(g$fallbacks[g$bin == "60-64"], 2L)       # both slow slots need songs
})

test_that("identical pools are simulated once but reported for both names", {
  slots <- tibble::tibble(song_number = 1:2, bpm = c(90, 110))
  pls <- list(per_period = list(test = list(songs = slots)))
  lib <- tibble::tibble(song_title = c("a", "b"), artist = "x", spotify_uri = SP,
                        soundcloud_url = NA_character_, youtube_url = NA_character_,
                        bpm = c(90, 110), notes = NA_character_)
  cov <- library_coverage(pls, list(spotify = lib, all = lib), shuffles = 0)
  expect_setequal(unique(cov$pool), c("spotify", "all"))
  expect_equal(cov$status[cov$pool == "spotify"], cov$status[cov$pool == "all"])

  # several shuffles + a different pool in between: the copy still comes from the
  # right pool (the shuffle loop used to overwrite the pool index)
  other <- lib
  other$bpm <- c(60, 150)
  cov <- library_coverage(pls, list(spotify = lib, youtube = other, all = lib), shuffles = 0:2)
  expect_equal(nrow(cov), 6)
  expect_equal(cov$status[cov$pool == "all"], cov$status[cov$pool == "spotify"])
  expect_equal(cov$worst_gap[cov$pool == "all"], c(0, 0))
})
