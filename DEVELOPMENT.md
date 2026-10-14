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

### Newer Mauna Loa months

```r
source("data-raw/update_maunaloa.R")
```

Downloads NOAA's `co2_mm_mlo.csv`, checks it (`check_maunaloa_update()` in
`R/refresh_co2.R`: at least 600 rows, starts in 1958, dates in order, values
300–600 ppm, doesn't end earlier, no month we already had changed by more than
1 ppm) and only then replaces `data/rawData/co2_mm_mlo.csv` and rebuilds
`co2_data.xlsx` — and only when NOAA has new or revised months. The Modern
playlist, its end date in *About* and the period stats follow automatically;
re-deploy afterwards.

**Monthly on GitHub:** `.github/workflows/refresh-co2.yml` runs the same script
on the 9th of every month (or *Actions → refresh-co2 → Run workflow*), runs the
tests, and opens a pull request `Data: Mauna Loa CO₂ through <month>` if
something changed. One-time setting: *Settings → Actions → General → Workflow
permissions → Allow GitHub Actions to create and approve pull requests*.

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
(`enrich_library.R`, offline with fake lookups), the period context / key
events (`period_context.R`: every event inside its period, ordering, window
lookup), the app settings and URL flags (`settings.R`), the Spotify login
plumbing (random single-use login states, one token store per visitor when
deployed, nothing on disk online), the library check (`library_check.R`: row
issues, faked oEmbed link checks, coverage and gaps), the About text, the
sharing helpers (`share.R`: link-preview tags, preview image size, the
*Suggest a song* link, wanted tempo ranges and their file), and the Mauna Loa
refresh (`refresh_co2.R`: reading NOAA's file, the sanity checks, replacing
the file only on real changes; the download is faked).

The enrichment test with Swedish characters needs a UTF-8 locale (it is on any
normal Mac/RStudio setup).

**On GitHub:** `.github/workflows/tests.yml` runs the whole suite on every push
(docs-only pushes skipped) with the packages from `renv.lock` plus `testthat`.
Results: the badge in the README, or the repo's *Actions* tab.

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

## Local vs deployed

`R/settings.R` detects a server (shinyapps.io / Posit Connect / Shiny Server,
or `BPM_DEPLOYED=true`) and switches: no fixed port, one Spotify login per
browser session kept in memory (locally: one login cached on disk, as before),
*Connect Spotify* only for `?testers` visitors. `deploy/deploy_shinyapps.R`
stages only the runtime files and writes the server's `.Renviron`; it refuses
to deploy if `renv.lock` is missing an imported package or is out of sync.
See [`LAUNCH.md`](LAUNCH.md).

## Song-library check

`source("data-raw/check_song_library.R")` — row issues, coverage simulation
with the app's own matcher, BPM gaps, and a READY / NOT YET verdict
(`R/library_check.R`).

## Link previews & Suggest a song

`R/share.R`. The preview tags sit in the static UI (crawlers don't run
JavaScript) and need the app's absolute address, which the deploy script passes
as `BPM_PUBLIC_URL`. The picture is `www/og-image.png` (1200 × 630), drawn by
`source("data-raw/make_og_image.R")` in the app's fonts if installed. To test,
send the deployed link to yourself in WhatsApp/Signal/Slack; those apps cache
previews, so a changed picture can take a while to show.

*Suggest a song* points to `BPM_SUGGEST_URL` (deploy script: `SUGGEST_URL`) or
else a pre-filled email to `BPM_CONTACT`. The tempos listed with it come from
`data/wanted_bpm.csv`, which the deploy script recomputes from the library
check (pool = the default player's) on every deploy; the app only reads it.

## Regenerate playlist outputs

```r
source("run_generator.R")
```
