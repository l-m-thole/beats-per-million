# Album covers: oEmbed parsing, the cache file, fallbacks. No network: the
# fetch step is replaced by a fake.

fake_fetch <- function(found) {
  calls <- new.env()
  calls$asked <- character(0)
  f <- function(ids) {
    calls$asked <- c(calls$asked, ids)
    stats::setNames(unname(found[ids]), ids)    # NA for ids not in `found`
  }
  list(fetch = f, calls = calls)
}

lib <- tibble::tibble(
  song_title  = c("a", "b", "c", "d"),
  spotify_uri = c("spotify:track:AAA", "https://open.spotify.com/track/BBB?si=x", NA, "spotify:track:DDD"),
  youtube_url = c(NA, NA, "https://youtu.be/dQw4w9WgXcQ", "https://youtu.be/qDneDYFM3fk")
)

test_that("the cover address comes from oEmbed's thumbnail_url", {
  expect_equal(oembed_thumbnail(list(thumbnail_url = "https://i.scdn.co/image/abc")),
               "https://i.scdn.co/image/abc")
  expect_true(is.na(oembed_thumbnail(list(title = "no thumbnail"))))
  expect_true(is.na(oembed_thumbnail(list(thumbnail_url = "javascript:alert(1)"))))
  expect_true(is.na(oembed_thumbnail(NULL)))
})

test_that("update_cover_cache fetches only what's missing and saves it", {
  path <- withr::local_tempfile(fileext = ".csv")
  ff <- fake_fetch(c(AAA = "https://img/a", BBB = "https://img/b"))
  cache <- update_cover_cache(lib, path, fetch = ff$fetch)
  expect_setequal(ff$calls$asked, c("AAA", "BBB", "DDD"))
  expect_equal(cache[["AAA"]], "https://img/a")
  expect_equal(attr(cache, "missing"), "DDD")           # not found -> asked again next time
  expect_equal(read_cover_cache(path)[c("AAA", "BBB")], c(AAA = "https://img/a", BBB = "https://img/b"))

  ff2 <- fake_fetch(c(DDD = "https://img/d"))
  cache2 <- update_cover_cache(lib, path, fetch = ff2$fetch)
  expect_equal(ff2$calls$asked, "DDD")
  expect_length(cache2, 3)

  # songs removed from the library leave the file
  cache3 <- update_cover_cache(lib[1, ], path, fetch = fake_fetch(character(0))$fetch)
  expect_equal(names(read_cover_cache(path)), "AAA")

  # refetch = TRUE asks again for everything
  ff4 <- fake_fetch(c(AAA = "https://img/a2"))
  update_cover_cache(lib[1, ], path, refetch = TRUE, fetch = ff4$fetch)
  expect_equal(ff4$calls$asked, "AAA")
  expect_equal(read_cover_cache(path)[["AAA"]], "https://img/a2")
})

test_that("a missing or broken cache file means no covers, not an error", {
  expect_length(read_cover_cache(file.path(tempdir(), "nope.csv")), 0)
  bad <- withr::local_tempfile(fileext = ".csv")
  writeLines("x,y\n1,2", bad)
  expect_length(read_cover_cache(bad), 0)
})

test_that("covers: only Spotify covers from the cache - never YouTube thumbnails", {
  cache <- c(AAA = "https://img/a")
  out <- song_cover_urls(lib$spotify_uri, cache)
  expect_equal(out, c("https://img/a", NA, NA, NA))
  expect_false(any(grepl("ytimg", out)))
  expect_equal(song_cover_urls(character(0)), character(0))
})

test_that("the app's cover store looks each missing cover up only once", {
  path <- withr::local_tempfile(fileext = ".csv")
  write_cover_cache(c(AAA = "https://img/a"), path)
  st <- cover_store(path)
  ff <- fake_fetch(c(BBB = "https://img/b"))
  out <- store_cover_urls(st, lib, fetch = ff$fetch)
  expect_setequal(ff$calls$asked, c("BBB", "DDD"))
  expect_equal(out[1:2], c("https://img/a", "https://img/b"))
  store_cover_urls(st, lib, fetch = ff$fetch)           # nothing new to ask
  expect_length(ff$calls$asked, 2)
  # cache only (fetch = NULL) never asks
  expect_equal(store_cover_urls(cover_store(path), lib, fetch = NULL)[2], NA_character_)
})
