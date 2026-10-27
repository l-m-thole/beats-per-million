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
playlist, the Industrial era's years after 2022 (its `cmip7` sheet = CMIP7 to
2022 + offset-matched Mauna Loa yearly means, complete years only), their end
dates in *About* and the period stats follow automatically;
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
the file only on real changes; the download is faked), the *How it works* /
*About this era* windows and how each era's CO₂ was measured, the album-cover
cache (`covers.R`, offline with a fake lookup), the playlist helpers (tempo
*Feel*, which song a point on the curve belongs to, the CSV download), and the
app's server logic (`test-app_server.R`, via `shiny::testServer()`: a new song
only starts by itself while music plays, Previous / Next, the playlist table,
how each song was matched, one service per playlist, the ▶ Play gate, a failing
YouTube video moving on instead of switching service, and that the page's
`<head>` loads nothing from other sites).

The enrichment test with Swedish characters needs a UTF-8 locale (it is on any
normal Mac/RStudio setup).

**On GitHub:** `.github/workflows/tests.yml` runs the whole suite on every push
(docs-only pushes skipped). It installs the app's packages from `DESCRIPTION`
(Imports + Suggests) as ready-made Linux binaries with pak and switches renv
off (`RENV_CONFIG_AUTOLOADER_ENABLED=false`): `renv::restore()` from the Mac's
lockfile failed there on the compiled packages. `renv.lock` is still what your
Mac and shinyapps.io use. Results: the badge in the README, or the repo's
*Actions* tab.

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

**Matching:** `assign_songs_to_playlist()` walks the slots in order;
`pick_song_widening()` tries the BPM windows in `MATCH_TOLS` (`R/config.R`:
±3, then ±5, then ±10 BPM), picks at random among the unused songs in the
first window that has any, else takes the nearest song. Changing `MATCH_TOLS`
changes which songs every seed gives. The library check and the wanted tempos
count a match in the first window as good.

**Following the curve** (`follow_curve = TRUE`, the default): for each slot
after the first, `assign_songs_to_playlist()` passes the direction of the slot
tempos (`sign(bpm[i] - bpm[i-1])`) and the song before's own BPM to
`pick_song_widening(after_bpm =, direction =)`. In the first window that has
songs, the draw is narrowed to the ones that step the same way (faster while the
tempo rises, slower while it falls) when there are any; otherwise the whole
window counts. It never widens a window, so match quality is unchanged; picks
carry `trend` ("faster"/"slower"/NA) for the Listen panel's explanation.
Without a direction the draw is exactly the old one, but with it most seeds now
give other songs than before v4.1.0.

**Playlist length:** `PLAYLIST_LENGTHS` (`R/config.R`: standard = 1, long = 2)
is the number of songs per standard slice; `generate_playlist(length_factor =)`
cuts each slice into that many equal parts (`num_songs` = standard count ×
factor, so the slices line up). `app.R` keeps `ALL_PLAYLISTS` (standard, made
at startup) unchanged and builds long playlists on first use in
`get_playlist()` (cached in `LONG_PLAYLISTS` per scale and era). Switching
length maps the selected song to the same moment (`floor((k - 1) × new / old) + 1`),
and `player_token()` includes the length. Songs never repeat in Long either.

## Period texts & key events

Background texts, key events and how the CO₂ was measured (`CO2_MEASUREMENT`
per data source, `CO2_MEASUREMENT_NOTES` per era) live in
`R/period_context.R` (sourced by `app.R` after `functions.R`). Ages are years
BP (before 1950); modern events are written as CE years via `.yr()`. The
windows that show them are built in `R/how_it_works.R`, which also holds the
app's story and the makers (`APP_STORY`, `APP_MAKERS`).

## Layout & player logic (app.R, www/player.js)

- **Layout:** header, era buttons (`radioButtons` styled as buttons), then a
  CSS grid: plot and playlist on the left, the Listen card on the right
  (`position: sticky`). Below 992 px it is one column: plot, Listen, playlist.
- **Font sizes:** Bootstrap 3 sets the root font to 10 px; `app_css()` resets it
  to 16 px so the `rem` sizes mean what they say (Bootstrap itself uses px).
- **Selected song:** `selected_idx()` is the only source of truth. The table has
  no DT selection: `player.js` sends row clicks as `input$playlist_row_click`
  (the song number from the first column, so sorting and filtering are safe)
  and highlights the row the server names (`bpm_select_row`), scrolling only the
  table. Previous / Next move by the click difference, so quick clicks add up.
- **Plot:** fixed axes, no mode bar; the selected slice is a shape. Clicking
  the curve or a cover uses the points' `customdata` (song number). Covers use
  a hidden second y-axis (`y2`) above the CO₂ axis.
- **Autoplay:** `listening()` is TRUE only while music plays. `player.js`
  reports play / pause (`input$player_state`, never for its own end-of-song
  pause or a player that hasn't started); a newly rendered player gets
  `data-autoplay` from `listening()`. At the end of a song, *Auto-play the next
  song* decides whether the playlist continues.
- **One service per playlist:** `play_service()` (the *Play via* choice) feeds
  `service_songs()` (`R/functions.R`), so the matcher only sees that service's
  songs, and the Listen panel only ever builds that service's player. There is
  no "best available" mix any more. A YouTube video that fails mid-session
  (`input$yt_error`) is remembered in `bad_yt()` and, while music is meant to
  play, the playlist moves on to the next song.
- **▶ Play gate (privacy):** nothing in `<head>` comes from another site (fonts
  in `www/fonts/fonts.css`). For embedded players the server renders
  `player_gate(service)` (`R/about.R`) plus the player placeholder in a hidden
  `.player-slot`. `player.js` keeps the gate until the visitor presses it
  (`consent[service]`, this page only), then fetches that service's script
  (`loadScript()`: Spotify embed API, YouTube IFrame API, SoundCloud widget API)
  and creates the player, starting the song. The Spotify SDK script is fetched
  when the server sends a token (`sp_token`, i.e. after a login). YouTube uses
  the normal youtube.com player (with `youtube-nocookie.com` YouTube refused
  22 of 23 songs, error 150) and `whenVisible()` before any automatic start.
- **YouTube refusals (`input$yt_error`):** the video goes into `bad_yt()` for
  the session; permanent codes wait in `yt_pending` and are only written to
  `data/youtube_blocked.csv` once a YouTube song has played in that browser
  (`input$player_state`). `YT_MAX_FAIL_RUN` (3) refusals in a row stop the
  playlist. Tests point `BPM_YT_BLOCKED_FILE` to a temporary file.

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

## Album covers

`R/covers.R`: `update_cover_cache()` (used by `data-raw/fetch_covers.R` and the
deploy script) fills `data/song_covers.csv` from Spotify's oEmbed
`thumbnail_url`; in the app `cover_store()` / `store_cover_urls()` read it and
look up missing ones once per R process (in parallel). Covers are Spotify-only
and only shown while playing via Spotify, credited under the plot
(`output$covers_credit`).

## Song-library check

`source("data-raw/check_song_library.R")` — row issues, coverage simulation
with the app's own matcher (one pool per service: `library_pools()` uses
`service_songs()`), BPM gaps, and a READY / NOT YET verdict
(`R/library_check.R`; a good match = within the first window of `MATCH_TOLS`,
±3 BPM). The verdict and the wanted tempos use the standard playlists; the Long
playlists (per-era, `PUBLIC_POOL`) get their own coverage table and gaps, as
information only. With `CHECK_LINKS <- TRUE` the online link check also
reports each YouTube link's channel and flags uploads that don't look official
(`youtube_channel_official()`; "label upload" / "official upload" in a song's
notes marks one you checked by hand).

## Platform rules & privacy (keep these)

Checked against the platforms' terms on 14 Oct 2026 (Spotify Developer Policy
and Widget Terms, YouTube API Services Developer Policies and Required Minimum
Functionality, SoundCloud API Terms). Not legal advice, but breaking these can
get an embed or API key blocked:

- **Never mix services** in one playlist or player (Spotify Policy III.5 /
  III.7, Widget Terms; SoundCloud API Terms §10). Links *out* to other services
  (the "Open in" buttons) are fine.
- **Spotify covers** only next to Spotify's player, credited to Spotify, with a
  link back (Spotify Policy II.4); never let visitors download them (no plot
  download button).
- **Nothing third-party before ▶ Play** (GDPR / Swedish cookie rules: the site
  owner shares responsibility for embeds). Keep fonts self-hosted; load new
  services through `loadScript()` after the gate; update `R/about.R` when a
  service, host or data use changes.
- **YouTube:** player at least 200 × 200 px, nothing on top of it, no hidden or
  audio-only playback, automatic starts only while it's more than half visible;
  keep the "YouTube API Services" + Terms of Service lines in *About* and the
  gate.
- **Official uploads only** for YouTube links (artist, VEVO, "Artist - Topic"
  or label channels).
- **Non-commercial:** no ads, sponsors or paid features while the app uses
  these players.
- Don't add a video/GIF export that combines the plot with the music (Spotify
  forbids synchronising recordings with visual media).

Tripwire: `tests/testthat/test-platform_rules.R` fails when ad, tracking or
payment code, a recording/animation/image export, the plot's mode bar or a new
download shows up. If it fails, check the change against these rules before
touching the test.

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
