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

test_that("login state must be one the app handed out", {
  expect_error(spotify_complete_login("code", "bad"), "state mismatch")
  expect_error(spotify_complete_login("code", NULL), "state mismatch")
  expect_error(spotify_complete_login("code", ""), "state mismatch")
})

test_that("login states are random, single-use, expire, and remember ?testers", {
  withr::with_envvar(c(SPOTIFY_CLIENT_ID = "CID"), {
    u1 <- spotify_begin_login()
    u2 <- spotify_begin_login(tester = TRUE)
  })
  s1 <- sub(".*[?&]state=([^&]+).*", "\\1", u1)
  s2 <- sub(".*[?&]state=([^&]+).*", "\\1", u2)
  expect_match(s1, "^[0-9a-f]{32}$")
  expect_false(identical(s1, s2))
  expect_false(get(s1, envir = .spotify_logins)$tester)
  expect_true(get(s2, envir = .spotify_logins)$tester)
  expect_false(spotify_login_tester(s1))
  expect_true(spotify_login_tester(s2))
  expect_false(spotify_login_tester("unknown"))
  expect_false(spotify_login_tester(NULL))

  # set.seed() (used for the song picks) must not make states predictable
  set.seed(1); a <- spotify_random_state()
  set.seed(1); b <- spotify_random_state()
  expect_false(identical(a, b))

  # expired: refused and forgotten (no network call is made before the check)
  assign(s1, list(time = as.numeric(Sys.time()) - SPOTIFY_LOGIN_TTL - 1, tester = FALSE),
         envir = .spotify_logins)
  expect_error(spotify_complete_login("code", s1), "expired")
  rm(list = intersect(c(s1, s2), ls(.spotify_logins)), envir = .spotify_logins)
})

test_that("deployed: every session gets its own token store; local: one shared store", {
  s1 <- list(userData = new.env())
  s2 <- list(userData = new.env())
  a <- spotify_session_store(s1, deployed = TRUE)
  b <- spotify_session_store(s2, deployed = TRUE)
  expect_false(identical(a, b))
  expect_identical(spotify_session_store(s1, deployed = TRUE), a)   # stable per session
  expect_identical(spotify_session_store(s1, deployed = FALSE), .spotify)

  # a token in one visitor's store is invisible to another visitor
  withr::with_envvar(c(SPOTIFY_CLIENT_ID = "CID", SPOTIFY_CLIENT_SECRET = "SECRET",
                       BPM_DEPLOYED = "true"), {
    a$token <- list(access_token = "visitor-A", expires_at = as.numeric(Sys.time()) + 3600)
    expect_equal(spotify_access_token(a), "visitor-A")
    expect_null(spotify_access_token(b))
    expect_gt(spotify_token_expires_in(a), 3500)
    expect_equal(spotify_token_expires_in(b), 0)
    spotify_forget_login(a)
    expect_null(spotify_access_token(a))
  })
})

test_that("only the local store is written to disk", {
  withr::with_envvar(c(BPM_DEPLOYED = "false"), {
    expect_true(.spotify_persist(.spotify))
    expect_false(.spotify_persist(spotify_new_store()))
  })
  withr::with_envvar(c(BPM_DEPLOYED = "true"), {
    expect_false(.spotify_persist(.spotify))
  })
})
