# The app's server logic (app.R) with shiny::testServer: when a new song may
# start by itself, Previous / Next, the playlist table, and how a song was
# picked. Loads the real data, so it takes a few seconds.

app_root <- function() {
  for (d in c(file.path("..", ".."), ".", "..")) {
    if (file.exists(file.path(d, "app.R"))) return(normalizePath(d))
  }
  NULL
}

autoplay_attr <- function(html) {
  m <- regmatches(html, regexpr('data-autoplay="[a-z]+"', html))
  if (length(m)) sub('.*="([a-z]+)"', "\\1", m) else NA_character_
}

test_that("playback, Previous/Next and the playlist table behave", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("DT")
  root <- app_root()
  skip_if(is.null(root), "app.R not found")
  # deployed mode: in-memory Spotify login, so no cached login is touched
  withr::local_envvar(BPM_DEPLOYED = "true", BPM_SPOTIFY_LOGIN = "off")
  app <- suppressMessages(suppressWarnings(shiny::shinyAppDir(root)))

  shiny::testServer(app, {
    session$setInputs(selected_period = "modern", scaling_mode = "per_period",
                      play_source = "spotify", auto_advance = TRUE,
                      play_length = "full", show_covers = FALSE)
    tok <- function() player_token()
    expect_equal(selected_idx(), 1L)
    expect_false(listening())

    # play / pause in the player
    session$setInputs(player_state = list(token = tok(), playing = TRUE, t = 1))
    expect_true(listening())
    session$setInputs(player_state = list(token = tok(), playing = FALSE, t = 2))
    expect_false(listening())

    # Feedback bug: stopped + "auto-play" off, then another era -> nothing starts
    session$setInputs(auto_advance = FALSE)
    session$setInputs(selected_period = "roman")
    expect_equal(selected_idx(), 1L)
    expect_equal(autoplay_attr(as.character(output$music_panel$html)), "false")

    # while music plays, Next starts the next song
    session$setInputs(player_state = list(token = tok(), playing = TRUE, t = 3))
    session$setInputs(next_song = 1)
    expect_equal(selected_idx(), 2L)
    expect_equal(autoplay_attr(as.character(output$music_panel$html)), "true")
    session$setInputs(prev_song = 1)
    expect_equal(selected_idx(), 1L)
    session$setInputs(prev_song = 2)            # already at the first song
    expect_equal(selected_idx(), 1L)

    # a song ends: auto-play off -> stop; on -> next song, still playing
    session$setInputs(player_ended = list(token = tok(), t = 4))
    expect_equal(selected_idx(), 1L)
    expect_false(listening())
    session$setInputs(auto_advance = TRUE)
    session$setInputs(player_state = list(token = tok(), playing = TRUE, t = 5))
    session$setInputs(player_ended = list(token = tok(), t = 6))
    expect_equal(selected_idx(), 2L)
    expect_true(listening())

    # events from a player that is being torn down are ignored
    session$setInputs(player_state = list(token = "old|token", playing = FALSE, t = 7))
    expect_true(listening())

    # table click selects (not a row number outside the playlist); Next stops
    # at the last song
    session$setInputs(playlist_row_click = list(row = 5, t = 1))
    expect_equal(selected_idx(), 5L)
    session$setInputs(playlist_row_click = list(row = 999, t = 2))
    expect_equal(selected_idx(), 5L)
    n <- nrow(current_playlist()$songs)
    expect_equal(output$song_position, paste(5, "/", n))
    selected_idx(n)
    session$setInputs(next_song = 2)
    expect_equal(selected_idx(), n)

    # the table: Song first, both tempos, Feel instead of Mood
    d <- playlist_display()
    expect_equal(names(d), c("#", "Song", "Years", "CO₂ ppm", "BPM", "Song BPM", "Feel"))
    expect_true(all(d$Feel %in% TEMPO_FEELS$feel))
    expect_match(d$Song[1], "song-title", fixed = TRUE)

    # every matched song says how it was found
    pk <- curated_picks()
    expect_true(all(c("match_tol", "n_candidates") %in% names(pk)))
    expect_true(all(pk$n_candidates >= 1))
  })
})

test_that("one service per playlist; players wait behind the Play gate", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("DT")
  root <- app_root()
  skip_if(is.null(root), "app.R not found")
  withr::local_envvar(BPM_DEPLOYED = "true", BPM_SPOTIFY_LOGIN = "off")
  app <- suppressMessages(suppressWarnings(shiny::shinyAppDir(root)))

  shiny::testServer(app, {
    session$setInputs(selected_period = "modern", scaling_mode = "per_period",
                      play_source = "spotify", auto_advance = TRUE,
                      play_length = "full", show_covers = FALSE)
    has <- function(col) !is.na(curated_picks()[[col]]) & nzchar(curated_picks()[[col]])

    # Spotify: Spotify songs only, Spotify's gate, no player loaded yet
    expect_true(all(has("spotify_uri")))
    html <- as.character(output$music_panel$html)
    expect_match(html, 'class="player-gate"', fixed = TRUE)
    expect_match(html, 'data-service="spotify"', fixed = TRUE)
    expect_match(html, "Play via Spotify", fixed = TRUE)
    expect_no_match(html, "<iframe", fixed = TRUE)
    expect_no_match(html, "open.spotify.com/embed", fixed = TRUE)

    # YouTube: YouTube songs only - and no Spotify covers next to YouTube
    session$setInputs(play_source = "youtube", show_covers = TRUE)
    expect_true(all(!is.na(vapply(curated_picks()$youtube_url, parse_youtube_id,
                                  character(1)))))
    html <- as.character(output$music_panel$html)
    expect_match(html, 'data-service="youtube"', fixed = TRUE)
    expect_match(html, "youtube.com/t/terms", fixed = TRUE)
    expect_null(covers())

    # a YouTube video that fails: never another service; skip only while
    # music is meant to play
    tok <- player_token()
    vid <- parse_youtube_id(selected_curated()$youtube_url)
    session$setInputs(yt_error = list(token = tok, code = 5, id = vid, autoplay = FALSE))
    expect_equal(selected_idx(), 1L)                      # stopped: stays
    html <- as.character(output$music_panel$html)
    expect_match(html, "can't be played via YouTube here", fixed = TRUE)
    expect_no_match(html, "bpm-spotify", fixed = TRUE)
    session$setInputs(next_song = 1)
    tok <- player_token()
    vid <- parse_youtube_id(selected_curated()$youtube_url)
    session$setInputs(yt_error = list(token = tok, code = 5, id = vid, autoplay = TRUE))
    expect_equal(selected_idx(), 3L)                      # meant to play: next song
    expect_true(listening())
  })
})

test_that("opening the page loads nothing from other sites", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("DT")
  root <- app_root()
  skip_if(is.null(root), "app.R not found")
  withr::local_envvar(BPM_DEPLOYED = "true", BPM_SPOTIFY_LOGIN = "off")
  env <- new.env()
  withr::with_dir(root, suppressMessages(suppressWarnings(
    sys.source(file.path(root, "app.R"), envir = env))))
  page <- htmltools::renderTags(env$ui)
  head <- paste(as.character(page$head), collapse = "\n")
  body <- paste(as.character(page$html), collapse = "\n")

  # no fonts, styles or scripts from Google, Spotify, YouTube or SoundCloud
  expect_no_match(head, paste0("googleapis\\.com|gstatic\\.com|scdn\\.co|spotify\\.com|",
                               "youtube\\.com|youtube-nocookie\\.com|soundcloud\\.com"))
  expect_no_match(paste(head, body), '(src|href)="https?://[^"]+\\.(js|css)', perl = TRUE)
  expect_no_match(body, "<iframe", fixed = TRUE)
  expect_match(head, "fonts/fonts.css?v=", fixed = TRUE)
  expect_match(head, "player.js?v=", fixed = TRUE)

  # "Best available" (which mixed services) is gone
  expect_false("auto" %in% env$PLAY_VIA_CHOICES)
  expect_true(env$DEFAULT_PLAYER %in% env$PLAY_VIA_CHOICES)
  expect_true(file.exists(file.path(root, "www", "fonts", "fonts.css")))
})
