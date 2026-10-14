# 🌍 Beats per Million — Dance While You Can

[![tests](https://github.com/l-m-thole/climate_playlist/actions/workflows/tests.yml/badge.svg)](https://github.com/l-m-thole/climate_playlist/actions/workflows/tests.yml)

**Translating Earth's Climate History into Music**

This project converts atmospheric CO₂ concentrations through geological time into "beats per minute" (BPM) values, creating a unique sonic experience of climate change. Lower CO₂ (ice ages) produces slow, ambient music; higher CO₂ (hothouse conditions) produces fast, energetic music.

A collaboration between **Martin Wegmann** and **Lena Thöle**.

**▶ Try it (test version):** <https://beatspermillion.shinyapps.io/dance/> —
Spotify plays 30-second previews; pick *Play via YouTube* for whole songs.

---

## 🎵 The Concept

| Climate State | CO₂ (ppm) | BPM | Mood |
|---------------|-----------|-----|------|
| Glacial maximum | ~180 | 60 | Glacial – Ambient / Drone |
| Pre-industrial | ~280 | 85 | Relaxed – Jazz / Soft Rock |
| Modern day | ~420 | 115 | Moderate – Pop / Indie |
| Eocene hothouse | ~1500 | 150 | Intense – Drum & Bass |

---

## 📊 Time Periods

| Period | Time Span | Songs | Data Source | Key events in the app (a selection) |
|--------|-----------|-------|-------------|------------------------|
| **Modern Era** | 1958–Present | ~23 | Mauna Loa Observatory | Keeling starts measuring, IPCC, Kyoto, 400 ppm crossed, Paris Agreement |
| **Roman Empire** | ~2,000 years | ~34 | Antarctic ice cores | Roman Climate Optimum, 536 CE eruptions, Medieval warmth, Little Ice Age, Industrial Revolution |
| **Last Glacial Maximum** | ~20,000 years | ~67 | Antarctic ice cores | LGM, Bølling–Allerød, Younger Dryas, start of the Holocene, Sweden ice-free, 8.2 kyr event |
| **Early Humans** | ~250,000 years | ~84 | Antarctic ice cores | Eemian interglacial, Toba eruption, Out of Africa, humans in Europe |
| **Full Ice Core** | ~800,000 years | ~89 | Antarctic ice cores | Mid-Brunhes Event, MIS 11, first Homo sapiens, 100-kyr ice-age cycles |
| **Cenozoic Era** | ~66 million years | ~88 | Marine proxy records | K–Pg impact, PETM, Eocene hothouse, Antarctic ice sheet, Pliocene (CO₂ ≈ today) |

Song counts are for the current data and change slightly when the data are refreshed.

In the app, each period has:

- a **short description** plus **"Read more"** background (what the data are, what drove CO₂, and what to listen for);
- a **key-events timeline** (oldest → youngest, the playback order);
- **event markers** (▼ and dotted lines) on the CO₂ plot — hover for details;
- a **"During this song"** box that lists any key event inside the selected song's time window.

The texts and events live in `R/period_context.R` (ages in years BP, i.e. before
1950; modern events are written as CE years and converted). Add or edit events
there — `tests/testthat/test-period_context.R` checks that every event falls
inside its period.

---

## 🚀 Getting Started

### 1. Install the packages

The project uses [renv](https://rstudio.github.io/renv/). Open
`climate_playlists.Rproj` in RStudio (this sets the working directory to the
project root), then:

```r
renv::restore()   # installs the exact package versions from renv.lock
```

### 2. (Optional) API keys

The app runs without any keys (YouTube and SoundCloud links play without login).
Keys are only needed for the full Spotify player, *Save to Spotify* and for
filling song links/BPM automatically. Copy `.Renviron.example` to `.Renviron`,
fill in the keys you have, and restart R. `.Renviron` is git-ignored — never
commit it. Details: [`MUSIC_SETUP.md`](MUSIC_SETUP.md).

| Key | Needed for | Lives in | Goes online? |
|---|---|---|---|
| `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET` | full Spotify player, *Save to Spotify*, finding Spotify links | your `.Renviron` | only when `SPOTIFY_LOGIN` in the deploy script isn't `"off"` |
| `YOUTUBE_API_KEY` | finding YouTube links (enrichment) | your `.Renviron` | never |
| `GETSONGBPM_KEY` | filling blank BPMs (enrichment); the live app's footer is the required backlink | your `.Renviron` | never |
| `SOUNDCLOUD_CLIENT_ID`, `SOUNDCLOUD_CLIENT_SECRET` | finding SoundCloud links (optional) | your `.Renviron` | never |
| shinyapps.io token | deploying | stored by `rsconnect` on your computer (`rsconnect::setAccountInfo()`) | — |

### 3. Run the Shiny app

```r
shiny::runApp()
```

The app opens in your browser at `http://127.0.0.1:4321` (the Spotify player
does not work in RStudio's Viewer).

### 4. Put it online

```r
source("deploy/deploy_shinyapps.R")   # after the one-time setup in LAUNCH.md
```

Deploys to shinyapps.io: only the files the app needs, plus a server-only
settings file (never your enrichment keys). Online, every visitor gets their own
Spotify login (or none), *Connect Spotify* is only shown via the `?testers`
link, and *About & privacy* is in the footer. Step-by-step setup, the player
test table and the launch criteria: [`LAUNCH.md`](LAUNCH.md).

**Sharing the link** shows a preview card (title, one line, and
`www/og-image.png` — the 800,000-year CO₂ curve; tags in `R/share.R`, picture
from `data-raw/make_og_image.R`). **Suggest a song** in the footer and in
*About & privacy* opens a pre-filled email to `CONTACT` (or a form, if you set
`SUGGEST_URL` in the deploy script); *About* also lists the tempos the library
is short of, which the deploy script works out each time (`data/wanted_bpm.csv`).

**Live:** <https://beatspermillion.shinyapps.io/dance/> (shinyapps.io account
`beatspermillion`, app `dance`; free plan, 25 active hours a month). The online
settings are at the top of `deploy/deploy_shinyapps.R` — currently
`DEFAULT_PLAYER = "spotify"` and `SPOTIFY_LOGIN = "off"` (no Spotify login
online, so Spotify plays 30-s previews; `"testers"` enables the invited-tester
login via `?testers`). Re-run the script after every change. The deployment
record in `rsconnect/` is git-ignored. Logs:
`rsconnect::showLogs(appName = "dance", account = "beatspermillion")`.

### Generate playlist templates

```r
source("run_generator.R")
```

This writes CSV/XLSX playlist templates to `output/` and seeds
`data/song_library.csv` if it doesn't exist yet (it never overwrites it).

---

## 📁 Project Structure

```
climate_playlist/
├── app.R                      # Shiny application
├── run_generator.R            # Playlist templates + seeds the song library
├── R/
│   ├── config.R               # Constants & time-period definitions
│   ├── period_context.R       # Background texts + key events per period
│   ├── functions.R            # CO2→BPM, playlist generation, song matcher
│   ├── load_data.R            # Data + song-library loading
│   ├── settings.R             # Local vs deployed, default player, who may log in
│   ├── spotify.R              # Spotify login (per visitor online), player, Save to Spotify
│   ├── about.R                # "About & privacy" window
│   ├── library_check.R        # Is the song library good enough to launch?
│   ├── enrich_library.R       # Fills blank BPM / Spotify / SoundCloud / YouTube cells
│   ├── share.R                # Link previews, "Suggest a song", tempos that need songs
│   ├── refresh_co2.R          # Fetch + check NOAA's newest Mauna Loa file
│   └── _disable_autoload.R    # Stops runApp() from sourcing everything in R/
├── www/
│   ├── player.js              # In-app players, progress + auto-advance
│   └── og-image.png           # Link-preview picture (data-raw/make_og_image.R)
├── deploy/deploy_shinyapps.R  # Puts the app online (shinyapps.io)
├── .github/workflows/         # tests on every push; monthly Mauna Loa refresh (PR)
├── rsconnect/                 # Deployment record (git-ignored)
├── data/
│   ├── co2_data.xlsx          # Processed: 'maunaloa' + 'bereiter2014' sheets
│   ├── song_library.csv       # Your songs + their real BPM (matched at run time)
│   ├── song_library_enrich_log.csv  # Review log of the last enrichment run
│   ├── wanted_bpm.csv         # Tempos that need songs (made on deploy, git-ignored)
│   ├── backups/               # Library backups made by the enrichment (git-ignored)
│   └── rawData/               # Raw CO2 files + provenance README
├── data-raw/
│   ├── build_co2_data.R       # Rebuilds co2_data.xlsx from rawData/
│   ├── update_maunaloa.R      # Fetches NOAA's newest months, then rebuilds
│   ├── make_og_image.R        # Draws www/og-image.png
│   ├── enrich_song_library.R  # Run the song-library enrichment
│   └── check_song_library.R   # Library report: fixes, gaps, READY / NOT YET
├── tests/testthat/            # Unit tests
├── output/                    # Generated playlist templates (+ library_check/, git-ignored)
├── .Renviron.example          # Template for API keys and app settings (copy to .Renviron)
├── LAUNCH.md                  # Going online: setup, player test, launch criteria
├── MUSIC_SETUP.md             # Players, keys, song links, troubleshooting
├── DEVELOPMENT.md             # renv, data rebuild, tests
└── README.md
```

---

## 📚 Data Sources

### Modern Observations (1958–Present)
- **Source:** NOAA Mauna Loa Observatory
- **URL:** https://gml.noaa.gov/ccgg/trends/
- **Description:** Direct atmospheric CO₂ measurements (the "Keeling Curve")
- **Updates:** `source("data-raw/update_maunaloa.R")` fetches NOAA's newest
  months, checks them and rebuilds `data/co2_data.xlsx`. A GitHub Action does
  the same on the 9th of every month and opens a pull request when there is
  something new (`.github/workflows/refresh-co2.yml`).

### Ice Core Record (0–800,000 years)
- **Source:** Bereiter et al. (2015)
- **URL:** https://www.ncei.noaa.gov/access/paleo-search/
- **Citation:** Bereiter, B., et al. (2015). Revision of the EPICA Dome C CO2 record from 800 to 600 kyr before present. *Geophysical Research Letters*, 42(2), 542-549.

### Cenozoic Proxies (0–66 million years)
- **Source:** Rae et al. (2021)
- **URL:** https://doi.org/10.1146/annurev-earth-082420-063026
- **Citation:** Rae, J.W.B., et al. (2021). Atmospheric CO2 over the Past 66 Million Years from Marine Archives. *Annual Review of Earth and Planetary Sciences*, 49, 609-641.
- **Methods:** Boron isotopes (δ¹¹B) and alkenone δ¹³C

---

## 🔧 How It Works

### CO₂ to BPM Conversion

```r
bpm = 60 + (90 / (co2_max - co2_min)) × (co2 - co2_min)
```

The app has two **BPM scaling** modes:

- **Per period (default, max. contrast):** each period is scaled on its own, so
  the **lowest** CO₂ in that period → 60 BPM and the **highest** → 150 BPM. This
  highlights the variation *within* a period, but also amplifies small wiggles
  (e.g. the nearly flat Roman era).
- **Global (comparable eras):** all periods share one scale (≈174–1963 ppm), so
  the same CO₂ always gives the same BPM and eras can be compared directly.

### Time Compression

Each playlist compresses geological time into listenable duration:

| Period | Compression | 1 song ≈ |
|--------|-------------|----------|
| Modern | 1:1 | 3 years |
| Roman | 20:1 | 60 years |
| LGM | 100:1 | 300 years |
| Humans | 1000:1 | 3,000 years |
| Ice Core | 3000:1 | 9,000 years |
| Cenozoic | 250,000:1 | 750,000 years |

---

## 🎧 Using the Song Library

The app plays songs from one hand-built library, `data/song_library.csv`,
**matched to each playlist slot by tempo** at run time. Because the match is by
BPM rather than a fixed slot, refreshing the climate data can never misalign
your picks.

Columns: `song_title, artist, spotify_uri, soundcloud_url, bpm, notes, youtube_url`.
Saving from Excel is fine (columns can be reordered, extra columns are ignored).

### How matching works

- For each slot the app looks for a song within **±5 BPM**, then **±10 BPM**,
  then takes the **single nearest** song. Only an empty library leaves a slot
  with search buttons.
- A song is **never repeated within one period**.
- **🔀 Shuffle** re-rolls the picks; otherwise the same period always shows the
  same songs (seeded from the period name).
- Matching follows the selected **BPM scaling** (per period vs global).
- Only **playable** songs (a BPM plus a Spotify, SoundCloud or YouTube link) are used.

### Playback

- **Play via Spotify is the default.** Order: Spotify full player (after
  *Connect Spotify*, needs Premium) → YouTube → SoundCloud → Spotify 30-s
  preview. **Play via** lets you prefer YouTube or SoundCloud instead.
- **Full songs via Spotify need a one-time *Connect Spotify* login** (Spotify
  Premium). Until then Spotify only allows 30-s previews, and the app shows a
  *Connect Spotify to play the full song* button right at the player.
- If a YouTube video refuses to play (many label videos block other websites),
  the app says why, switches that song to the next player, and remembers the
  video in `data/youtube_blocked.csv` so it is skipped from then on.
- Songs play in full; the ball on the CO₂ curve travels through the song's time
  window, and with *Auto-play next song* ticked the next slot starts when a song ends.
- **Play via Spotify stays on Spotify** (YouTube is only used if you pick it):
  only songs with a Spotify link are matched. Not connected → Spotify's 30-s
  clips, which auto-play one after another once you've pressed ▶ on the first
  (songs without a clip are skipped). Connected → whole songs or snippets.
- **Song length:** *Whole song* (default) or *30-s snippets* — a quick run
  through a period so you really hear the tempo climb. Snippets start at the
  beginning, at 0:30 (skip the intro, default) or in the middle of the song,
  and auto-advance just like whole songs. Works with Spotify (connected),
  YouTube and SoundCloud; you can switch mid-song.
- **Skip preview-only songs** (on by default) matches only songs that can play to the
  end: those with a YouTube or SoundCloud link, plus Spotify-only songs once
  *Connect Spotify* is active. Untick it to also use Spotify-only songs, which
  play a 30-s preview and don't auto-advance when Spotify isn't connected.
- **➕ Save to Spotify** saves the current period's songs (oldest → youngest)
  as a private playlist in your Spotify account.
- **Settings, no code changes:** the player visitors start with
  (`BPM_DEFAULT_PLAYER`) and who sees *Connect Spotify* (`BPM_SPOTIFY_LOGIN`:
  everyone locally, only `?testers` visitors online) — see `.Renviron.example`.
  `?player=youtube` in the URL picks a player directly.

Setup of keys, the Spotify developer app and sharing with a colleague:
[`MUSIC_SETUP.md`](MUSIC_SETUP.md).

### Is the library ready?

```r
source("data-raw/check_song_library.R")
```

Lists rows to fix (no BPM, no or broken links, BPM outside 60–150, duplicates,
YouTube videos that can't be embedded), simulates the matcher for every period
and both scaling modes, shows which BPM ranges need more songs, and ends with a
**READY / NOT YET** verdict. Details go to `output/library_check/`. With
`CHECK_LINKS <- TRUE` it also tests every link online through the services'
public oEmbed endpoints (no keys), including whether a link points to the right
song. Launch criteria: [`LAUNCH.md`](LAUNCH.md#6-get-the-library-ready-ongoing).

### Finding a song's BPM

- **Automatically:** add rows with just `song_title` + `artist`, then run
  `source("data-raw/enrich_song_library.R")`. It fills only **blank** `bpm`,
  `spotify_uri`, `soundcloud_url` and `youtube_url` cells (steps without a key
  are skipped), backs up the CSV to `data/backups/` first, and writes a review
  log to `data/song_library_enrich_log.csv`. BPM comes from the
  [GetSongBPM](https://getsongbpm.com) API (see below).
- **By hand:** look it up on [GetSongBPM](https://getsongbpm.com),
  [TuneBat](https://tunebat.com) or [songbpm.com](https://songbpm.com).
- **Watch half-/double-time.** Tempo databases sometimes list a song at half or
  double its felt tempo (a 70 BPM ballad listed as 140). The enrichment flags
  values outside 60–150 BPM in the log; enter the tempo the song *feels* like.

### 🎼 BPM data: GetSongBPM

Song tempos looked up automatically come from the **[GetSongBPM API](https://getsongbpm.com/api)**
(`GETSONGBPM_KEY` in `.Renviron`). The API is free, but its terms require a
**visible link back to [getsongbpm.com](https://getsongbpm.com)** on a public
page of the project. The link in the footer of the live app
(<https://beatspermillion.shinyapps.io/dance/>) is the registered backlink, and
this section repeats it. Please keep both if you fork or reuse the project.
Rate limit: 3,000 requests per hour.

---

## 📄 License

This project is released under the MIT License.

---

## 🙏 Acknowledgments

- Charles David Keeling for beginning the Mauna Loa CO₂ record in 1958
- The ice core drilling teams at EPICA, Vostok, and other Antarctic sites
- The paleoclimate community for developing CO₂ proxy methods
- [GetSongBPM](https://getsongbpm.com) for song tempo (BPM) data
