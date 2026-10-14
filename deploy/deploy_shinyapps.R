# deploy/deploy_shinyapps.R ----------------------------------------------
# Put Beats per Million online at https://<ACCOUNT>.shinyapps.io/<APP_NAME>/
#
# Run from the project root (open climate_playlists.Rproj in RStudio):
#
#   source("deploy/deploy_shinyapps.R")
#
# What it does
#   1. Checks: shinyapps.io account known to rsconnect, renv.lock complete and
#      in sync with your library, tests pass.
#   2. Works out which tempos need more songs (data/wanted_bpm.csv, shown
#      under "Suggest a song"), then copies ONLY the files the app needs into
#      a temporary folder.
#   3. Writes a server-only .Renviron there: the app settings below, the
#      production Spotify redirect URI and - only if the tester login is on -
#      the Spotify app keys. Your YouTube / GetSongBPM / SoundCloud keys and
#      your own .Renviron never leave your machine.
#   4. Uploads that folder with rsconnect::deployApp().
#
# One-time setup (account, token, Spotify dashboard): LAUNCH.md, step 1-2.

# ---- settings -------------------------------------------------------------
ACCOUNT   <- "beatspermillion"                    # your shinyapps.io account name (see LAUNCH.md)
APP_NAME  <- "dance"               # last part of the URL: https://beatspermillion.shinyapps.io/dance/
APP_TITLE <- "Beats per Million"

DEFAULT_PLAYER <- "spotify"   # what visitors start with: "spotify" | "youtube" | "auto"
SPOTIFY_LOGIN  <- "off"   # "testers": Connect Spotify only via the ?testers link
                              # "off": no Spotify login online | "on": everyone
CONTACT        <- "lena.thoele@gmail.com"          # email or URL shown in About & privacy
SUGGEST_URL    <- ""          # "Suggest a song": "" = pre-filled email to CONTACT,
                              # or a form's address (e.g. a Google Form)
RUN_TESTS      <- TRUE

# ---- checks ---------------------------------------------------------------
stopifnot("Run this from the project root (where app.R is)" = file.exists("app.R"))
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  stop("Install rsconnect first: install.packages(\"rsconnect\")")
}
if (!nzchar(ACCOUNT)) {
  stop("Set ACCOUNT at the top of deploy/deploy_shinyapps.R (your shinyapps.io account name).")
}
known <- rsconnect::accounts(server = "shinyapps.io")
if (!ACCOUNT %in% known$name) {
  stop("rsconnect doesn't know the account '", ACCOUNT, "' yet. In shinyapps.io: ",
       "Account -> Tokens -> Show -> copy the rsconnect::setAccountInfo(...) line, run it ",
       "once in the R console, then source this script again (LAUNCH.md, step 1).")
}
APP_URL <- sprintf("https://%s.shinyapps.io/%s/", ACCOUNT, APP_NAME)

# Every package the app imports must be in renv.lock - the server installs
# exactly what the lockfile lists.
imports <- read.dcf("DESCRIPTION", fields = "Imports")[1, 1]
imports <- trimws(sub("\\(.*$", "", strsplit(gsub("\n", " ", imports), ",")[[1]]))
locked  <- names(jsonlite::read_json("renv.lock")$Packages)
missing <- setdiff(imports, locked)
if (length(missing)) {
  stop("renv.lock is missing: ", paste(missing, collapse = ", "),
       ". Run renv::snapshot(), check the result, and source this script again.")
}
if (requireNamespace("renv", quietly = TRUE)) {
  st <- renv::status()
  if (!isTRUE(st$synchronized)) {
    stop("Your package library and renv.lock differ (see above). Run renv::snapshot() ",
         "(or renv::restore()), then source this script again.")
  }
}
if (isTRUE(RUN_TESTS)) {
  message("Running the tests...")
  testthat::test_dir("tests/testthat", reporter = "summary", stop_on_failure = TRUE)
}
if (SPOTIFY_LOGIN != "off" &&
    !all(nzchar(Sys.getenv(c("SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET"))))) {
  warning("SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET aren't set: deploying without Spotify login.",
          call. = FALSE)
  SPOTIFY_LOGIN <- "off"
}
if (!nzchar(CONTACT)) {
  warning("CONTACT is empty: About & privacy will show no contact. Set it before going public.",
          call. = FALSE)
}

# ---- songs wanted (About & privacy -> Suggest a song) -----------------------
# Tempo ranges where the library is thin for the player visitors start with,
# from the library check's coverage simulation (~10 s). Redone on every
# deploy, so it always matches the library that goes online
# (data/wanted_bpm.csv is git-ignored).
message("Working out which tempos need more songs...")
local({
  suppressPackageStartupMessages(library(dplyr))
  for (f in c("config.R", "functions.R", "load_data.R", "library_check.R", "share.R")) {
    sys.source(file.path("R", f), envir = environment())
  }
  quiet <- function(expr) {                 # these print progress; not needed here
    out <- NULL
    utils::capture.output(out <- suppressMessages(expr))
    out
  }
  pool  <- pool_for_player(DEFAULT_PLAYER)
  co2   <- quiet(load_co2_data("data"))
  pls   <- quiet(list(per_period = generate_all_playlists(co2)))
  lib   <- quiet(load_song_library("data"))
  pools <- library_pools(lib, read_blocked_youtube("data/youtube_blocked.csv"))[pool]
  ranges <- wanted_bpm_ranges(library_gaps(library_coverage(pls, pools), pools), pool)
  write_wanted_bpms(ranges, pool, file.path("data", "wanted_bpm.csv"))
  message("  ", if (nrow(ranges)) paste(wanted_bpm_labels(ranges), collapse = ", ")
          else "none - every tempo is covered")
})

# ---- stage the app ----------------------------------------------------------
APP_FILES <- c(
  "app.R", "DESCRIPTION", "renv.lock",
  list.files("R", pattern = "\\.R$", full.names = TRUE),   # incl. _disable_autoload.R
  "www/player.js", "www/og-image.png",
  "data/co2_data.xlsx", "data/rawData/rae2021co2.xlsx",
  "data/song_library.csv", "data/youtube_blocked.csv", "data/wanted_bpm.csv"
)
absent <- APP_FILES[!file.exists(APP_FILES)]
if (length(absent)) stop("Missing file(s): ", paste(absent, collapse = ", "))

stage <- file.path(tempdir(), APP_NAME)
unlink(stage, recursive = TRUE)
for (f in APP_FILES) {
  dir.create(dirname(file.path(stage, f)), recursive = TRUE, showWarnings = FALSE)
  file.copy(f, file.path(stage, f), overwrite = TRUE)
}

# Server-only settings (see R/settings.R). Quoted so any character is safe.
env <- c(BPM_DEPLOYED       = "true",
         BPM_DEFAULT_PLAYER = DEFAULT_PLAYER,
         BPM_SPOTIFY_LOGIN  = SPOTIFY_LOGIN,
         BPM_CONTACT        = CONTACT,
         BPM_PUBLIC_URL     = APP_URL,          # link previews need absolute addresses
         BPM_SUGGEST_URL    = SUGGEST_URL)
if (SPOTIFY_LOGIN != "off") {
  env <- c(env,
           SPOTIFY_CLIENT_ID     = Sys.getenv("SPOTIFY_CLIENT_ID"),
           SPOTIFY_CLIENT_SECRET = Sys.getenv("SPOTIFY_CLIENT_SECRET"),
           SPOTIFY_REDIRECT_URI  = APP_URL)
}
writeLines(sprintf('%s="%s"', names(env), gsub('"', '\\\\"', env)),
           file.path(stage, ".Renviron"))
Sys.chmod(file.path(stage, ".Renviron"), mode = "0600")

message("Deploying these files from a temporary folder:\n  ",
        paste(c(APP_FILES, ".Renviron (server settings)"), collapse = "\n  "))

# ---- deploy -------------------------------------------------------------------
rsconnect::deployApp(
  appDir      = stage,
  appName     = APP_NAME,
  appTitle    = APP_TITLE,
  account     = ACCOUNT,
  server      = "shinyapps.io",
  recordDir   = getwd(),        # deployment record in ./rsconnect (git-ignored)
  forceUpdate = TRUE,
  launch.browser = interactive()
)
unlink(stage, recursive = TRUE)

message("\nDone: ", APP_URL,
        "\n  Testers (Connect Spotify): ", APP_URL, "?testers",
        "\n  About & privacy:           ", APP_URL, "?about",
        "\n  Try a player directly:     ", APP_URL, "?player=youtube",
        if (SPOTIFY_LOGIN != "off")
          paste0("\nSpotify dashboard -> your app -> Settings -> Redirect URIs must include:\n  ",
                 APP_URL))
