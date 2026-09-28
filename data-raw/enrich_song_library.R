# data-raw/enrich_song_library.R -----------------------------------------
# Run after adding new rows (song_title + artist) to data/song_library.csv.
# Fills only BLANK bpm / spotify_uri / soundcloud_url / youtube_url cells.
#
# One-time setup
#   1. Get keys:
#      - GetSongBPM: https://getsongbpm.com/api (free; needs a backlink to
#        getsongbpm.com, e.g. in the app footer or README)
#      - Spotify:    https://developer.spotify.com/dashboard (app owner needs Premium)
#      - SoundCloud: https://developers.soundcloud.com (access is by application)
#      - YouTube:    https://console.cloud.google.com -> enable "YouTube Data API v3",
#                    create an API key (free, ~100 searches/day)
#   2. Copy .Renviron.example to .Renviron (or usethis::edit_r_environ("project"))
#      and fill in the keys you have
#   3. Make sure .Renviron and data/backups/ are in .gitignore, then restart R.
#   Missing keys are fine: that step is skipped, the others still run.

source("R/enrich_library.R")

log <- enrich_song_library(
  path  = "data/song_library.csv",
  steps = c("bpm", "spotify", "soundcloud", "youtube")
)

# Rows to check by hand: no match, or BPM outside the app's 60-150 range
if (nrow(log)) {
  review <- log[nzchar(log$flag), c("csv_line", "song_title", "artist", "field", "value", "flag")]
  print(review, row.names = FALSE)
}

# Spot-check the accepted matches (matched_title/artist = what the API returned)
# View(log)
