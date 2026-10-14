# data-raw/fetch_covers.R ---------------------------------------------------
# Album covers for "Show covers on the plot".
#
# Looks up the cover of every song in data/song_library.csv that has a Spotify
# link (Spotify's public oEmbed endpoint, no key needed) and stores the
# addresses in data/song_covers.csv. Only songs that aren't in the file yet are
# looked up, so re-running after adding songs takes a second or two.
# The deploy script runs the same update before every deploy.
#
# Run from the project root:
#   source("data-raw/fetch_covers.R")
#
# REFETCH <- TRUE asks Spotify again for every song (e.g. if covers changed).

REFETCH <- FALSE

local({
  suppressPackageStartupMessages(library(dplyr))
  for (f in c("config.R", "functions.R", "load_data.R", "covers.R")) {
    source(file.path("R", f), local = TRUE)
  }
  lib  <- load_song_library("data")
  path <- file.path("data", COVERS_CSV)
  cache <- update_cover_cache(lib, path, refetch = REFETCH)

  message("\n", length(cache), " covers in ", path,
          " (", attr(cache, "asked"), " looked up just now)")
  miss <- attr(cache, "missing")
  if (length(miss)) {
    rows <- lib[vapply(lib$spotify_uri, parse_spotify_id, character(1),
                       USE.NAMES = FALSE) %in% miss, c("song_title", "artist")]
    message("No cover for ", length(miss), " song(s) - check their Spotify links ",
            "(or Spotify couldn't be reached; just run this again):\n  ",
            paste0(rows$song_title, " – ", rows$artist, collapse = "\n  "))
  }
})
