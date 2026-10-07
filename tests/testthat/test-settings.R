# App settings from environment variables, deployed detection, URL flags.

test_that("deployed is detected from the host's environment, and can be forced", {
  withr::with_envvar(c(BPM_DEPLOYED = "", SHINY_PORT = "", R_CONFIG_ACTIVE = ""),
                     expect_false(bpm_is_deployed()))
  withr::with_envvar(c(BPM_DEPLOYED = "", SHINY_PORT = "39123", R_CONFIG_ACTIVE = ""),
                     expect_true(bpm_is_deployed()))
  withr::with_envvar(c(BPM_DEPLOYED = "", SHINY_PORT = "", R_CONFIG_ACTIVE = "shinyapps"),
                     expect_true(bpm_is_deployed()))
  withr::with_envvar(c(BPM_DEPLOYED = "false", SHINY_PORT = "39123"),
                     expect_false(bpm_is_deployed()))
  withr::with_envvar(c(BPM_DEPLOYED = "true", SHINY_PORT = ""),
                     expect_true(bpm_is_deployed()))
})

test_that("defaults: Spotify player; login for everyone locally, testers only when deployed", {
  withr::with_envvar(c(BPM_DEFAULT_PLAYER = "", BPM_SPOTIFY_LOGIN = "", BPM_CONTACT = ""), {
    local <- app_settings(deployed = FALSE)
    srv   <- app_settings(deployed = TRUE)
  })
  expect_equal(local$default_player, "spotify")
  expect_equal(local$spotify_login, "on")
  expect_equal(srv$spotify_login, "testers")
  expect_equal(srv$contact, "")
})

test_that("settings are read from the environment; bad values fall back with a warning", {
  withr::with_envvar(c(BPM_DEFAULT_PLAYER = "YouTube", BPM_SPOTIFY_LOGIN = "off",
                       BPM_CONTACT = " me@example.org "), {
    s <- app_settings(deployed = TRUE)
  })
  expect_equal(s$default_player, "youtube")
  expect_equal(s$spotify_login, "off")
  expect_equal(s$contact, "me@example.org")

  withr::with_envvar(c(BPM_DEFAULT_PLAYER = "napster"), {
    expect_warning(s2 <- app_settings(deployed = FALSE), "not one of")
  })
  expect_equal(s2$default_player, "spotify")
})

test_that("who sees Connect Spotify", {
  expect_true(spotify_login_visible("on"))
  expect_false(spotify_login_visible("off"))
  expect_false(spotify_login_visible("testers"))
  expect_true(spotify_login_visible("testers", tester = TRUE))
  expect_false(spotify_login_visible("off", tester = TRUE))
  expect_true(spotify_login_visible("off", connected = TRUE))   # can always disconnect
})

test_that("URL flags: ?testers, ?player=, ?about", {
  f <- url_flags(shiny::parseQueryString("?testers&player=YouTube&about"))
  expect_true(f$tester)
  expect_equal(f$player, "youtube")
  expect_true(f$about)

  none <- url_flags(list())
  expect_false(none$tester)
  expect_null(none$player)
  expect_false(none$about)

  expect_null(url_flags(list(player = "winamp"))$player)
})
