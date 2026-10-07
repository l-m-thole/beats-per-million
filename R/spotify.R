# =============================================================================
# SPOTIFY: LOGIN, IN-APP PLAYBACK TOKEN, PLAYLIST EXPORT
# =============================================================================
#
# Needs a Spotify developer app (https://developer.spotify.com/dashboard):
#   - .Renviron: SPOTIFY_CLIENT_ID=..., SPOTIFY_CLIENT_SECRET=...
#   - In the app's settings add the Redirect URI exactly:  http://127.0.0.1:4321/
#     (Spotify no longer accepts "localhost"; the app runs on port 4321.)
#     A deployed copy also needs its own https://... address there, and
#     SPOTIFY_REDIRECT_URI set to it (deploy/deploy_shinyapps.R does that).
#   - Development-mode apps need the app owner to have Spotify Premium, allow
#     max. 5 Spotify accounts (dashboard -> User Management), and the in-app
#     player (Web Playback SDK) needs the listener to have Premium.
#
# Login is a standard Authorization Code flow handled by the Shiny app itself:
# the browser goes to Spotify, Spotify redirects back to the app with ?code=,
# the app swaps the code for tokens.
#
# WHERE TOKENS LIVE
#   Local (your laptop, one user): one process-wide store, and the refresh
#     token is cached on disk (outside the repo) so you only log in once.
#   Deployed (a server, many visitors): one store PER BROWSER SESSION, kept in
#     memory only. Otherwise every visitor would be playing - and saving
#     playlists - with the account of whoever logged in last.
# =============================================================================

SPOTIFY_PORT         <- 4321L
SPOTIFY_REDIRECT_URI <- Sys.getenv("SPOTIFY_REDIRECT_URI",
                                   paste0("http://127.0.0.1:", SPOTIFY_PORT, "/"))
SPOTIFY_SCOPES <- c(
  "streaming", "user-read-email", "user-read-private",          # Web Playback SDK
  "user-modify-playback-state", "user-read-playback-state",     # start a track
  "playlist-modify-private", "playlist-modify-public"           # export
)
SPOTIFY_LOGIN_TTL <- 15 * 60   # seconds a started login stays valid

spotify_new_store <- function() new.env(parent = emptyenv())

# The local, process-wide token store (single-user app on your machine)
.spotify <- spotify_new_store()

# Logins in progress: state -> list(time, tester). Shared by all sessions,
# because Spotify's redirect back to the app starts a NEW Shiny session.
.spotify_logins <- new.env(parent = emptyenv())

#' The token store for a Shiny session
#'
#' @param session Shiny session (needs $userData)
#' @param deployed Running on a server? Then each session gets its own store.
spotify_session_store <- function(session, deployed = bpm_is_deployed()) {
  if (!isTRUE(deployed)) return(.spotify)
  if (is.null(session$userData$spotify)) {
    session$userData$spotify <- spotify_new_store()
  }
  session$userData$spotify
}

# Only the local store is ever written to disk
.spotify_persist <- function(store) identical(store, .spotify) && !bpm_is_deployed()

spotify_configured <- function() {
  nzchar(Sys.getenv("SPOTIFY_CLIENT_ID")) && nzchar(Sys.getenv("SPOTIFY_CLIENT_SECRET"))
}

spotify_token_file <- function() {
  file.path(tools::R_user_dir("beats_per_million", "cache"), "spotify_token.rds")
}

#' Spotify authorize URL for the Authorization Code flow
spotify_authorize_url <- function(state,
                                  client_id    = Sys.getenv("SPOTIFY_CLIENT_ID"),
                                  redirect_uri = SPOTIFY_REDIRECT_URI,
                                  scopes       = SPOTIFY_SCOPES) {
  q <- c(client_id = client_id, response_type = "code",
         redirect_uri = redirect_uri, scope = paste(scopes, collapse = " "),
         state = state, show_dialog = "false")
  paste0("https://accounts.spotify.com/authorize?",
         paste0(names(q), "=", vapply(q, utils::URLencode, "", reserved = TRUE),
                collapse = "&"))
}

#' Unguessable login `state` (CSRF protection)
#'
#' Uses openssl (installed with httr2) rather than sample(): the app calls
#' set.seed() for the song picks, which would make sample() predictable.
spotify_random_state <- function(bytes = 16) {
  paste(as.character(openssl::rand_bytes(bytes)), collapse = "")
}

#' Start a login: remember its state, return the Spotify URL to send the browser to
#'
#' @param tester Did this visitor come in via ?testers (kept after the redirect)
spotify_begin_login <- function(tester = FALSE) {
  now <- as.numeric(Sys.time())
  for (s in ls(.spotify_logins)) {                       # forget stale logins
    if (now - .spotify_logins[[s]]$time > SPOTIFY_LOGIN_TTL) rm(list = s, envir = .spotify_logins)
  }
  state <- spotify_random_state()
  assign(state, list(time = now, tester = isTRUE(tester)), envir = .spotify_logins)
  spotify_authorize_url(state)
}

# POST to the token endpoint; keeps the old refresh token if none is returned.
spotify_token_request <- function(form, old_refresh = NULL, store = .spotify) {
  resp <- httr2::request("https://accounts.spotify.com/api/token") |>
    httr2::req_auth_basic(Sys.getenv("SPOTIFY_CLIENT_ID"),
                          Sys.getenv("SPOTIFY_CLIENT_SECRET")) |>
    httr2::req_body_form(!!!form) |>
    httr2::req_timeout(15) |>          # one R process serves everyone: never hang
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400) {
    stop("Spotify token request failed (HTTP ", httr2::resp_status(resp), "): ",
         httr2::resp_body_string(resp))
  }
  tok <- httr2::resp_body_json(resp)
  tok$expires_at    <- as.numeric(Sys.time()) + tok$expires_in
  tok$refresh_token <- tok$refresh_token %||% old_refresh
  store$token <- tok
  if (.spotify_persist(store)) {
    try({
      dir.create(dirname(spotify_token_file()), recursive = TRUE, showWarnings = FALSE)
      saveRDS(list(refresh_token = tok$refresh_token), spotify_token_file())
    }, silent = TRUE)
  }
  tok
}

#' Was this login started from a ?testers link? (does not use up the state)
spotify_login_tester <- function(state) {
  if (!is.character(state) || length(state) != 1 || !nzchar(state) ||
      !exists(state, envir = .spotify_logins, inherits = FALSE)) return(FALSE)
  isTRUE(get(state, envir = .spotify_logins, inherits = FALSE)$tester)
}

#' Finish a login: check `state` (known, fresh, single use), swap `code` for tokens
#'
#' @return list(tester) - whether the login was started from a ?testers link
spotify_complete_login <- function(code, state, store = .spotify) {
  entry <- if (is.character(state) && length(state) == 1 && nzchar(state) &&
               exists(state, envir = .spotify_logins, inherits = FALSE)) {
    get(state, envir = .spotify_logins, inherits = FALSE)
  }
  if (is.null(entry) || as.numeric(Sys.time()) - entry$time > SPOTIFY_LOGIN_TTL) {
    stop("Spotify login state mismatch or expired - please click 'Connect Spotify' again.")
  }
  rm(list = state, envir = .spotify_logins)
  spotify_token_request(list(grant_type = "authorization_code", code = code,
                             redirect_uri = SPOTIFY_REDIRECT_URI), store = store)
  invisible(list(tester = isTRUE(entry$tester)))
}

#' A valid access token (refreshing / restoring from disk), or NULL
spotify_access_token <- function(store = .spotify) {
  if (!spotify_configured()) return(NULL)
  tok <- store$token
  if (!is.null(tok) && tok$expires_at - 60 > as.numeric(Sys.time())) {
    return(tok$access_token)
  }
  refresh <- tok$refresh_token
  if (is.null(refresh) && .spotify_persist(store) && file.exists(spotify_token_file())) {
    refresh <- tryCatch(readRDS(spotify_token_file())$refresh_token,
                        error = function(e) NULL)
  }
  if (is.null(refresh)) return(NULL)
  tok <- tryCatch(
    spotify_token_request(list(grant_type = "refresh_token", refresh_token = refresh),
                          old_refresh = refresh, store = store),
    error = function(e) NULL)
  tok$access_token
}

#' Seconds until the current access token expires (0 if none)
spotify_token_expires_in <- function(store = .spotify) {
  tok <- store$token
  if (is.null(tok$expires_at)) return(0)
  max(0, tok$expires_at - as.numeric(Sys.time()))
}

spotify_forget_login <- function(store = .spotify) {
  store$token <- NULL
  if (.spotify_persist(store) && file.exists(spotify_token_file())) {
    unlink(spotify_token_file())
  }
}

spotify_api <- function(method, path, body = NULL, store = .spotify) {
  token <- spotify_access_token(store)
  if (is.null(token)) stop("Not connected to Spotify.")
  req <- httr2::request(paste0("https://api.spotify.com/v1", path)) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_method(method) |>
    httr2::req_timeout(15) |>
    httr2::req_error(is_error = function(r) FALSE)
  if (!is.null(body)) req <- httr2::req_body_json(req, body)
  httr2::req_perform(req)
}

#' Spotify track URIs for a playlist's matched songs, in playlist order
#'
#' @param picks Output of assign_songs_to_playlist() (song_number, spotify_uri)
#' @return character vector of "spotify:track:<id>" (unplayable rows dropped)
picks_to_spotify_uris <- function(picks) {
  if (is.null(picks) || nrow(picks) == 0) return(character())
  picks <- picks[order(picks$song_number), , drop = FALSE]
  ids <- vapply(picks$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
  ids <- ids[!is.na(ids)]
  unique(paste0("spotify:track:", ids))
}

#' Create a private playlist in the logged-in user's Spotify and fill it
#'
#' Uses the February-2026 endpoints (POST /me/playlists,
#' POST /playlists/{id}/items), falling back to /tracks for older API setups.
#' @return list(url, n) - the playlist's open.spotify.com URL and track count
spotify_export_playlist <- function(name, description, uris, store = .spotify) {
  if (length(uris) == 0) stop("No Spotify tracks in this playlist to export.")
  r <- spotify_api("POST", "/me/playlists",
                   list(name = name, public = FALSE,
                        description = substr(gsub("[\r\n]+", " ", description), 1, 300)),
                   store = store)
  if (httr2::resp_status(r) >= 400) {
    stop("Creating the playlist failed (HTTP ", httr2::resp_status(r), "): ",
         httr2::resp_body_string(r))
  }
  pl <- httr2::resp_body_json(r)
  for (chunk in split(uris, ceiling(seq_along(uris) / 100))) {
    r2 <- spotify_api("POST", paste0("/playlists/", pl$id, "/items"), list(uris = chunk),
                      store = store)
    if (httr2::resp_status(r2) >= 400) {
      r2 <- spotify_api("POST", paste0("/playlists/", pl$id, "/tracks"), list(uris = chunk),
                        store = store)
    }
    if (httr2::resp_status(r2) >= 400) {
      stop("Adding tracks failed (HTTP ", httr2::resp_status(r2), "): ",
           httr2::resp_body_string(r2))
    }
  }
  list(url = pl$external_urls$spotify %||% paste0("https://open.spotify.com/playlist/", pl$id),
       n = length(uris))
}
