# Development & Reproducibility

## Dependencies (renv)

This project uses [renv](https://rstudio.github.io/renv/) to pin package versions
so the pipeline reproduces years from now. Declared dependencies live in
`DESCRIPTION` (the `Imports` field).

**Fresh clone:**

```r
install.packages("renv")
renv::restore()     # installs the exact versions recorded in renv.lock
```

**Create / update the lockfile** (run once to generate `renv.lock`, then again
whenever dependencies change):

```r
renv::init()        # first time: scans the code, writes renv.lock
renv::snapshot()    # later: update renv.lock to match your current library
```

## Rebuild the processed data

`data/co2_data.xlsx` is generated from the raw files in `data/rawData/`:

```r
source("data-raw/build_co2_data.R")
```

- **Mauna Loa** and **Rae 2021** rebuild fully from raw files already in the repo.
- **Bereiter** needs the raw 800 kyr composite dropped into `data/rawData/`
  (see the script header for the NCEI download). Until then the existing sheet
  is preserved and the script warns, so it still runs end to end.

## Run the tests

```r
install.packages("testthat")   # if needed
testthat::test_dir("tests/testthat")
```

Covered: the CO2 to BPM conversion (`co2_to_bpm`), age-label formatting
(`format_age`), the Rae proxy binning / validation (`load_data.R`), the BPM song
matcher (`pick_song_for_bpm` / `pick_song_widening` / `assign_songs_to_playlist`:
tolerance, widening, exclusion, empty library, seed reproducibility), and the
song-library seed → Excel-style re-save → load round-trip, the Spotify / YouTube
link parsing, the CO2-curve ball position, the song-library enrichment matching
(`enrich_library.R`, offline with fake lookups), and the period context / key
events (`period_context.R`: every event inside its period, ordering, window lookup).

The enrichment test with Swedish characters needs a UTF-8 locale (it is on any
normal Mac/RStudio setup).

## Song library (in-app playback)

Songs are matched to playlist slots **by BPM at run time** from a flat,
hand-built `data/song_library.csv` (`song_title, artist, spotify_uri,
soundcloud_url, bpm, notes, youtube_url`). Blank cells can be filled with
`source("data-raw/enrich_song_library.R")` (GetSongBPM, Spotify, SoundCloud,
YouTube APIs; see MUSIC_SETUP.md). This replaces the earlier fixed-slot
`curated_songs.csv`, whose `(period, song_number)` join broke whenever a data
refresh shifted song numbers. `seed_song_library()` writes the file once (header
+ two example rows) and never overwrites it; `run_generator.R` calls it after
exporting the templates.

## Period texts & key events

Background texts and key events per period live in `R/period_context.R`
(sourced by `app.R` after `functions.R`). Ages are years BP (before 1950);
modern events are written as CE years via `.yr()`.

## Secrets

API keys live in `.Renviron` (git-ignored); `.Renviron.example` lists the
variables. Never commit keys.

## Regenerate playlist outputs

```r
source("run_generator.R")
```
