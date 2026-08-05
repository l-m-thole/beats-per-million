# 🌍 Beats per Million — Dance While You Can

**Translating Earth's Climate History into Music**

This project converts atmospheric CO₂ concentrations through geological time into "beats per minute" (BPM) values, creating a unique sonic experience of climate change. Lower CO₂ (ice ages) produces slow, ambient music; higher CO₂ (hothouse conditions) produces fast, energetic music.

A collaboration between **Martin Wegmann** and **Lena Thöle**.

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

| Period | Time Span | Songs | Data Source |
|--------|-----------|-------|-------------|
| **Modern Era** | 1958–Present | ~22 | Mauna Loa Observatory |
| **Roman Empire** | ~2,000 years | ~34 | Antarctic ice cores |
| **Last Glacial Maximum** | ~20,000 years | ~67 | Antarctic ice cores |
| **Early Humans** | ~250,000 years | ~84 | Antarctic ice cores |
| **Full Ice Core** | ~800,000 years | ~89 | Antarctic ice cores |
| **Cenozoic Era** | ~66 million years | ~88 | Marine proxy records |

---

## 🚀 Getting Started

### Prerequisites

```r
install.packages(c(
  "shiny",
  "readxl",
  "dplyr",
  "tibble",
  "readr",
  "plotly",
  "DT",
  "writexl",
  "here"
))
```

### Run the Shiny App

Open `climate_playlists.Rproj` in RStudio (this sets the working directory to the project root), then:

```r
shiny::runApp()
```

### Generate Playlist Templates

```r
source("run_generator.R")
```

This creates CSV files in `output/` with columns for adding your own song selections.

---

## 📁 Project Structure

```
climate_playlists/
├── R/
│   ├── config.R          # Shared constants & time periods
│   ├── functions.R       # CO2→BPM conversion, playlist generation
│   └── load_data.R       # Data loading & normalization
├── app.R                 # Shiny application
├── run_generator.R       # CLI script for generating templates + seeding the library
├── data/
│   ├── co2_data.xlsx     # Processed: 'maunaloa' + 'bereiter2014' sheets
│   ├── song_library.csv  # Your songs + their real BPM (matched to slots at runtime)
│   └── rawData/
│       ├── co2_mm_mlo.csv      # Raw monthly Mauna Loa CO2 (NOAA)
│       ├── rae2021co2.xlsx     # Cenozoic proxy data (Rae et al. 2021)
│       └── eggleston2016.xlsx  # Antarctic 155 kyr CO2 + isotopes (currently unused)
├── output/               # Generated playlist templates
└── README.md
```

---

## 📚 Data Sources

### Modern Observations (1958–Present)
- **Source:** NOAA Mauna Loa Observatory
- **URL:** https://gml.noaa.gov/ccgg/trends/
- **Description:** Direct atmospheric CO₂ measurements (the "Keeling Curve")

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

Each time period is scaled independently, so:
- The **lowest** CO₂ in that period → 60 BPM
- The **highest** CO₂ in that period → 150 BPM

This ensures the full BPM range is used for each playlist, highlighting the relative climate variation within each timeframe.

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

The app plays songs from a single hand-built library, **matched to each playlist
slot by tempo** at run time. Because the match is by BPM rather than a fixed
slot, refreshing the climate data can never misalign your picks.

1. **Seed the file (first time):** `source("run_generator.R")` creates
   `data/song_library.csv` with a header and two example rows. It never
   overwrites an existing library.
2. **Add songs:** open `data/song_library.csv` and fill one row per song:
   - `song_title`, `artist`
   - `spotify_uri` — any of `spotify:track:<id>`, an `https://open.spotify.com/track/<id>` URL, or the bare id
   - `soundcloud_url` — the public track URL
   - `bpm` — the song's **real tempo** (see below)
   - `notes` — anything you like

   Delete the two example rows once you've added real songs. Saving from Excel is
   fine: columns can be reordered and extra columns are ignored on load.
3. **Run the app:** `shiny::runApp()`, pick a period, and click a song in the
   Playlist. If a library song is near that slot's BPM you get an embedded
   Spotify/SoundCloud player plus "Open in…" links; if nothing matches yet you
   get BPM search buttons.

### Finding a song's BPM

- Look it up on [TuneBat](https://tunebat.com) or [songbpm.com](https://songbpm.com).
- **Watch half-/double-time tags.** These tools sometimes report a track at half
  or double its felt tempo (e.g. a 70 BPM song listed as 140). Enter the tempo
  that matches how the song actually *feels*, or the matching will be off — a
  quick `half-time?` in `notes` helps you remember which ones you second-guessed.

### How matching works

- For each slot the app looks for a library song within **±5 BPM** of the slot's
  target, then widens to **±10 BPM**, then falls back to the **single nearest**
  song. Only an empty library leaves a slot with search buttons.
- A song is **never repeated within one period**, so the more songs you add the
  more slots fill in — a ~90-song library comfortably covers even the longest
  playlist.
- **🔀 Shuffle** re-rolls which songs land in the current period's slots.
  Otherwise picks are reproducible: the same period shows the same songs each
  time until you shuffle.
- Matching uses the **currently selected BPM scaling mode** (per-period vs
  global), so switching modes can change which songs match a slot.

---

## 📄 License

This project is released under the MIT License.

---

## 🙏 Acknowledgments

- Charles David Keeling for beginning the Mauna Loa CO₂ record in 1958
- The ice core drilling teams at EPICA, Vostok, and other Antarctic sites
- The paleoclimate community for developing CO₂ proxy methods
