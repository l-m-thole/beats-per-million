# 🌍 Beats per Million — Dance While You Can

[![tests](https://github.com/l-m-thole/climate_playlist/actions/workflows/tests.yml/badge.svg)](https://github.com/l-m-thole/climate_playlist/actions/workflows/tests.yml)

**Translating Earth's Climate History into Music**

This project converts atmospheric CO₂ concentrations through geological time into "beats per minute" (BPM) values, creating a unique sonic experience of climate change. Lower CO₂ (ice ages) produces slow music; higher CO₂ (hothouse conditions) produces fast, energetic music.

A collaboration between **Martin Wegmann** and **Lena Thöle**.

**▶ Try it (test version):** <https://beatspermillion.shinyapps.io/dance/> —
Spotify plays 30-second previews; pick *Play via YouTube* for whole songs.

---

## 🎵 The Concept

| Climate State | CO₂ (ppm) | BPM (global scale) | Feel |
|---------------|-----------|-----|------|
| Glacial maximum | ~180 | 60 | Glacial |
| Pre-industrial | ~280 | 65 | Glacial |
| Modern day | ~420 | 72 | Slow |
| Eocene hothouse | ~1500 | 127 | Upbeat |

With the default **per-era** scale each era's own lowest CO₂ is 60 BPM and its
highest 150 BPM, so within the Modern Era the tempo climbs from about 60 to
about 150 BPM.

*Feel* names the tempo band of a slot (Glacial < 70, Slow 70–84, Relaxed 85–99,
Moderate 100–114, Upbeat 115–129, Energetic 130–144, Intense 145+ BPM). It
describes the tempo, not the song: the matched song can be any genre. (The
playlist templates from `run_generator.R` still add genre ideas per band.)

---

## 📊 Time Periods

| Period | Time Span | Songs | Data Source | Key events in the app (a selection) |
|--------|-----------|-------|-------------|------------------------|
| **Modern Era** | 1958–Present | ~23 | Mauna Loa Observatory | Keeling starts measuring, IPCC, Kyoto, 400 ppm crossed, Paris Agreement |
| **Industrial Era** | 1850–Present | ~24 | CMIP7 historical CO₂ (+ Mauna Loa after 2022) | Industrial Revolution, Arrhenius 1896, Great Acceleration, Keeling, Paris Agreement |
| **Roman Empire** | ~2,000 years | ~34 | Antarctic ice cores | Roman Climate Optimum, 536 CE eruptions, Medieval warmth, Little Ice Age, Industrial Revolution |
| **Last Glacial Maximum** | ~20,000 years | ~67 | Antarctic ice cores | LGM, Bølling–Allerød, Younger Dryas, start of the Holocene, Sweden ice-free, 8.2 kyr event |
| **Early Humans** | ~250,000 years | ~84 | Antarctic ice cores | Eemian interglacial, Toba eruption, Out of Africa, humans in Europe |
| **Full Ice Core** | ~800,000 years | ~89 | Antarctic ice cores | Mid-Brunhes Event, MIS 11, first Homo sapiens, 100-kyr ice-age cycles |
| **Cenozoic Era** | ~66 million years | ~88 | Marine proxy records | K–Pg impact, PETM, Eocene hothouse, Antarctic ice sheet, Pliocene (CO₂ ≈ today) |

Song counts are for the current data and change slightly when the data are refreshed.
With **Playlist length: Long** every era has twice as many songs (Modern ~46 …
Full Ice Core ~178), each standing for half as many years.

In the app, each period (era) has:

- an **About this era** window (button on the CO₂ plot): short description,
  key numbers, **how the CO₂ was measured** for that era, background (what drove
  CO₂, what to listen for) and a **key-events timeline** (oldest → youngest);
- **event markers** (▼ and dotted lines) on the CO₂ plot — hover for details;
- a **"During this song"** box in the Listen panel that lists any key event
  inside the selected song's time window.

The texts, events and measurement notes live in `R/period_context.R` (ages in
years BP, i.e. before 1950; modern events are written as CE years and
converted). Add or edit events there — `tests/testthat/test-period_context.R`
checks that every event falls inside its period.

### The app at a glance

- **Header:** title, one line on what to do (*Pick an era → press play → dance
  while you can*), **💡 How it works** (method, how songs are chosen, where the
  CO₂ numbers come from, how the app came about, who made it) and *About &
  privacy*.
- **Era buttons** in a row under the header.
- **CO₂ through time:** a plain plot (no zoom or toolbar). The selected song's
  slice is highlighted; click the curve to jump to the song for that time.
- **Playlist:** one row per song, oldest first — *Song* (title, artist),
  *Years*, *CO₂*, *BPM* (the slice's tempo), *Song BPM* (the song's own tempo)
  and *Feel*. Above it: **BPM scale** (per era / global), **Playlist length**
  (*Standard* / *Long*, 2× songs), **🔀 Shuffle songs** and, while playing via
  Spotify, **🖼 Show album covers** (covers above each song's slice on the plot).
- **Listen** (next to the playlist, stays in view while you scroll; on phones
  it comes right after the plot): the song, the player (behind a **▶ Play via …**
  button until you press it, see *Privacy* below), **⏮ Previous / Next ⏭**,
  the song's years, CO₂ and tempo, *how this song was picked*, and the player
  options.

The *How it works* texts are in `R/how_it_works.R`; the story and the
"who made this" lines are plain text at the top of that file (`APP_STORY`,
`APP_MAKERS`) — edit them freely.

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
│   ├── about.R                # "About & privacy" window + the ▶ Play gate text
│   ├── how_it_works.R         # "How it works" + "About this era" windows (edit the story here)
│   ├── covers.R               # Album covers for the plot (Spotify oEmbed + cache)
│   ├── library_check.R        # Is the song library good enough to launch?
│   ├── enrich_library.R       # Fills blank BPM / Spotify / SoundCloud / YouTube cells
│   ├── share.R                # Link previews, "Suggest a song", tempos that need songs
│   ├── refresh_co2.R          # Fetch + check NOAA's newest Mauna Loa file
│   └── _disable_autoload.R    # Stops runApp() from sourcing everything in R/
├── www/
│   ├── player.js              # Play gate, in-app players, progress + auto-advance
│   ├── fonts/                 # Self-hosted fonts (OFL) - no Google Fonts request
│   └── og-image.png           # Link-preview picture (data-raw/make_og_image.R)
├── deploy/deploy_shinyapps.R  # Puts the app online (shinyapps.io)
├── .github/workflows/         # tests on every push; monthly Mauna Loa refresh (PR)
├── rsconnect/                 # Deployment record (git-ignored)
├── data/
│   ├── co2_data.xlsx          # Processed: 'maunaloa' + 'bereiter2014' sheets
│   ├── song_library.csv       # Your songs + their real BPM (matched at run time)
│   ├── song_library_enrich_log.csv  # Review log of the last enrichment run
│   ├── song_covers.csv        # Album-cover addresses (data-raw/fetch_covers.R, also on deploy)
│   ├── wanted_bpm.csv         # Tempos that need songs (made on deploy, git-ignored)
│   ├── backups/               # Library backups made by the enrichment (git-ignored)
│   └── rawData/               # Raw CO2 files + provenance README
├── data-raw/
│   ├── build_co2_data.R       # Rebuilds co2_data.xlsx from rawData/
│   ├── update_maunaloa.R      # Fetches NOAA's newest months, then rebuilds
│   ├── make_og_image.R        # Draws www/og-image.png
│   ├── enrich_song_library.R  # Run the song-library enrichment
│   ├── fetch_covers.R         # Looks up album covers -> data/song_covers.csv
│   └── check_song_library.R   # Library report: fixes, gaps, READY / NOT YET
├── tests/testthat/            # Unit tests
├── output/                    # Generated playlist templates (+ library_check/, git-ignored)
├── .Renviron.example          # Template for API keys and app settings (copy to .Renviron)
├── LAUNCH.md                  # Going online: setup, player test, launch criteria
├── MUSIC_SETUP.md             # Players, keys, song links, troubleshooting
├── DEVELOPMENT.md             # renv, data rebuild, tests, platform rules
├── LICENSE, LICENSE.md        # MIT (code); data, fonts and music have their own terms
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

### Industrial Era (1850–Present)
- **Source:** CMIP7 historical greenhouse-gas concentrations, CR-CMIP-1-0-0
  (Climate Resource), annual global-mean CO₂ 1750–2022 —
  `data/rawData/co2_1750-2022.csv` (from Martin). The era starts in 1850, where
  CMIP historical model runs start.
- **URL:** https://doi.org/10.5281/zenodo.14892947
- **Citation:** Nicholls, Z., Meinshausen, M., Pflüger, M. & Lewis, J. (2025). *CMIP GHG Forcing* (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.14892947
- **After 2022:** Mauna Loa annual means (complete years only), lowered by the
  mean Mauna Loa − CMIP7 difference of the last 10 shared years (~1.1 ppm), so
  the curve has no step (`splice_cmip7_maunaloa()` in `R/refresh_co2.R`). The
  monthly Mauna Loa refresh keeps this era current too.

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

- **Per era (default, max. contrast):** each period is scaled on its own, so
  the **lowest** CO₂ in that period → 60 BPM and the **highest** → 150 BPM. This
  highlights the variation *within* a period, but also amplifies small wiggles
  (e.g. the nearly flat Roman era).
- **Global (compare eras):** all periods share one scale (≈174–1963 ppm), so
  the same CO₂ always gives the same BPM and eras can be compared directly.

### Time Compression

Each playlist compresses geological time into listenable duration:

| Period | Compression | 1 song ≈ |
|--------|-------------|----------|
| Modern | 1:1 | 3 years |
| Industrial | 2.5:1 | 7.5 years |
| Roman | 20:1 | 60 years |
| LGM | 100:1 | 300 years |
| Humans | 1000:1 | 3,000 years |
| Ice Core | 3000:1 | 9,000 years |
| Cenozoic | 250,000:1 | 750,000 years |

**Playlist length: Long** cuts every slice in two (`PLAYLIST_LENGTHS` in
`R/config.R`, `generate_playlist(length_factor = 2)`): twice the songs, each
for half as many years (Modern 1.5 years … Cenozoic 375,000 years), so you hear
more detail and the playlist plays twice as long. The slices line up — long
songs 2k−1 and 2k are standard song k — so switching keeps your place in time.
The BPM scale is the same, so the tempo climbs at half the speed per minute;
with *30-s snippets* the climb is smooth and quick. Standard playlists are made
at startup, long ones the first time someone picks them (then cached).

---

## 🎧 Using the Song Library

The app plays songs from one hand-built library, `data/song_library.csv`,
**matched to each playlist slot by tempo** at run time. Because the match is by
BPM rather than a fixed slot, refreshing the climate data can never misalign
your picks.

Columns: `song_title, artist, spotify_uri, soundcloud_url, bpm, notes, youtube_url`.
Saving from Excel is fine (columns can be reordered, extra columns are ignored).

### How matching works

- For each slot the app takes the songs within **±3 BPM** and picks one **at
  random**; if none is left it widens to **±5**, then **±10 BPM**, then takes
  the **single nearest** song (the windows are `MATCH_TOLS` in `R/config.R`).
  Only an empty library leaves a slot with search buttons.
- **Follows the curve:** when the tempo rises from one slot to the next, the
  pick is narrowed to songs **faster than the song before** (slower when it
  falls), as long as the window has one — so two good matches never step
  against the curve without need (e.g. 66 → 65 BPM while CO₂ rises). The window
  never widens for this. In the first Modern playlist (Spotify) the step-backs
  went from 4 to 0 (Long: 10 to 1); over all eras from ~11 % to ~1 % of the
  song changes (Long: ~13 % to ~3 %).
- A song is **never repeated within one period** — Long playlists included.
  Early Humans and Cenozoic need more songs before every Long slot matches
  within ±3 BPM (see *Is the library ready?*).
- **Transparent:** the playlist shows the slot's tempo (*BPM*) next to the
  song's own (*Song BPM*), and the Listen panel says how the song was found
  (e.g. *+2 BPM from the target · picked at random from 8 songs within ±3 BPM
  that are faster than the song before*; `match_tol` / `n_candidates` / `trend`
  from `pick_song_widening()`).
- **🔀 Shuffle songs** re-rolls the random picks — other songs, same tempos. The
  order never changes (always oldest → youngest). Without shuffling, the same
  period always shows the same songs (seeded from the period name).
- Matching follows the selected **BPM scale** (per era vs global).
- Only **playable** songs (a BPM plus a Spotify, SoundCloud or YouTube link) are used.

### Playback

- **One service per playlist.** *Play via* picks Spotify (the default),
  YouTube or SoundCloud, and the playlist only uses songs that service can
  play — never a mix (Spotify's and SoundCloud's terms don't allow mixing their
  music with another service's; see DEVELOPMENT.md). Spotify: the full player
  after *Connect Spotify* (needs Premium), otherwise 30-s clips. YouTube and
  SoundCloud: whole songs, no login.
- **Full songs via Spotify need a one-time *Connect Spotify* login** (Spotify
  Premium). Until then Spotify only allows 30-s previews, and the app shows a
  *Connect Spotify to play the full song* button right at the player.
- If a YouTube video refuses to play (some label videos block other websites),
  the app says why, leaves it out for that visitor and — if music was playing —
  moves on to the next song (never to another service). It is written to
  `data/youtube_blocked.csv` (left out for good) only once a YouTube song has
  really played in that browser, and after 3 refusals in a row the playlist
  stops — so an ad blocker or a YouTube hiccup can't block the whole library.
- Songs play in full; the ball on the CO₂ curve travels through the song's time
  window, and with *Auto-play the next song when one ends* ticked the next slot
  starts when a song ends.
- **⏮ Previous / Next ⏭** in the Listen panel step through the playlist.
- **A new song only starts by itself while music is playing.** Clicking another
  song, Previous / Next or another era keeps the music going if it was playing;
  after you pause (or once a song ended with auto-play off), nothing starts on
  its own. `www/player.js` reports play / pause from every player
  (`input$player_state`).
- **Play via Spotify** without a login: Spotify's 30-s clips, which auto-play
  one after another once you've pressed ▶ on the first (songs without a clip
  are skipped). Connected → whole songs or snippets.
- **Song length:** *Whole song* (default) or *30-s snippets* — a quick run
  through a period so you really hear the tempo climb. Snippets start at the
  beginning, at 0:30 (skip the intro, default) or in the middle of the song,
  and auto-advance just like whole songs. Works with Spotify (connected),
  YouTube and SoundCloud; you can switch mid-song.
- **➕ Save to Spotify** saves the current period's songs (oldest → youngest)
  as a private playlist in your Spotify account.
- **Settings, no code changes:** the player visitors start with
  (`BPM_DEFAULT_PLAYER`) and who sees *Connect Spotify* (`BPM_SPOTIFY_LOGIN`:
  everyone locally, only `?testers` visitors online) — see `.Renviron.example`.
  `?player=youtube` in the URL picks a player directly.

Setup of keys, the Spotify developer app and sharing with a colleague:
[`MUSIC_SETUP.md`](MUSIC_SETUP.md).

### Privacy: nothing loads before ▶ Play

Opening the page contacts no one but the app's own server: the fonts are
served from `www/fonts/` (no Google Fonts), and no code from Spotify, YouTube
or SoundCloud is in the page. Instead of a player, the Listen panel first
shows **▶ Play via Spotify** (or YouTube / SoundCloud) with two lines on what
that service then receives (your IP address, its cookies; for YouTube also its
Terms of Service). Pressing it loads that service's player and starts the
song; the OK lasts until the page is reloaded. YouTube only starts a song by
itself while its player is on screen (on phones the page scrolls back to it).
(Not in YouTube's `youtube-nocookie.com` mode: there YouTube refused 22 of 23
songs in a test.)
The Spotify SDK is only loaded after a Spotify login, and album covers only
when you switch them on. The texts live in `R/about.R` (`player_gate()` and
*About & privacy*); the loading in `www/player.js`.

### Album covers

*🖼 Show album covers* (above the playlist, only while playing via Spotify)
puts each song's cover above its time slice on the CO₂ plot, with a
"covers from Spotify" credit under the plot; hover shows the song, click
selects it. Covers come from Spotify's public oEmbed endpoint (no key) and are
cached in `data/song_covers.csv`:

```r
source("data-raw/fetch_covers.R")   # looks up covers for new songs (a second or two)
```

The deploy script does the same before every deploy, so the online app never
has to ask Spotify. Songs missing from the file are looked up once when someone
switches covers on; songs without a Spotify cover get none (no YouTube
thumbnails mixed in - Spotify's terms).
For long eras (80+ songs) the covers become a thin strip — hover still works.

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
song, and lists YouTube links from channels that don't look official (lyrics,
promo or fan uploads — swap them for the artist's, VEVO or "Artist - Topic"
upload; write "label upload" in a song's notes once you've checked a label's
channel by hand). Launch criteria: [`LAUNCH.md`](LAUNCH.md#6-get-the-library-ready-ongoing).
It also simulates the **Long** playlists (per-era scale, `PUBLIC_POOL`) and
lists the BPM ranges they still need songs in — for information, not a launch
criterion (`coverage_long.csv`, `gaps_long.csv`).

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

The code is released under the MIT License — © 2026 Lena Thöle and Martin
Wegmann, see [`LICENSE.md`](LICENSE.md). The CO₂ data (NOAA; Bereiter et al. 2015
and Rae et al. 2021 via NOAA's paleo archive, CC0 — please cite them), the fonts
(SIL Open Font License) and the music the app plays keep their own terms.

---

## 🙏 Acknowledgments

- Charles David Keeling for beginning the Mauna Loa CO₂ record in 1958
- The ice core drilling teams at EPICA, Vostok, and other Antarctic sites
- The paleoclimate community for developing CO₂ proxy methods
- [GetSongBPM](https://getsongbpm.com) for song tempo (BPM) data
