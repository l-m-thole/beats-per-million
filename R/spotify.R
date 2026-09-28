# =============================================================================
# SPOTIFY: LOGIN, IN-APP PLAYBACK TOKEN, PLAYLIST EXPORT
# =============================================================================
#
# Needs a Spotify developer app (https://developer.spotify.com/dashboard):
#   - .Renviron: SPOTIFY_CLIENT_ID=..., SPOTIFY_CLIENT_SECRET=...
#   - In the app's settings add the Redirect URI exactly:  http://127.0.0.1:4321/
#     (Spotify no longer accepts "localhost"; the app runs on port 4321.)
#   - Development-mode apps need the app owner to have Spotify Premium, and the
#     in-app player (Web Playback SDK) needs the listener to have Premium.
#
# Login is a standard Authorization Code flow handled by the Shiny app itself:
# the browser goes to Spotify, Spotify redirects back to the app with ?code=,
# the app swaps the code for tokens. The refresh token is cached on disk
# (outside the repo) so you only log in once.
# =============================================================================

SPOTIFY_PORT         <- 4321L
SPOTIFY_REDIRECT_URI <- Sys.getenv("SPOTIFY_REDIRECT_URI",
                                   paste0("http://127.0.0.1:", SPOTIFY_PORT, "/"))
SPOTIFY_SCOPES <- c(
  "streaming", "user-read-email", "user-read-private",          # Web Playback SDK
  "user-modify-playback-state", "user-read-playback-state",     # start a track
  "playlist-modify-private", "playlist-modify-public"           # export
)

# Session-independent state (single-user local app): current token + the
# `state` value of a login that is in progress.
.spotify <- new.env(parent = emptyenv())

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

spotify_begin_login <- function() {
  state <- paste(sample(c(letters, 0:9), 24, replace = TRUE), collapse = "")
  .spotify$state <- state
  spotify_authorize_url(state)
}

# POST to the token endpoint; keeps the old refresh token if none is returned.
spotify_token_request <- function(form, old_refresh = NULL) {
  resp <- httr2::request("https://accounts.spotify.com/api/token") |>
    httr2::req_auth_basic(Sys.getenv("SPOTIFY_CLIENT_ID"),
                          Sys.getenv("SPOTIFY_CLIENT_SECRET")) |>
    httr2::req_body_form(!!!form) |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) >= 400) {
    stop("Spotify token request failed (HTTP ", httr2::resp_status(resp), "): ",
         httr2::resp_body_string(resp))
  }
  tok <- httr2::resp_body_json(resp)
  tok$expires_at    <- as.numeric(Sys.time()) + tok$expires_in
  tok$refresh_token <- tok$refresh_token %||% old_refresh
  .spotify$token <- tok
  try({
    dir.create(dirname(spotify_token_file()), recursive = TRUE, showWarnings = FALSE)
    saveRDS(list(refresh_token = tok$refresh_token), spotify_token_file())
  }, silent = TRUE)
  tok
}

#' Finish a login: validate `state`, swap `code` for tokens
spotify_complete_login <- function(code, state) {
  if (is.null(.spotify$state) || !identical(state, .spotify$state)) {
    stop("Spotify login state mismatch - please click 'Connect Spotify' again.")
  }
  .spotify$state <- NULL
  spotify_token_request(list(grant_type = "authorization_code", code = code,
                             redirect_uri = SPOTIFY_REDIRECT_URI))
}

#' A valid access token (refreshing / restoring from disk), or NULL
spotify_access_token <- function() {
  if (!spotify_configured()) return(NULL)
  tok <- .spotify$token
  if (!is.null(tok) && tok$expires_at - 60 > as.numeric(Sys.time())) {
    return(tok$access_token)
  }
  refresh <- tok$refresh_token
  if (is.null(refresh) && file.exists(spotify_token_file())) {
    refresh <- tryCatch(readRDS(spotify_token_file())$refresh_token,
                        error = function(e) NULL)
  }
  if (is.null(refresh)) return(NULL)
  tok <- tryCatch(
    spotify_token_request(list(grant_type = "refresh_token", refresh_token = refresh),
                          old_refresh = refresh),
    error = function(e) NULL)
  tok$access_token
}

spotify_forget_login <- function() {
  .spotify$token <- NULL
  if (file.exists(spotify_token_file())) unlink(spotify_token_file())
}

spotify_api <- function(method, path, body = NULL) {
  token <- spotify_access_token()
  if (is.null(token)) stop("Not connected to Spotify.")
  req <- httr2::request(paste0("https://api.spotify.com/v1", path)) |>
    httr2::req_auth_bearer_token(token) |>
    httr2::req_method(method) |>
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
spotify_export_playlist <- function(name, description, uris) {
  if (length(uris) == 0) stop("No Spotify tracks in this playlist to export.")
  r <- spotify_api("POST", "/me/playlists",
                   list(name = name, public = FALSE,
                        description = substr(gsub("[\r\n]+", " ", description), 1, 300)))
  if (httr2::resp_status(r) >= 400) {
    stop("Creating the playlist failed (HTTP ", httr2::resp_status(r), "): ",
         httr2::resp_body_string(r))
  }
  pl <- httr2::resp_body_json(r)
  for (chunk in split(uris, ceiling(seq_along(uris) / 100))) {
    r2 <- spotify_api("POST", paste0("/playlists/", pl$id, "/items"), list(uris = chunk))
    if (httr2::resp_status(r2) >= 400) {
      r2 <- spotify_api("POST", paste0("/playlists/", pl$id, "/tracks"), list(uris = chunk))
    }
    if (httr2::resp_status(r2) >= 400) {
      stop("Adding tracks failed (HTTP ", httr2::resp_status(r2), "): ",
           httr2::resp_body_string(r2))
    }
  }
  list(url = pl$external_urls$spotify %||% paste0("https://open.spotify.com/playlist/", pl$id),
       n = length(uris))
}
