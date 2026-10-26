# =============================================================================
# CLIMATE PLAYLISTS - SHARED CONFIGURATION
# =============================================================================
#
# This file contains all shared constants and time period configurations.
# Source this file in all other scripts to ensure consistency.
#
# =============================================================================

# -----------------------------------------------------------------------------
# GLOBAL CONSTANTS
# -----------------------------------------------------------------------------

# BPM range for music mapping
# 60 BPM = very slow (ambient, funeral march)
# 150 BPM = very fast (dance, electronic)
BPM_MIN <- 60
BPM_MAX <- 150

# Song matching: the BPM windows (± around a slice's tempo) the matcher tries,
# in this order. It picks at random among the unused songs in the first window
# that has any, and takes the closest song when none has. The first window is
# also the "good match" the library check and the wanted tempos aim for.
MATCH_TOLS <- c(3, 5, 10)

# SoundCloud is built in but hidden for now: no SoundCloud button, no
# "Play via SoundCloud" and no SoundCloud lines in About & privacy.
# Set to TRUE to bring it back (Play via also needs SoundCloud links).
SHOW_SOUNDCLOUD <- FALSE

# Average song length in minutes
AVG_SONG_LENGTH <- 3

# Reference year for age calculations (standard paleoclimate convention)
REFERENCE_YEAR <- 1950

# -----------------------------------------------------------------------------
# DATA SOURCE IDENTIFIERS
# -----------------------------------------------------------------------------

DATA_SOURCE_MODERN   <- "modern"      # Mauna Loa direct measurements
DATA_SOURCE_CMIP7    <- "cmip7"       # CMIP7 historical CO2 (1750-2022) + Mauna Loa after
DATA_SOURCE_ICECORE  <- "icecore"     # Bereiter et al. 2015 ice core composite
DATA_SOURCE_CENOZOIC <- "cenozoic"    # Rae et al. 2021 proxy reconstructions

# Data sources on a calendar-year axis: ages are years before 1950 and go
# negative after 1950; the span comes from the data, songs are labelled in CE.
CALENDAR_SOURCES <- c(DATA_SOURCE_MODERN, DATA_SOURCE_CMIP7)

#' Is this data source shown in calendar years (CE)?
is_calendar_source <- function(source) isTRUE(source %in% CALENDAR_SOURCES)

# CMIP7 era: first year, and the Mauna Loa years used to line the two records up
# (Mauna Loa reads ~1 ppm above the global mean; see splice_cmip7_maunaloa()).
CMIP7_START_YEAR <- 1850
CMIP7_OVERLAP_YEARS <- 10

# -----------------------------------------------------------------------------
# TIME PERIOD CONFIGURATIONS
# -----------------------------------------------------------------------------
#
# Each period has:
#   id              - Short identifier (used in filenames, code)
#   name            - Display name
#   short_name      - Name on the era buttons at the top of the app
#   span_label      - Second line on the era buttons (how far back it goes)
#   years_span      - Total years covered
#   years_per_minute - Compression ratio (how many years = 1 minute of music)
#   data_source     - Which dataset to use
#   filter_min_age  - Minimum age in years BP to include (default: 0)
#   filter_max_age  - Maximum age in years BP to include
#   description     - Scientific context for display
#   color           - Theme color for UI
#
# -----------------------------------------------------------------------------

TIME_PERIODS <- list(
  
  # -------------------------------------------------------------------------
  # MODERN ERA - Direct atmospheric measurements
  # -------------------------------------------------------------------------
  modern = list(
    id = "modern",
    name = "Modern Era (1958–Present)",
    short_name = "Modern Era",
    span_label = "1958 – today",
    years_span = 67,           # Modern span is derived from the data at run time (see generate_playlist)
    years_per_minute = 1,
    data_source = DATA_SOURCE_MODERN,
    filter_min_age = -Inf,
    filter_max_age = Inf,
    description = paste(
      "Direct atmospheric CO₂ measurements from Mauna Loa Observatory, Hawaii.",
      "This is the famous 'Keeling Curve' showing CO₂ rising from ~315 ppm",
      "in 1958 to over 420 ppm today—an increase unprecedented in human history."
    ),
    color = "#3b82f6"
  ),
  
  # -------------------------------------------------------------------------
  # INDUSTRIAL ERA - the CMIP7 historical period (1850-today)
  # -------------------------------------------------------------------------
  industrial = list(
    id = "industrial",
    name = "Industrial Era (1850–Present)",
    short_name = "Industrial Era",
    span_label = "1850 – today",
    years_span = 175,          # derived from the data at run time, like Modern
    years_per_minute = 2.5,
    data_source = DATA_SOURCE_CMIP7,
    filter_min_age = -Inf,
    filter_max_age = REFERENCE_YEAR - CMIP7_START_YEAR,   # years from 1850 on
    description = paste(
      "The CO₂ history the CMIP7 climate models are driven with: global-mean",
      "CO₂ from ~285 ppm in 1850 to over 420 ppm today, with Mauna Loa",
      "measurements for the latest years."
    ),
    color = "#f97316"
  ),

  # -------------------------------------------------------------------------
  # ROMAN ERA - Historical period from ice cores
  # -------------------------------------------------------------------------
  roman = list(
    id = "roman",
    name = "Roman Empire Era (~2,000 years)",
    short_name = "Roman Empire",
    span_label = "last 2,000 years",
    years_span = 2000,
    years_per_minute = 20,
    data_source = DATA_SOURCE_ICECORE,
    filter_min_age = 0,
    filter_max_age = 2000,
    description = paste(
      "Ice core records spanning the Roman Empire, Medieval Warm Period,",
      "Little Ice Age, and Industrial Revolution. CO₂ remained remarkably",
      "stable at ~280 ppm for nearly 2000 years until the 1800s."
    ),
    color = "#8b5cf6"
  ),
  
  # -------------------------------------------------------------------------
  # LAST GLACIAL MAXIMUM - End of the last ice age
  # -------------------------------------------------------------------------
  lgm = list(
    id = "lgm",
    name = "Last Glacial Maximum (~20,000 years)",
    short_name = "Last Glacial Maximum",
    span_label = "last 20,000 years",
    years_span = 20000,
    years_per_minute = 100,
    data_source = DATA_SOURCE_ICECORE,
    filter_min_age = 0,
    filter_max_age = 20000,
    description = paste(
      "The transition from the Last Ice Age (~20,000 years ago) to our",
      "current warm Holocene period. CO₂ rose from ~180 ppm during peak",
      "glaciation to ~280 ppm as massive ice sheets retreated."
    ),
    color = "#06b6d4"
  ),
  
  # -------------------------------------------------------------------------
  # EARLY HUMANS - Anatomically modern Homo sapiens
  # -------------------------------------------------------------------------
  humans = list(
    id = "humans",
    name = "Early Modern Humans (~250,000 years)",
    short_name = "Early Modern Humans",
    span_label = "last 250,000 years",
    years_span = 250000,
    years_per_minute = 1000,
    data_source = DATA_SOURCE_ICECORE,
    filter_min_age = 0,
    filter_max_age = 250000,
    description = paste(
      "The entire existence of anatomically modern Homo sapiens.",
      "Multiple glacial-interglacial cycles with CO₂ oscillating between",
      "~180 ppm (ice ages) and ~280 ppm (warm interglacials)."
    ),
    color = "#f59e0b"
  ),
  
  # -------------------------------------------------------------------------
  # FULL ICE CORE - Complete Antarctic record
  # -------------------------------------------------------------------------
  icecore = list(
    id = "icecore",
    name = "Full Ice Core Record (~800,000 years)",
    short_name = "Full Ice Core",
    span_label = "last 800,000 years",
    years_span = 800000,
    years_per_minute = 3000,
    data_source = DATA_SOURCE_ICECORE,
    filter_min_age = 0,
    filter_max_age = 800000,
    description = paste(
      "Eight complete glacial-interglacial cycles from Antarctic ice cores.",
      "Throughout 800,000 years, CO₂ NEVER exceeded 300 ppm—until now.",
      "Today's levels are truly unprecedented in this entire record."
    ),
    color = "#ef4444"
  ),
  
  # -------------------------------------------------------------------------
  # CENOZOIC - Age of mammals, from K-Pg extinction to present
  # -------------------------------------------------------------------------
  cenozoic = list(
    id = "cenozoic",
    name = "Cenozoic Era (~66 million years)",
    short_name = "Cenozoic",
    span_label = "last 66 million years",
    years_span = 66000000,
    years_per_minute = 250000,
    data_source = DATA_SOURCE_CENOZOIC,
    filter_min_age = 0,
    filter_max_age = 66000000,
    description = paste(
      "The entire Age of Mammals, from the asteroid impact that killed the",
      "dinosaurs to today. CO₂ ranged from ~180 ppm during ice ages to over",
      "1500 ppm in the warm early Eocene, when crocodiles lived in the Arctic."
    ),
    color = "#10b981"
  )
)

# -----------------------------------------------------------------------------
# HELPER: Get period by ID
# -----------------------------------------------------------------------------

get_period <- function(period_id) {
  if (!period_id %in% names(TIME_PERIODS)) {
    stop("Unknown period ID: ", period_id, 
         "\nValid IDs: ", paste(names(TIME_PERIODS), collapse = ", "))
  }
  return(TIME_PERIODS[[period_id]])
}

# -----------------------------------------------------------------------------
# HELPER: List all period IDs
# -----------------------------------------------------------------------------

list_period_ids <- function() {
  return(names(TIME_PERIODS))
}
