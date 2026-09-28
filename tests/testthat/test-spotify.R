# Offline tests for the Spotify helpers (no network, no keys).

test_that("authorize URL carries client id, loopback redirect, scopes and state", {
  u <- spotify_authorize_url("abc123", client_id = "CID",
                             redirect_uri = "http://127.0.0.1:4321/",
                             scopes = c("streaming", "playlist-modify-private"))
  expect_match(u, "^https://accounts.spotify.com/authorize\\?")
  expect_match(u, "client_id=CID", fixed = TRUE)
  expect_match(u, "redirect_uri=http%3A%2F%2F127.0.0.1%3A4321%2F", fixed = TRUE)
  expect_match(u, "scope=streaming%20playlist-modify-private", fixed = TRUE)
  expect_match(u, "state=abc123", fixed = TRUE)
})

test_that("picks become ordered, de-duplicated Spotify URIs", {
  picks <- tibble::tibble(
    song_number = c(3, 1, 2, 4),
    spotify_uri = c("https://open.spotify.com/track/CCC?si=x", "spotify:track:AAA",
                    NA, "AAA")
  )
  expect_equal(picks_to_spotify_uris(picks),
               c("spotify:track:AAA", "spotify:track:CCC"))
  expect_equal(picks_to_spotify_uris(picks[0, ]), character())
  expect_equal(picks_to_spotify_uris(NULL), character())
})

test_that("login state must match", {
  .spotify$state <- "good"
  expect_error(spotify_complete_login("code", "bad"), "state mismatch")
})
