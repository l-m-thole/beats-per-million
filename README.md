# 🌍 Climate Playlists

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
  "tidyverse",
  "plotly",
  "DT",
  "writexl"
))
```

### Run the Shiny App

```r
setwd("path/to/climate_playlists")
shiny::runApp()
```

### Generate Playlist Templates

```r
setwd("path/to/climate_playlists")
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
├── run_generator.R       # CLI script for generating templates
├── data/
│   ├── co2_data.xlsx     # Modern + ice core data
│   └── raw/
│       └── rae2021co2.xlsx   # Cenozoic proxy data
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

## 🎧 Using the Playlists

1. **Generate templates:** Run `source("run_generator.R")`
2. **Open CSVs:** Find them in `output/`
3. **Find songs:** Use Spotify/SoundCloud to search for songs at each target BPM
4. **Fill in:** Add song titles, artists, and URIs to the template
5. **Create playlist:** Import into your music platform

### BPM Search Tips

- Spotify: Search `bpm:120` or use tools like [Sort Your Music](http://sortyourmusic.playlistmachinery.com/)
- SoundCloud: Search "120 bpm ambient" or similar
- Genres often have typical BPM ranges that match the mood suggestions

---

## 📄 License

This project is released under the MIT License.

---

## 🙏 Acknowledgments

- Charles David Keeling for beginning the Mauna Loa CO₂ record in 1958
- The ice core drilling teams at EPICA, Vostok, and other Antarctic sites
- The paleoclimate community for developing CO₂ proxy methods
