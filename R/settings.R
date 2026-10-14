# =============================================================================
# APP SETTINGS: local vs deployed, public player mode, contact
# =============================================================================
#
# Everything here is read from environment variables, so the SAME code runs on
# your laptop and on a server; only .Renviron differs. Locally nothing needs to
# be set. The deploy script (deploy/deploy_shinyapps.R) writes the server's
# .Renviron for you.
#
#   BPM_DEFAULT_PLAYER  "Play via" choice a visitor starts with:
#                       spotify (default) | youtube | soundcloud | auto
#   BPM_SPOTIFY_LOGIN   who sees "Connect Spotify":
#                       on      - everyone (default when running locally)
#                       testers - only visitors who open the app with ?testers
#                                 in the URL (default when deployed; Spotify
#                                 development mode allows max. 5 accounts)
#                       off     - nobody
#   BPM_CONTACT         contact shown in About & privacy (email or URL)
#   BPM_PUBLIC_URL      the app's public address (https://.../), for link
#                       previews; the deploy script writes it
#   BPM_SUGGEST_URL     where "Suggest a song" points, e.g. a Google Form;
#                       empty = a pre-filled email to BPM_CONTACT
#   BPM_DEPLOYED        force deployed (true) / local (false) mode; normally
#                       detected automatically
# =============================================================================

PLAYER_CHOICES      <- c("auto", "spotify", "youtube", "soundcloud")
SPOTIFY_LOGIN_MODES <- c("on", "testers", "off")

#' TRUE when the app runs on a server rather than on your own machine
#'
#' shinyapps.io sets R_CONFIG_ACTIVE = "shinyapps", Posit Connect "rsconnect",
#' and Shiny Server (incl. shinyapps.io) sets SHINY_PORT. BPM_DEPLOYED
#' overrides the detection (e.g. in a Docker image).
bpm_is_deployed <- function() {
  forced <- tolower(Sys.getenv("BPM_DEPLOYED"))
  if (forced %in% c("true", "1", "yes")) return(TRUE)
  if (forced %in% c("false", "0", "no")) return(FALSE)
  nzchar(Sys.getenv("SHINY_PORT")) ||
    Sys.getenv("R_CONFIG_ACTIVE") %in% c("shinyapps", "rsconnect")
}

# An environment variable restricted to a set of allowed values
.bpm_choice <- function(var, choices, default) {
  val <- tolower(trimws(Sys.getenv(var)))
  if (!nzchar(val)) return(default)
  if (!val %in% choices) {
    warning(var, "='", val, "' is not one of ", paste(choices, collapse = ", "),
            "; using '", default, "'.", call. = FALSE)
    return(default)
  }
  val
}

#' All app settings as a list (read once at start-up)
#'
#' @param deployed Running on a server? (default: detected)
#' @return list(deployed, default_player, spotify_login, contact, public_url,
#'   suggest_url)
app_settings <- function(deployed = bpm_is_deployed()) {
  list(
    deployed       = deployed,
    default_player = .bpm_choice("BPM_DEFAULT_PLAYER", PLAYER_CHOICES, "spotify"),
    spotify_login  = .bpm_choice("BPM_SPOTIFY_LOGIN", SPOTIFY_LOGIN_MODES,
                                 if (deployed) "testers" else "on"),
    contact        = trimws(Sys.getenv("BPM_CONTACT")),
    public_url     = trimws(Sys.getenv("BPM_PUBLIC_URL")),
    suggest_url    = trimws(Sys.getenv("BPM_SUGGEST_URL"))
  )
}

#' Should this visitor see "Connect Spotify"?
#'
#' @param mode One of SPOTIFY_LOGIN_MODES
#' @param tester TRUE if the visitor opened the app with ?testers
#' @param connected TRUE if this visitor is already connected (always keep the
#'   disconnect link visible)
spotify_login_visible <- function(mode, tester = FALSE, connected = FALSE) {
  isTRUE(connected) || identical(mode, "on") ||
    (identical(mode, "testers") && isTRUE(tester))
}

#' Read the URL query flags the app understands
#'
#' ?testers           show Connect Spotify (when BPM_SPOTIFY_LOGIN = testers)
#' ?player=youtube    start with that "Play via" choice (handy for testing)
#' ?about             open About & privacy on load
#'
#' @param query Parsed query string (list), e.g. shiny::parseQueryString()
#' @return list(tester, player, about)
url_flags <- function(query) {
  player <- tolower(query$player %||% "")
  list(
    tester = !is.null(query$testers),
    player = if (player %in% PLAYER_CHOICES) player else NULL,
    about  = !is.null(query$about)
  )
}

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}
