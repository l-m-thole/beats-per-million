# =============================================================================
# BEATS PER MILLION - SHINY APPLICATION
# =============================================================================
#
# Interactive web application for exploring paleoclimate playlists.
#
# To run:
#   1. Install required packages (see below)
#   2. Set working directory to this folder
#   3. Run: shiny::runApp()
#
# Required packages:
#   install.packages(c("shiny", "readxl", "dplyr", "readr", "plotly", "DT", "here"))
#
# Layout: header (title, one-line how-to, "How it works" / "About" buttons),
# a row of era buttons, then a two-column grid - CO2 plot and playlist on the
# left, the Listen panel on the right (it stays in view while you scroll).
# On phones everything stacks: plot, Listen, playlist.
#
# =============================================================================

# -----------------------------------------------------------------------------
# LOAD PACKAGES
# -----------------------------------------------------------------------------

library(shiny)
library(readxl)
library(dplyr)
library(readr)
library(plotly)
library(DT)
library(here)

# -----------------------------------------------------------------------------
# SOURCE SHARED MODULES
# -----------------------------------------------------------------------------

source(here::here("R", "config.R"))
source(here::here("R", "functions.R"))
source(here::here("R", "period_context.R"))
source(here::here("R", "load_data.R"))
source(here::here("R", "settings.R"))
source(here::here("R", "spotify.R"))
source(here::here("R", "about.R"))
source(here::here("R", "how_it_works.R"))
source(here::here("R", "share.R"))
source(here::here("R", "covers.R"))

# Local vs deployed, default player, who may log in to Spotify, contact.
# All from environment variables - see R/settings.R and .Renviron.example.
SETTINGS <- app_settings()

# -----------------------------------------------------------------------------
# CSS FUNCTION
# -----------------------------------------------------------------------------

app_css <- function() {
'
/* Bootstrap 3 sets the root font to 10px, which made every rem size below
   (titles, labels) tiny. 16px is the browser default the sizes assume;
   Bootstrap itself uses px, so it is unaffected. */
html { font-size: 16px; }

body {
  font-family: "DM Sans", -apple-system, BlinkMacSystemFont, sans-serif;
  background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
  color: #f5f5f7;
  min-height: 100vh;
}

/* ---- Header ------------------------------------------------------------ */
.main-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 1rem 2rem;
  background: rgba(10, 10, 15, 0.9);
  border-bottom: 1px solid rgba(255,255,255,0.1);
  padding: 1.75rem 2rem 1.5rem;
  margin: 0 -15px 1.25rem;
}

.main-title {
  font-family: "Playfair Display", serif;
  font-size: 3rem;            /* 1.5x the old 2rem */
  line-height: 1.1;
  font-weight: 600;
  margin: 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.main-subtitle {
  color: #a1a1aa;
  font-size: 1.35rem;         /* 1.5x the old 0.9rem */
  margin: 0.4rem 0 0;
}

.main-howto {
  margin: 0.9rem 0 0;
  font-size: 1.05rem;
  line-height: 1.6;
  color: #a1a1aa;
}
.howto-step {
  color: #f5f5f7;
  font-weight: 600;
  white-space: nowrap;
}
.howto-num {
  display: inline-block;
  width: 1.5em; height: 1.5em;
  line-height: 1.5em;
  margin-right: 0.35em;
  border-radius: 50%;
  text-align: center;
  font-size: 0.8em;
  background: rgba(102, 126, 234, 0.25);
  color: #c7d2fe;
}
.howto-arrow { color: #667eea; margin: 0 0.5rem; }

.header-actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
  padding-top: 0.5rem;
}

.btn-ghost {
  background: rgba(255,255,255,0.06) !important;
  border: 1px solid rgba(255,255,255,0.14) !important;
  color: #f5f5f7 !important;
  border-radius: 999px !important;
  padding: 0.45rem 1rem !important;
  font-size: 0.9rem !important;
}
.btn-ghost:hover, .btn-ghost:focus { background: rgba(255,255,255,0.12) !important; }
.btn-ghost.btn-accent {
  border-color: rgba(102, 126, 234, 0.7) !important;
  background: rgba(102, 126, 234, 0.18) !important;
}
.btn-ghost[disabled] { opacity: 0.35; }

/* ---- Era buttons ------------------------------------------------------- */
.era-picker { margin: 0 0 1.25rem; }
.era-picker .form-group { margin: 0; }
.era-picker .shiny-options-group {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
}
.era-picker .radio-inline {
  margin: 0 !important;
  padding: 0 !important;
}
.era-picker input[type=radio], .seg input[type=radio] {
  position: absolute;
  opacity: 0;
  width: 1px; height: 1px;
  margin: 0;
}
.era-picker input + span {
  display: flex;
  flex-direction: column;
  min-width: 10.5rem;
  padding: 0.6rem 1.1rem;
  border-radius: 14px;
  border: 1px solid rgba(255,255,255,0.1);
  background: rgba(26, 26, 37, 0.8);
  cursor: pointer;
  transition: all 0.15s ease;
}
.era-picker input + span:hover { background: rgba(255,255,255,0.08); }
.era-picker input:checked + span {
  background: linear-gradient(135deg, rgba(102,126,234,0.35) 0%, rgba(118,75,162,0.35) 100%);
  border-color: #667eea;
  box-shadow: 0 0 0 1px rgba(102,126,234,0.4);
}
.era-picker input:focus-visible + span, .seg input:focus-visible + span {
  outline: 2px solid #a5b4fc;
  outline-offset: 2px;
}
.era-name { color: #f5f5f7; font-weight: 600; font-size: 1rem; white-space: nowrap; }
.era-span { color: #a1a1aa; font-size: 0.8rem; margin-top: 0.1rem; white-space: nowrap; }
.era-picker input:checked + span .era-span { color: #c7d2fe; }

/* ---- Main grid: plot + playlist left, Listen right -------------------- */
.main-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(330px, 410px);
  grid-template-areas: "plot listen" "playlist listen";
  gap: 1.25rem 1.5rem;
  align-items: start;
}
.area-plot     { grid-area: plot;     min-width: 0; }
.area-playlist { grid-area: playlist; min-width: 0; }
.area-listen   { grid-area: listen;   min-width: 0; align-self: stretch; }
.main-grid .card { margin-bottom: 0; }

.listen-card {
  position: sticky;
  top: 1rem;
  max-height: calc(100vh - 2rem);
  overflow-y: auto;
  border-color: rgba(102, 126, 234, 0.3) !important;
  background: linear-gradient(160deg, rgba(26, 26, 37, 0.95) 0%, rgba(40, 44, 80, 0.6) 100%) !important;
}

@media (max-width: 991px) {
  .main-grid {
    grid-template-columns: minmax(0, 1fr);
    grid-template-areas: "plot" "listen" "playlist";
  }
  .listen-card { position: static; max-height: none; overflow: visible; }
}

/* ---- Cards ------------------------------------------------------------- */
.card {
  background: rgba(26, 26, 37, 0.8);
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 16px;
  padding: 1.25rem 1.5rem 1.5rem;
  margin-bottom: 1.5rem;
  backdrop-filter: blur(10px);
}

.card-title {
  font-family: "Playfair Display", serif;
  font-size: 1.35rem;
  margin: 0;
  color: #f5f5f7;
}

.card-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 0.5rem 1rem;
  margin-bottom: 0.75rem;
}
.card-head-actions { display: flex; gap: 0.4rem; flex-wrap: wrap; align-items: center; }
.card-head-actions .shiny-html-output { display: inline-block; }

/* Era facts under the plot title */
.era-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.25rem 1rem;
  margin-top: 0.3rem;
  font-size: 0.85rem;
  color: #a1a1aa;
}
.era-meta .era-current { color: #f5f5f7; font-weight: 600; }
.stat-chip b {
  font-family: "JetBrains Mono", monospace;
  font-weight: 500;
}
.gold { color: #f59e0b; }
.purple { color: #a78bfa; }
.cold { color: #60a5fa; }
.warm { color: #f87171; }

.description-text {
  color: #a1a1aa;
  font-size: 1.05rem;
  line-height: 1.7;
}

/* ---- Playlist ---------------------------------------------------------- */
.playlist-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0.75rem 1.5rem;
  padding: 0.75rem 1rem;
  margin-bottom: 0.6rem;
  border-radius: 12px;
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.06);
}
.playlist-filters .form-group { margin-bottom: 0; }
.playlist-filters .checkbox { margin: 0 0 0.3rem; }
.playlist-filters .checkbox label { font-size: 0.9rem; color: #d4d4d8; }
.filter-block { display: flex; flex-direction: column; gap: 0.3rem; }
.filter-label, .seg .control-label, .listen-options .control-label {
  color: #a1a1aa;
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.3rem;
}
.playlist-hint {
  color: #a1a1aa;
  font-size: 0.85rem;
  line-height: 1.5;
  margin: 0 0 0.6rem;
}

/* Segmented radio buttons (BPM scale, Play via, Song length) */
.seg .form-group { margin-bottom: 0; }
.seg .shiny-options-group { display: flex; flex-wrap: wrap; gap: 0.35rem; }
.seg .radio-inline { margin: 0 !important; padding: 0 !important; }
.seg input + span {
  display: inline-block;
  padding: 0.3rem 0.75rem;
  border-radius: 999px;
  border: 1px solid rgba(255,255,255,0.14);
  background: rgba(255,255,255,0.03);
  color: #d4d4d8;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.15s ease;
}
.seg input + span:hover { background: rgba(255,255,255,0.08); }
.seg input:checked + span {
  background: rgba(102, 126, 234, 0.3);
  border-color: #667eea;
  color: #fff;
}

/* Song cell in the table */
#playlist_table td.dt-nowrap { white-space: nowrap; }
#playlist_table td:nth-child(2) { min-width: 11rem; }
.song-title { display: block; color: #f5f5f7; font-weight: 600; }
.song-artist { display: block; color: #a1a1aa; font-size: 0.85em; }
.song-none { color: #71717a; font-style: italic; }

/* ---- Listen panel ------------------------------------------------------ */
.listen-title-row {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 0.75rem;
}
.np-kicker {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #a1a1aa;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.feel-tag {
  display: inline-block;
  padding: 0.1rem 0.55rem;
  border-radius: 999px;
  background: rgba(255,255,255,0.1);
  color: #d4d4d8;
  font-size: 0.75rem;
  letter-spacing: 0.02em;
  text-transform: none;
}
.np-title {
  font-family: "Playfair Display", serif;
  font-size: 1.5rem;
  line-height: 1.2;
  margin-top: 0.35rem;
}
.np-artist { color: #a1a1aa; font-size: 1rem; margin-top: 0.15rem; }
.np-facts {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
  margin: 0.9rem 0 0.6rem;
}
.np-facts .np-fact:first-child { grid-column: 1 / -1; }
.np-fact {
  background: rgba(255,255,255,0.04);
  border-radius: 10px;
  padding: 0.45rem 0.6rem;
  min-width: 0;
}
.np-label {
  display: block;
  color: #a1a1aa;
  font-size: 0.68rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.np-value {
  display: block;
  font-family: "JetBrains Mono", monospace;
  font-size: 0.9rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.np-bpm .np-value { font-size: 1.35rem; font-weight: 600; line-height: 1.2; }
.np-unit { font-size: 0.7rem; color: #a1a1aa; margin-left: 0.2rem; font-weight: 400; }
.np-match {
  font-size: 0.85rem;
  color: #a1a1aa;
  line-height: 1.5;
  margin: 0 0 0.5rem;
}
.np-match b { color: #f5f5f7; font-weight: 500; }
.song-events {
  margin: 0.25rem 0 0.75rem;
  padding: 0.5rem 0.75rem;
  border-radius: 10px;
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.25);
  font-size: 0.85rem;
  color: #f5f5f7;
}

.transport {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin: 0.75rem 0 0.5rem;
}
.np-details {
  margin-top: 0.75rem;
  padding-top: 0.5rem;
  border-top: 1px solid rgba(255,255,255,0.08);
}
.np-details .np-facts { margin-top: 0.4rem; }
#music_panel .button-row { margin-top: 0.5rem; }
.transport .btn { min-width: 6.5rem; }
.transport-pos {
  font-family: "JetBrains Mono", monospace;
  font-size: 0.85rem;
  color: #a1a1aa;
}

.listen-options {
  margin-top: 1rem;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(255,255,255,0.08);
}
.listen-options .seg { margin-bottom: 0.6rem; }
.listen-options .checkbox { margin: 0.3rem 0; font-size: 0.9rem; }
/* "Play" gate: nothing from Spotify / YouTube / SoundCloud loads before the
   visitor presses it (www/player.js then swaps it for the player) */
.player-gate {
  margin-top: 0.75rem;
  padding: 1rem;
  min-height: 152px;            /* the Spotify player\'s height: nothing jumps */
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 0.6rem;
  border-radius: 12px;
  background: rgba(255,255,255,0.04);
  border: 1px dashed rgba(255,255,255,0.15);
}
.player-gate .gate-play { align-self: flex-start; font-size: 1rem !important; }
.gate-note { color: #a1a1aa; font-size: 0.8rem; line-height: 1.45; margin: 0; }
.gate-note a { color: #3b82f6; }
.player-slot { display: none; }
.player-slot.is-on { display: block; }
.covers-credit {
  color: #a1a1aa;
  font-size: 0.75rem;
  margin: 0.25rem 0 0;
  text-align: right;
}
.covers-credit a { color: #3b82f6; }

/* Period context + key events (About this era window) */
.events-title {
  color: #f5f5f7;
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin: 1rem 0 0.5rem;
}
.event-list {
  list-style: none;
  padding-left: 0;
  margin: 0;
  border-left: 2px solid rgba(255,255,255,0.1);
}
.event-list li {
  position: relative;
  padding: 0 0 0.75rem 0.9rem;
  font-size: 0.9rem;
  line-height: 1.45;
  color: #a1a1aa;
}
.event-list li::before {
  content: "";
  position: absolute;
  left: -6px; top: 0.35rem;
  width: 10px; height: 10px;
  border-radius: 50%;
  background: #f59e0b;
}
.event-when {
  display: block;
  font-family: "JetBrains Mono", monospace;
  font-size: 0.75rem;
  color: #f59e0b;
}
.event-name { color: #f5f5f7; font-weight: 500; }

.button-row {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  margin-top: 0.75rem;
  flex-wrap: wrap;
}
.button-row .btn { padding: 0.3rem 0.75rem !important; font-size: 0.8rem !important; }
.open-label { color: #a1a1aa; font-size: 0.8rem; margin-right: 0.15rem; }

.play-status {
  font-family: "JetBrains Mono", monospace;
  font-size: 0.8rem;
  color: #a1a1aa;
  margin-top: 0.5rem;
}

.spotify-connect {
  margin-bottom: 0.75rem;
  font-size: 0.85rem;
}

.spotify-connect .btn { margin-right: 0.5rem; }

.card iframe {
  display: block;
  border: none;
}

.btn-spotify {
  background: #1DB954 !important;
  color: #000 !important;
  border: none !important;
  border-radius: 20px !important;
  padding: 0.6rem 1.2rem !important;
  font-weight: 500 !important;
  text-decoration: none !important;
}

.btn-soundcloud {
  background: #ff5500 !important;
  color: #fff !important;
  border: none !important;
  border-radius: 20px !important;
  padding: 0.6rem 1.2rem !important;
  font-weight: 500 !important;
  text-decoration: none !important;
}

.btn-youtube {
  background: #ff0033 !important;
  color: #fff !important;
  border: none !important;
  border-radius: 20px !important;
  padding: 0.6rem 1.2rem !important;
  font-weight: 500 !important;
  text-decoration: none !important;
}

.btn-download {
  background: rgba(255,255,255,0.1) !important;
  border: none !important;
  color: #f5f5f7 !important;
  border-radius: 8px !important;
  font-size: 0.85rem !important;
}

.footer {
  text-align: center;
  padding: 2rem;
  color: #a1a1aa;
  font-size: 0.8rem;
  border-top: 1px solid rgba(255,255,255,0.05);
  margin-top: 2rem;
}

.footer a {
  color: #3b82f6;
}

.muted {
  color: #a1a1aa;
}

.shiny-input-container {
  color: #f5f5f7;
}

/* DataTable styling */
.dataTables_wrapper {
  color: #a1a1aa;
}

table.dataTable {
  color: #f5f5f7 !important;
}

table.dataTable thead th {
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #a1a1aa;
}

table.dataTable tbody tr {
  background: rgba(255,255,255,0.02) !important;
  cursor: pointer;
}

table.dataTable tbody tr:hover {
  background: rgba(255,255,255,0.06) !important;
}

#playlist_table table.dataTable tbody tr.selected,
#playlist_table table.dataTable tbody tr.selected > td {
  background: #3b4380 !important;   /* beats the light-blue DT default */
  box-shadow: none !important;
  color: #fff !important;
}
#playlist_table table.dataTable tbody tr.selected .song-artist { color: #c7d2fe; }

.dataTables_info, .dataTables_length, .dataTables_filter {
  color: #a1a1aa !important;
}

.dataTables_filter { float: none !important; text-align: left !important; margin-bottom: 0.5rem; }
.dataTables_filter label { width: 100%; }
.dataTables_filter input {
  background: rgba(255,255,255,0.05) !important;
  border: 1px solid rgba(255,255,255,0.1) !important;
  color: #f5f5f7 !important;
  border-radius: 8px !important;
  padding: 0.35rem 0.7rem !important;
  margin-left: 0 !important;
  width: 100% !important;
  max-width: 22rem;
}

/* Dialogs (How it works, About this era, About & privacy, Spotify setup) */
.modal-content {
  background: #1a1a25;
  color: #f5f5f7;
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 16px;
}
.modal-header, .modal-footer { border-color: rgba(255,255,255,0.08); }
.modal-title, .modal-content h4 { font-family: "Playfair Display", serif; }
.modal-title { font-size: 1.6rem; }
.modal-content h4 { margin-top: 1.4rem; font-size: 1.25rem; }
.modal-content p, .modal-content li { color: #d4d4d8; line-height: 1.6; }
.modal-content a { color: #60a5fa; }
.modal-content .close { color: #f5f5f7; opacity: 0.7; text-shadow: none; }
.modal-content .btn-default {
  background: rgba(255,255,255,0.1); color: #f5f5f7; border: none;
}
.modal-content .steps li { margin-bottom: 0.5rem; }
.info-box {
  margin: 0.75rem 0 0.5rem;
  padding: 0.75rem 1rem;
  border-radius: 12px;
  background: rgba(102, 126, 234, 0.1);
  border: 1px solid rgba(102, 126, 234, 0.3);
  color: #d4d4d8;
  line-height: 1.6;
}
.era-lead { font-size: 1.1rem; }
.era-stats { display: flex; flex-wrap: wrap; gap: 0.5rem 1.25rem; margin: 0.25rem 0 0.5rem; color: #a1a1aa; }
.era-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
  gap: 0 2rem;
}
.era-events .event-list li { color: #a1a1aa; }
@media (max-width: 767px) { .era-grid { grid-template-columns: minmax(0, 1fr); } }
.measure-box {
  margin-top: 1.25rem;
  padding: 1rem 1.25rem;
  border-radius: 12px;
  background: rgba(16, 185, 129, 0.07);
  border: 1px solid rgba(16, 185, 129, 0.3);
}
.measure-kicker {
  color: #6ee7b7;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.measure-box h5 {
  font-family: "Playfair Display", serif;
  font-size: 1.2rem;
  margin: 0.25rem 0 0.6rem;
  color: #f5f5f7;
}
.measure-source { font-size: 0.85rem; color: #a1a1aa !important; margin-bottom: 0; }

/* ---- Phones ------------------------------------------------------------ */
@media (max-width: 767px) {
  .main-header { padding: 1.25rem 1rem 1rem; }
  .main-title { font-size: 2.4rem; }
  .main-subtitle { font-size: 1.15rem; }
  .main-howto { font-size: 0.95rem; }
  .era-picker .shiny-options-group {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 0.4rem;
    -webkit-overflow-scrolling: touch;
  }
  .era-picker input + span { min-width: 9.5rem; }
  .card { padding: 1rem; }
}
'
}

# -----------------------------------------------------------------------------
# LOAD DATA AT STARTUP
# -----------------------------------------------------------------------------

CO2_DATA <- load_co2_data(here::here("data"))
GLOBAL_RANGE <- global_co2_range(CO2_DATA)

# Pre-generate both scaling modes for instant switching
ALL_PLAYLISTS <- list(
  per_period = generate_all_playlists(CO2_DATA),
  global     = generate_all_playlists(CO2_DATA, co2_scale = GLOBAL_RANGE)
)

# Hand-curated song library (a flat list of songs tagged with their real BPM).
# Matched to playlist slots by tempo at run time. Empty tibble if
# data/song_library.csv hasn't been seeded yet.
SONG_LIBRARY <- load_song_library(here::here("data"))

# Only match against songs that have a BPM *and* a Spotify/SoundCloud link,
# otherwise slots get "matched" to rows the player can't play.
SONG_LIBRARY <- playable_songs(SONG_LIBRARY)

# "Play via" choices (SoundCloud only once the library has SoundCloud links)
# and the one visitors start with (BPM_DEFAULT_PLAYER, default Spotify).
# A playlist plays from ONE service only - no "best available" mix of
# services: Spotify's and SoundCloud's terms don't allow mixing their music
# with another service's (see service_songs() in R/functions.R).
SERVICE_LABELS   <- c(spotify = "Spotify", youtube = "YouTube", soundcloud = "SoundCloud")
PLAY_VIA_CHOICES <- stats::setNames(names(SERVICE_LABELS), SERVICE_LABELS)
if (!any(!is.na(SONG_LIBRARY$soundcloud_url) & nzchar(trimws(SONG_LIBRARY$soundcloud_url)))) {
  PLAY_VIA_CHOICES <- PLAY_VIA_CHOICES[PLAY_VIA_CHOICES != "soundcloud"]
}
DEFAULT_PLAYER <- if (SETTINGS$default_player %in% PLAY_VIA_CHOICES) {
  SETTINGS$default_player
} else {
  unname(PLAY_VIA_CHOICES[1])
}

# Tempos the library is short of, for "Suggest a song" in About & privacy.
# Worked out by the deploy script (data/wanted_bpm.csv); NULL until then.
WANTED_BPMS <- read_wanted_bpms(here::here("data", "wanted_bpm.csv"))

# Album covers for "Show covers on the plot": data/song_covers.csv (made by
# data-raw/fetch_covers.R and the deploy script); missing ones are looked up
# once per R session when someone switches covers on (see R/covers.R).
COVERS <- cover_store(here::here("data", COVERS_CSV))

# YouTube videos that refused to play in the app (owner blocks embedding,
# removed, ...). Remembered across sessions so they are skipped next time.
YT_BLOCKED_FILE <- here::here("data", "youtube_blocked.csv")
read_yt_blocked <- function() {
  if (!file.exists(YT_BLOCKED_FILE)) return(character(0))
  x <- tryCatch(utils::read.csv(YT_BLOCKED_FILE, colClasses = "character")$video_id,
                error = function(e) character(0))
  unique(x[!is.na(x) & nzchar(x)])
}
add_yt_blocked <- function(id, code) {
  new <- !file.exists(YT_BLOCKED_FILE)
  try(utils::write.table(
    data.frame(video_id = id, error_code = code, date = format(Sys.Date())),
    YT_BLOCKED_FILE, sep = ",", row.names = FALSE, col.names = new, append = !new
  ), silent = TRUE)
}

# player.js and the font CSS with their checksums in the address: after a
# deploy, browsers that still hold the old file in their cache load the new one.
.versioned <- function(file) {
  paste0(file, "?v=", substr(unname(tools::md5sum(here::here("www", file))), 1, 8))
}
PLAYER_JS <- .versioned("player.js")
FONTS_CSS <- .versioned("fonts/fonts.css")

# Trimmed text, or NULL when empty/NA
.txt <- function(x) {
  if (is.null(x) || !length(x) || is.na(x[1]) || !nzchar(trimws(x[1]))) NULL else trimws(x[1])
}

# -----------------------------------------------------------------------------
# USER INTERFACE
# -----------------------------------------------------------------------------

ui <- fluidPage(
  title = APP_TITLE_LONG,   # browser tab and bookmarks

  # Nothing in <head> comes from another site: the fonts are served by the
  # app (www/fonts/), and the players' code from Spotify, YouTube and
  # SoundCloud is loaded by www/player.js only after the visitor presses
  # ▶ Play (or connects Spotify) - so opening the page tells no one else.
  tags$head(
    # Link previews when someone shares the address (see R/share.R)
    social_meta_tags(SETTINGS$public_url),
    tags$link(rel = "stylesheet", href = FONTS_CSS),
    # App styles (defined inline in app_css())
    tags$style(HTML(app_css())),
    # Players: consent gate, progress events + auto-advance (see www/player.js)
    tags$script(src = PLAYER_JS)
  ),

  # ---- Header: title, what to do, info buttons ----
  div(class = "main-header",
      div(class = "header-text",
          h1(class = "main-title", "🌍 Beats per Million"),
          p(class = "main-subtitle", "Dance While You Can — translating Earth's climate history into music"),
          p(class = "main-howto",
            span(class = "howto-step", span(class = "howto-num", "1"), "Pick an era"),
            span(class = "howto-arrow", "→"),
            span(class = "howto-step", span(class = "howto-num", "2"), "press play"),
            span(class = "howto-arrow", "→"),
            span(class = "howto-step", span(class = "howto-num", "3"), "dance while you can"),
            tags$br(),
            "Every song is a slice of Earth's history: the more CO₂ in the air back then, the faster the beat.")
      ),
      div(class = "header-actions",
          actionButton("how_it_works", "💡 How it works", class = "btn-ghost btn-accent"),
          actionButton("about_top", "About & privacy", class = "btn-ghost"))
  ),

  # ---- Era buttons ----
  div(class = "era-picker",
      radioButtons(
        "selected_period", label = NULL, inline = TRUE,
        choiceNames = unname(lapply(TIME_PERIODS, function(p) {
          tagList(span(class = "era-name", p$short_name %||% p$name),
                  span(class = "era-span", p$span_label %||% ""))
        })),
        choiceValues = names(TIME_PERIODS),
        selected = "modern"
      )
  ),

  div(class = "main-grid",

      # ---- CO2 plot ----
      div(class = "area-plot",
          div(class = "card plot-card",
              div(class = "card-head",
                  div(h3(class = "card-title", "CO₂ through time"),
                      uiOutput("era_meta")),
                  div(class = "card-head-actions",
                      actionButton("era_info", "📖 About this era", class = "btn-ghost btn-accent"))
              ),
              plotlyOutput("timeline_plot", height = "300px"),
              uiOutput("covers_credit")
          )
      ),

      # ---- Listen (sticky on wide screens) ----
      div(class = "area-listen",
          div(class = "card listen-card",
              div(class = "listen-title-row",
                  h3(class = "card-title", "Listen")),
              uiOutput("now_playing"),
              uiOutput("spotify_connect"),
              uiOutput("music_panel"),
              div(class = "transport",
                  actionButton("prev_song", "⏮ Previous", class = "btn-ghost"),
                  span(class = "transport-pos", textOutput("song_position", inline = TRUE)),
                  actionButton("next_song", "Next ⏭", class = "btn-ghost")),
              uiOutput("play_status"),
              uiOutput("song_facts"),
              div(class = "listen-options",
                  div(class = "seg",
                      radioButtons("play_source", "Play via",
                                   choices = PLAY_VIA_CHOICES,
                                   selected = DEFAULT_PLAYER, inline = TRUE)),
                  # Whole songs, or short snippets for a faster feel of the CO2
                  # rise. Works with every full player (Spotify connected,
                  # YouTube, SoundCloud) and auto-advances.
                  div(class = "seg",
                      radioButtons("play_length", "Song length",
                                   choices = c("Whole song" = "full",
                                               "30-s snippets" = "snippet"),
                                   selected = "full", inline = TRUE)),
                  conditionalPanel(
                    "input.play_length == 'snippet'",
                    div(class = "seg",
                        radioButtons("snippet_start", "Snippets start at",
                                     choices = c("Beginning" = "0",
                                                 "0:30 (skip intro)" = "30",
                                                 "Middle of the song" = "-1"),
                                     selected = "30", inline = TRUE))
                  ),
                  checkboxInput("auto_advance",
                                "Auto-play the next song when one ends",
                                value = TRUE)
              )
          )
      ),

      # ---- Playlist ----
      div(class = "area-playlist",
          div(class = "card playlist-card",
              div(class = "card-head",
                  h3(class = "card-title", "Playlist"),
                  div(class = "card-head-actions",
                      # Save to Spotify: only shown to visitors who can log in
                      uiOutput("export_ui", inline = TRUE),
                      downloadButton("download_csv", "📥 CSV", class = "btn-download"))
              ),
              div(class = "playlist-filters",
                  div(class = "seg",
                      radioButtons("scaling_mode", "BPM scale",
                                   choices = c("Per era (max. contrast)" = "per_period",
                                               "Global (compare eras)"   = "global"),
                                   selected = "per_period", inline = TRUE)),
                  div(class = "filter-block",
                      span(class = "filter-label", "Songs"),
                      actionButton("shuffle", "🔀 Shuffle songs", class = "btn-ghost",
                                   title = "Swap in other songs with the same tempos. The order (oldest → youngest) stays the same.")),
                  # Covers come from Spotify, so only next to Spotify's player
                  # (Spotify's terms; see R/covers.R)
                  conditionalPanel(
                    "input.play_source == 'spotify'",
                    div(class = "filter-block",
                        title = "Loads the album covers from Spotify",
                        span(class = "filter-label", "On the CO₂ plot"),
                        checkboxInput("show_covers", "🖼 Show album covers", value = FALSE)))
              ),
              p(class = "playlist-hint",
                "Each row is a song and a slice of time, oldest first: the slice's CO₂ sets",
                "the tempo (", tags$b("BPM", .noWS = "outside"), "), the song has about that tempo (",
                tags$b("Song BPM", .noWS = "outside"), "). Shuffle picks other songs with the",
                "same tempos; the order stays. Click a row to select it."),
              DTOutput("playlist_table")
          )
      )
  ),

  # Footer
  div(class = "footer",
      p("Data sources: ",
        tags$a(href = "https://gml.noaa.gov/ccgg/trends/", target = "_blank", "NOAA Mauna Loa"),
        " • ",
        tags$a(href = "https://www.ncei.noaa.gov/access/paleo-search/", target = "_blank", "Bereiter et al. 2015"),
        " • ",
        tags$a(href = "https://www.annualreviews.org/doi/10.1146/annurev-earth-082420-063026", target = "_blank", "Rae et al. 2021")
      ),
      # Keep this backlink in the static UI (not renderUI): GetSongBPM's terms
      # require a public link to getsongbpm.com that a crawler can see.
      p("Song tempos (BPM) partly from ",
        tags$a(href = "https://getsongbpm.com", target = "_blank", "GetSongBPM")),
      p("A collaboration between Martin Wegmann and Lena Thöle",
        " • ", actionLink("how_it_works_footer", "How it works"),
        " • ", actionLink("about", "About & privacy"),
        if (!is.null(suggest_song_link(SETTINGS))) {
          tagList(" • ", suggest_song_tag(SETTINGS, "Suggest a song"))
        })
  )
)

# -----------------------------------------------------------------------------
# SERVER LOGIC
# -----------------------------------------------------------------------------

server <- function(input, output, session) {

  # Get current playlist (pre-computed)
  current_playlist <- reactive({
    ALL_PLAYLISTS[[input$scaling_mode]][[input$selected_period]]
  })

  # Get current period config
  current_period <- reactive({
    TIME_PERIODS[[input$selected_period]]
  })

  # The one service this playlist plays from ("Play via")
  play_service <- reactive({
    s <- input$play_source %||% DEFAULT_PLAYER
    if (s %in% PLAY_VIA_CHOICES) s else DEFAULT_PLAYER
  })

  # Selected song index
  selected_idx <- reactiveVal(1L)   # integer: DT sends integers, and 1 vs 1L would re-render everything

  # Shuffle counter — bumped by the Shuffle button. Feeds the RNG seed so each
  # bump re-rolls which library songs land in this period's slots (see
  # assign_songs_to_playlist), while staying reproducible between bumps.
  shuffle_counter <- reactiveVal(0)

  # Playback progress of the current song (0 = start, 1 = end / 3-min cap),
  # reported by www/player.js. Drives the ball on the CO2 curve.
  play_frac <- reactiveVal(0)
  play_pos  <- reactiveVal(NULL)   # list(pos, dur) in ms, for the status line

  # TRUE while music is playing (reported by www/player.js: play / pause).
  # A newly selected song - a click in the playlist or on the plot, Previous /
  # Next, another era - starts by itself only while music is playing; after a
  # pause nothing starts on its own. At the end of a song, "Auto-play the next
  # song" decides whether the playlist keeps going.
  listening <- reactiveVal(FALSE)

  # Back to the first song when the era changes. High priority, so this runs
  # before the playlist table re-renders with the new era (the table reads the
  # selection when it is drawn).
  observeEvent(input$selected_period, {
    selected_idx(1L)
  }, priority = 100)

  # Re-roll the BPM-matched song picks
  observeEvent(input$shuffle, {
    shuffle_counter(shuffle_counter() + 1)
  })

  # Get selected song
  selected_song <- reactive({
    pl <- current_playlist()
    idx <- selected_idx()
    if (nrow(pl$songs) >= idx) {
      pl$songs[idx, ]
    } else if (nrow(pl$songs) > 0) {
      pl$songs[1, ]
    } else {
      NULL
    }
  })

  # BPM-matched song picks for the WHOLE current playlist, recomputed when the
  # period, scaling mode, or shuffle counter changes. Doing it playlist-wide (not
  # per-slot) lets us pass each slot the titles already used as `exclude` so a
  # song never repeats within a period, and the seeded draw stays consistent
  # across slots. Returns one row per MATCHED slot (song_number + library cols
  # + how the song was found: match_tol, n_candidates).
  curated_picks <- reactive({
    pl <- current_playlist()
    if (is.null(pl) || nrow(pl$songs) == 0) return(NULL)
    # Only songs the chosen service can play: a playlist never mixes services
    # (Play via Spotify -> Spotify links only, via YouTube -> YouTube only).
    # isolate: a video failing mid-session must not reshuffle the whole list
    lib <- service_songs(SONG_LIBRARY, play_service(),
                         bad_youtube = isolate(bad_yt()))
    assign_songs_to_playlist(
      pl$songs, lib,
      period          = input$selected_period,
      shuffle_counter = shuffle_counter()
    )
  })

  # The pick for the currently selected slot, or NULL (-> search fallback).
  # Because matching is by tempo, this naturally reflects each scaling mode's BPM.
  selected_curated <- reactive({
    song  <- selected_song()
    picks <- curated_picks()
    if (is.null(song) || is.null(picks) || nrow(picks) == 0) return(NULL)
    match <- picks %>% dplyr::filter(song_number == song$song_number)
    if (nrow(match) == 0) return(NULL)
    match[1, ]
  })

  # ----- INFO WINDOWS -----

  open_how_it_works <- function() {
    show_how_it_works(period_id = input$selected_period,
                      stats = current_playlist()$stats,
                      scaling = input$scaling_mode,
                      global_range = GLOBAL_RANGE,
                      n_library = nrow(SONG_LIBRARY))
  }
  observeEvent(input$how_it_works, open_how_it_works())
  observeEvent(input$how_it_works_footer, open_how_it_works())

  observeEvent(input$era_info, {
    show_era_info(input$selected_period, ALL_PLAYLISTS$per_period[[input$selected_period]]$stats)
  })

  # ----- SPOTIFY LOGIN / FULL PLAYER / EXPORT -----

  sp_connected <- reactiveVal(FALSE)

  # Where this visitor's Spotify token lives: on your laptop one shared,
  # disk-cached login; on a server one in-memory login per browser session
  # (see R/spotify.R), so visitors never share an account.
  sp_store <- spotify_session_store(session, deployed = SETTINGS$deployed)

  # Opened with ?testers (or came back from a login started there): may see
  # "Connect Spotify" when BPM_SPOTIFY_LOGIN = testers (default on a server).
  tester <- reactiveVal(FALSE)

  # May this visitor log in to Spotify? (keys set + login mode allows it)
  login_ok <- reactive({
    spotify_configured() &&
      spotify_login_visible(SETTINGS$spotify_login, tester(), sp_connected())
  })

  # Hand the browser a fresh access token for the Web Playback SDK
  send_sp_token <- function() {
    tok <- spotify_access_token(sp_store)
    if (is.null(tok)) { sp_connected(FALSE); return(invisible(FALSE)) }
    sp_connected(TRUE)
    session$sendCustomMessage("sp_token", list(
      token = tok,
      expires_in = spotify_token_expires_in(sp_store)
    ))
    invisible(TRUE)
  }

  # On page load: read the URL flags (?testers, ?player=, ?about), finish a
  # login if Spotify just redirected back (?code=...), otherwise reuse a
  # cached login (local only).
  observeEvent(session$clientData$url_search, {
    q  <- parseQueryString(session$clientData$url_search %||% "")
    fl <- url_flags(q)
    tester(fl$tester)
    if (!is.null(fl$player) && fl$player %in% PLAY_VIA_CHOICES) {
      updateRadioButtons(session, "play_source", selected = fl$player)
    }
    if (fl$about) show_about(SETTINGS, CO2_DATA, WANTED_BPMS)

    if (!is.null(q$error)) {
      showNotification(paste("Spotify login cancelled:", q$error), type = "warning")
    } else if (!is.null(q$code)) {
      # remember ?testers first, so Connect stays visible even if the login fails
      if (spotify_login_tester(q$state)) tester(TRUE)
      tryCatch({
        spotify_complete_login(q$code, q$state, store = sp_store)
        showNotification("Connected to Spotify.", type = "message")
      }, error = function(e) showNotification(conditionMessage(e), type = "warning", duration = 15))
    }
    if (!is.null(q$code) || !is.null(q$error)) {
      # tidy the address bar; keep ?testers so a reload still shows Connect
      session$sendCustomMessage("sp_clean_url",
                                list(keep = if (isTRUE(tester())) "testers" else ""))
    }
    send_sp_token()
  }, once = TRUE, ignoreNULL = FALSE)

  observeEvent(input$about, show_about(SETTINGS, CO2_DATA, WANTED_BPMS))
  observeEvent(input$about_top, show_about(SETTINGS, CO2_DATA, WANTED_BPMS))
  observeEvent(input$about_gate, show_about(SETTINGS, CO2_DATA, WANTED_BPMS))   # link at ▶ Play

  observeEvent(input$sp_token_request, send_sp_token())

  spotify_setup_modal <- function() {
    showModal(modalDialog(
      title = "Connect Spotify",
      tags$ol(
        tags$li("Create an app at ", tags$a(href = "https://developer.spotify.com/dashboard",
                                            target = "_blank", "developer.spotify.com/dashboard"),
                " (needs Spotify Premium) and tick ", tags$b("Web API"), " and ",
                tags$b("Web Playback SDK"), "."),
        tags$li("Add this Redirect URI: ", tags$code(SPOTIFY_REDIRECT_URI)),
        tags$li("Put ", tags$code("SPOTIFY_CLIENT_ID"), " and ", tags$code("SPOTIFY_CLIENT_SECRET"),
                " in ", tags$code(".Renviron"), " (", tags$code('usethis::edit_r_environ("project")'),
                "), restart R and run the app again.")
      ),
      easyClose = TRUE, footer = modalButton("OK")
    ))
  }

  start_spotify_login <- function() {
    if (!spotify_configured()) {
      if (SETTINGS$deployed) {
        return(showNotification("Spotify login isn't available on this site.",
                                type = "warning"))
      }
      return(spotify_setup_modal())
    }
    if (!isTRUE(login_ok())) return()
    session$sendCustomMessage("sp_goto", list(url = spotify_begin_login(tester = tester())))
  }
  observeEvent(input$sp_connect, start_spotify_login())
  observeEvent(input$sp_connect_inline, start_spotify_login())

  observeEvent(input$sp_disconnect, {
    spotify_forget_login(sp_store)
    sp_connected(FALSE)
    session$reload()
  })

  # YouTube refused to play this video (removed, or embedding disabled by the
  # uploader). The video is remembered as broken (for good if the problem is
  # permanent) and left out of playlists from now on. The song is NOT handed
  # to another service - a playlist never mixes services - so while music is
  # meant to play, the playlist simply moves on to the next song.
  bad_yt <- reactiveVal(read_yt_blocked())
  observeEvent(input$yt_error, {
    ev <- input$yt_error
    if (!identical(ev$token, player_token())) return()
    why <- switch(as.character(ev$code),
      "2"   = "the youtube_url is not a valid video link",
      "5"   = "the browser can't play this video",
      "100" = "the video was removed or is private",
      "101" = , "150" = "the owner doesn't allow playing it on other websites",
      "153" = "YouTube rejected the embed (player configuration / referrer)",
      paste("YouTube error", ev$code))
    if (!is.null(ev$id) && nzchar(ev$id) && !(ev$id %in% bad_yt())) {
      bad_yt(union(bad_yt(), ev$id))
      # permanent problems -> skip this video in future sessions too
      if (as.character(ev$code) %in% c("2", "100", "101", "150")) add_yt_blocked(ev$id, ev$code)
    }
    idx <- selected_idx()
    skip <- (isTRUE(ev$autoplay) || isTRUE(listening())) && isTRUE(input$auto_advance) &&
      idx < nrow(current_playlist()$songs)
    showNotification(
      paste0("YouTube can't play this song here: ", why, ". ",
             if (skip) "Skipping to the next song. " else "Press Next ⏭ for the next song. ",
             "This video is left out from now on (data/youtube_blocked.csv)."),
      type = "warning", duration = 10)
    if (skip) {
      listening(TRUE)
      selected_idx(idx + 1L)
    }
  })

  observeEvent(input$sp_error, {
    msg <- input$sp_error
    if (grepl("^account_error", msg)) {
      msg <- "The in-app Spotify player needs a Spotify Premium account."
    }
    showNotification(paste("Spotify:", msg), type = "warning", duration = 12)
  })

  # TRUE once this browser tab is a ready Spotify device (full tracks)
  sdk_ready <- reactive({
    isTRUE(sp_connected()) && !is.null(input$sp_device) && nzchar(input$sp_device)
  })

  output$spotify_connect <- renderUI({
    if (!spotify_configured()) {
      if (SETTINGS$deployed) return(NULL)        # nothing visitors can set up
      return(div(class = "spotify-connect muted",
                 "Previews only. ",
                 actionLink("sp_connect", "Set up Spotify for full songs")))
    }
    if (!login_ok()) return(NULL)                # public visitor, login is invite-only
    if (!sp_connected()) {
      return(div(class = "spotify-connect",
                 actionButton("sp_connect", "Connect Spotify (full songs)",
                              class = "btn btn-spotify")))
    }
    if (!sdk_ready()) {
      return(div(class = "spotify-connect muted", "Starting Spotify player…"))
    }
    div(class = "spotify-connect muted",
        "✓ Spotify connected — full songs in-app · ",
        actionLink("sp_disconnect", "disconnect"))
  })

  # The button only appears for visitors who can log in to Spotify (locally:
  # always, so the setup instructions stay one click away).
  output$export_ui <- renderUI({
    if (SETTINGS$deployed && !isTRUE(login_ok())) return(NULL)
    actionButton("export_spotify", "➕ Save to Spotify", class = "btn-download")
  })

  # Save the current period's matched songs as a private Spotify playlist.
  # Nothing opens by itself: you get a notification with a link.
  observeEvent(input$export_spotify, {
    if (!spotify_configured()) return(spotify_setup_modal())
    if (is.null(spotify_access_token(sp_store))) {
      showNotification("Connect Spotify first (button in the Listen panel).",
                       type = "warning", duration = 8)
      return()
    }
    uris <- picks_to_spotify_uris(curated_picks())
    per  <- current_period()
    name <- paste0("Beats per Million — ", per$name,
                   if (input$scaling_mode == "global") " (global scale)" else "")
    desc <- paste0("CO2 through time as tempo, oldest to youngest. ",
                   length(uris), " songs matched by BPM. Made with Beats per Million.")
    res <- tryCatch(spotify_export_playlist(name, desc, uris, store = sp_store),
                    error = function(e) { showNotification(conditionMessage(e), type = "error",
                                                           duration = 15); NULL })
    if (!is.null(res)) {
      showNotification(
        tagList("Saved ", res$n, " songs to your Spotify as “", name, "”. ",
                tags$a(href = res$url, target = "_blank", "Open playlist")),
        type = "message", duration = 20
      )
    }
  })

  # ----- PLAYER <-> SHINY -----

  # Identifies the slot the embedded player was built for; progress events
  # carrying another token (a player that's being torn down) are ignored.
  player_token <- reactive({
    paste(input$selected_period, input$scaling_mode, selected_idx(),
          shuffle_counter(), sep = "|")
  })

  # New song -> ball back to the start of its window
  observeEvent(player_token(), {
    play_frac(0)
    play_pos(NULL)
  })

  observeEvent(input$player_progress, {
    ev <- input$player_progress
    if (!identical(ev$token, player_token())) return()
    play_frac(as.numeric(ev$frac %||% 0))
    play_pos(list(pos = as.numeric(ev$pos %||% 0), dur = as.numeric(ev$dur %||% 0)))
  })

  # Play / pause in any player (www/player.js sends a change only after the
  # song really started, so a player that is still loading never counts as
  # "paused").
  observeEvent(input$player_state, {
    ev <- input$player_state
    if (!identical(ev$token, player_token())) return()
    listening(isTRUE(ev$playing))
  })

  # Song length for www/player.js (whole song or 30-s snippets); sent on
  # start-up and whenever the setting changes - applies to the playing song too.
  observe({
    session$sendCustomMessage("play_cfg", list(
      snippet = identical(input$play_length, "snippet"),
      len     = 30,
      start   = as.numeric(input$snippet_start %||% "30")
    ))
  })

  # Spotify clip that never started (e.g. no preview for this track): skip it
  observeEvent(input$sp_nostart, {
    if (!identical(input$sp_nostart$token, player_token())) return()
    showNotification("Spotify has no playable clip for this song - skipping to the next one.",
                     type = "message", duration = 5)
  })

  # Song finished (or its snippet did): next slot, which plays by itself -
  # if "Auto-play the next song" is ticked. Otherwise the music stops here.
  observeEvent(input$player_ended, {
    if (!identical(input$player_ended$token, player_token())) return()
    idx <- selected_idx()
    if (isTRUE(input$auto_advance) && idx < nrow(current_playlist()$songs)) {
      listening(TRUE)
      selected_idx(idx + 1L)
    } else {
      listening(FALSE)
    }
  })

  # Previous / Next. The new song plays by itself if music was playing.
  # A button's value counts its clicks; quick clicks can arrive together
  # (3 -> 6), so move by the difference.
  clicks_seen <- c(next_song = 0L, prev_song = 0L)
  nav_steps <- function(id) {
    now <- as.integer(input[[id]])
    step <- max(1L, now - clicks_seen[[id]])
    clicks_seen[[id]] <<- now
    step
  }
  observeEvent(input$next_song, {
    n <- nrow(current_playlist()$songs)
    selected_idx(min(n, selected_idx() + nav_steps("next_song")))
  })
  observeEvent(input$prev_song, {
    selected_idx(max(1L, selected_idx() - nav_steps("prev_song")))
  })

  output$song_position <- renderText({
    paste(selected_idx(), "/", nrow(current_playlist()$songs))
  })

  # Grey out Previous / Next at the ends of the playlist
  observe({
    n <- nrow(current_playlist()$songs)
    idx <- selected_idx()
    session$sendCustomMessage("bpm_nav", list(prev = idx > 1L, `next` = idx < n))
  })

  # Move the ball along the curve without re-drawing the plot
  observeEvent(play_frac(), {
    song <- isolate(selected_song())
    pl   <- isolate(current_playlist())
    if (is.null(song) || nrow(pl$raw_data) == 0) return()
    ax  <- axis_for_period(isolate(current_period()))
    pos <- ball_position(song, pl$raw_data, play_frac())
    plotlyProxy("timeline_plot", session) %>%
      plotlyProxyInvoke(
        "restyle",
        list(x = list(list(ax$scale(pos$age))), y = list(list(pos$co2))),
        list(1L)   # trace 1 = the ball (trace 0 = the CO2 curve)
      )
  }, ignoreInit = TRUE)

  # ----- PLAYLIST TABLE <-> SELECTED SONG -----
  # The table has no DT selection of its own: www/player.js reports row clicks
  # (input$playlist_row_click = song number) and highlights the selected song.
  # A DT selection echoed back to the server could undo quick Next clicks.

  observeEvent(input$playlist_row_click, {
    num <- suppressWarnings(as.integer(input$playlist_row_click$row))
    if (length(num) == 1 && !is.na(num) && num >= 1L &&
        num <= nrow(current_playlist()$songs)) {
      selected_idx(num)
    }
  })

  # Highlight the selected song in the table and scroll it into view (also
  # re-applied by player.js whenever the table is redrawn)
  observe({
    session$sendCustomMessage("bpm_select_row",
                              list(id = "playlist_table", row = selected_idx()))
  })

  # Click on the CO2 curve or on a cover -> select that song
  # (suppressWarnings: plotly warns until the plot has been drawn once)
  plot_click <- reactive(suppressWarnings(event_data("plotly_click", source = "timeline")))
  observeEvent(plot_click(), {
    ev <- plot_click()
    num <- suppressWarnings(as.integer(ev$customdata[[1]]))
    if (length(num) && !is.na(num) && num >= 1L &&
        num <= nrow(current_playlist()$songs)) {
      selected_idx(num)
    }
  })

  # ----- ALBUM COVERS ON THE PLOT -----

  # Only while playing via Spotify, and only Spotify's covers (credited under
  # the plot; each song links back to Spotify in the Listen panel)
  covers <- reactive({
    if (!isTRUE(input$show_covers) || !identical(play_service(), "spotify")) return(NULL)
    picks <- curated_picks()
    if (is.null(picks) || !nrow(picks)) return(NULL)
    sp <- vapply(picks$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
    todo <- setdiff(unique(sp[!is.na(sp)]), c(names(COVERS$cache), COVERS$tried))
    if (length(todo)) {
      showNotification("Looking up album covers…", id = "covers_note", duration = NULL,
                       type = "message")
      on.exit(removeNotification("covers_note"), add = TRUE)
    }
    data.frame(song_number = picks$song_number,
               url = store_cover_urls(COVERS, picks),
               title = picks$song_title, artist = picks$artist,
               song_bpm = picks$bpm, stringsAsFactors = FALSE)
  })

  # ----- OUTPUTS -----

  # Era name + key numbers under the plot title
  output$era_meta <- renderUI({
    s <- current_playlist()$stats
    per <- current_period()
    div(class = "era-meta",
        span(class = "era-current", per$name),
        span(class = "stat-chip", tags$b(class = "gold",
             format(s$years_span, big.mark = ",", scientific = FALSE)), " years"),
        span(class = "stat-chip", tags$b(class = "purple", s$num_songs), " songs"),
        span(class = "stat-chip", "CO₂ ", tags$b(class = "cold", s$co2_min), "–",
             tags$b(class = "warm", s$co2_max), " ppm"))
  })

  # Timeline plot: static (no zoom/pan/toolbar), the selected song's slice
  # highlighted, key events marked, optional album covers along the top.
  # Click the curve (or a cover) to select the song for that time.
  output$timeline_plot <- renderPlotly({
    pl <- current_playlist()
    period <- current_period()
    data <- pl$raw_data
    songs <- pl$songs

    if (nrow(data) == 0) return(NULL)

    # Determine x-axis based on timescale
    ax <- axis_for_period(period)

    data <- data %>% mutate(x_val = ax$scale(age),
                            song = song_at_age(age, songs))
    x_reversed <- ax$reversed
    cov <- covers()
    show_cov <- !is.null(cov) && any(!is.na(cov$url))
    y_max <- max(data$co2, na.rm = TRUE)
    # Fixed x range (1.5 % padding), so toggling covers or markers never shifts it
    x_rng <- range(data$x_val, na.rm = TRUE) + c(-1, 1) * diff(range(data$x_val, na.rm = TRUE)) * 0.015

    # Covers get their own strip at the top (a second, hidden y-axis); the
    # CO2 axis then uses the lower 78 % of the plot.
    y_dom <- if (show_cov) c(0, 0.78) else c(0, 1)

    p <- plot_ly(source = "timeline") %>%
      add_trace(
        data = data,
        x = ~x_val,
        y = ~co2,
        customdata = ~song,
        type = "scatter",
        mode = "lines",
        fill = "tozeroy",
        fillcolor = "rgba(102, 126, 234, 0.2)",
        line = list(color = "#667eea", width = 2),
        hovertemplate = paste0("<b>%{y:.0f} ppm</b> · ", ax$hover,
                               "<br>Song %{customdata} (click to select)<extra></extra>")
      ) %>%
      layout(
        xaxis = list(
          title = ax$title,
          color = "#a1a1aa",
          gridcolor = "rgba(255,255,255,0.05)",
          range = if (x_reversed) rev(x_rng) else x_rng,
          autorange = FALSE,
          fixedrange = TRUE
        ),
        yaxis = list(
          title = "CO₂ (ppm)",
          color = "#a1a1aa",
          gridcolor = "rgba(255,255,255,0.05)",
          range = c(0, y_max * 1.08),
          domain = y_dom,
          fixedrange = TRUE
        ),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        font = list(family = "DM Sans, sans-serif", size = 13, color = "#a1a1aa"),
        margin = list(l = 60, r = 20, t = 24, b = 50),
        showlegend = FALSE,
        dragmode = FALSE,
        hoverlabel = list(bgcolor = "#1a1a25", bordercolor = "#667eea",
                          font = list(color = "#f5f5f7"))
      )

    # Key events: dotted vertical lines (shapes) + hoverable markers on top.
    ev <- period_key_events(input$selected_period)
    ev <- ev[ev$age >= min(data$age) & ev$age <= max(data$age), , drop = FALSE]
    shapes <- lapply(seq_len(nrow(ev)), function(i) list(
      type = "line", xref = "x", yref = "y domain",
      x0 = ax$scale(ev$age[i]), x1 = ax$scale(ev$age[i]), y0 = 0, y1 = 1,
      line = list(color = "rgba(245,158,11,0.35)", width = 1, dash = "dot"),
      layer = "below"
    ))
    annotations <- list()

    # Ball for the selected song: sits on the curve at the current playback
    # position and is moved by the play_frac() observer while the song plays.
    # The song's time slice is highlighted in the song's tempo colour.
    song <- selected_song()
    if (!is.null(song)) {
      pos <- ball_position(song, data, isolate(play_frac()))
      x0 <- ax$scale(song$start_age); x1 <- ax$scale(song$end_age)
      shapes <- c(shapes, list(list(
        type = "rect", xref = "x", yref = "y domain",
        x0 = x0, x1 = x1, y0 = 0, y1 = 1,
        fillcolor = hex_to_rgba(song$bpm_color, 0.28),
        line = list(color = hex_to_rgba(song$bpm_color, 0.9), width = 1),
        layer = "below"
      )))
      if (!show_cov) {
        annotations <- c(annotations, list(list(
          x = (x0 + x1) / 2, y = 1, xref = "x", yref = "y domain",
          text = paste0("<b>", song$song_number, "</b>"), showarrow = FALSE,
          yanchor = "bottom", font = list(color = "#f5f5f7", size = 11),
          bgcolor = song$bpm_color, borderpad = 2
        )))
      }

      cur <- selected_curated()
      p <- p %>%
        add_trace(
          x = ax$scale(pos$age),
          y = pos$co2,
          type = "scatter",
          mode = "markers",
          marker = list(
            size = 14,
            color = song$bpm_color,
            line = list(color = "white", width = 2)
          ),
          cliponaxis = FALSE,
          hovertemplate = paste0(
            "<b>Song ", song$song_number, "</b>",
            if (!is.null(cur)) paste0(": ", htmltools::htmlEscape(cur$song_title)) else "",
            "<br>", song$avg_co2, " ppm → ", song$bpm, " BPM<extra></extra>"
          )
        )
    }

    # Added after the ball on purpose: the play-progress observer restyles trace 1 (ball).
    if (nrow(ev)) {
      p <- p %>%
        add_trace(
          x = ax$scale(ev$age),
          y = rep(y_max, nrow(ev)),
          type = "scatter", mode = "markers",
          marker = list(symbol = "triangle-down", size = 9, color = "#f59e0b"),
          text = paste0("<b>", ev$when, " – ", ev$title, "</b><br>",
                        vapply(strwrap(ev$detail, 50, simplify = FALSE),
                               paste, character(1), collapse = "<br>")),
          hovertemplate = "%{text}<extra></extra>"
        )
    }

    # Album covers above each song's slice (hover: the song; click: select it)
    if (show_cov) {
      cs <- dplyr::inner_join(songs[, c("song_number", "start_age", "end_age", "bpm")],
                              cov[!is.na(cov$url), , drop = FALSE], by = "song_number")
      cs$x  <- ax$scale((cs$start_age + cs$end_age) / 2)
      cs$w  <- abs(ax$scale(cs$end_age) - ax$scale(cs$start_age))
      sel <- if (!is.null(song)) song$song_number else NA
      images <- lapply(seq_len(nrow(cs)), function(i) list(
        source = cs$url[i], xref = "x", yref = "y2",
        x = cs$x[i], y = 0.5, sizex = cs$w[i] * 0.92, sizey = 0.92,
        xanchor = "center", yanchor = "middle", sizing = "contain",
        opacity = if (identical(cs$song_number[i], sel)) 1 else 0.8,
        layer = "above"
      ))
      if (!is.na(sel) && sel %in% cs$song_number) {
        j <- which(cs$song_number == sel)
        shapes <- c(shapes, list(list(
          type = "rect", xref = "x", yref = "y2",
          x0 = cs$x[j] - cs$w[j] / 2, x1 = cs$x[j] + cs$w[j] / 2, y0 = 0, y1 = 1,
          line = list(color = song$bpm_color, width = 2), fillcolor = "rgba(0,0,0,0)",
          layer = "above"
        )))
      }
      p <- p %>%
        add_trace(
          x = cs$x, y = rep(0.5, nrow(cs)), yaxis = "y2",
          customdata = cs$song_number,
          type = "scatter", mode = "markers",
          marker = list(size = 22, color = "rgba(0,0,0,0)", symbol = "square"),
          text = paste0("<b>", cs$song_number, ". ", htmltools::htmlEscape(cs$title), "</b><br>",
                        htmltools::htmlEscape(cs$artist), "<br>",
                        cs$bpm, " BPM slot · song ", cs$song_bpm, " BPM",
                        "<br><i>Cover: Spotify · click to select</i>"),
          hovertemplate = "%{text}<extra></extra>"
        ) %>%
        layout(images = images,
               yaxis2 = list(domain = c(0.8, 1), range = c(0, 1), visible = FALSE,
                             fixedrange = TRUE, anchor = "x"))
    }

    p %>%
      layout(shapes = shapes, annotations = annotations) %>%
      config(displayModeBar = FALSE, scrollZoom = FALSE, doubleClick = FALSE,
             showTips = FALSE, responsive = TRUE) %>%
      event_register("plotly_click")
  })

  # Under the plot while covers are shown: where they come from (Spotify's
  # terms: credit Spotify, link back - the Listen panel's Spotify player and
  # "Open in Spotify" link to the song)
  output$covers_credit <- renderUI({
    cov <- covers()
    if (is.null(cov) || !any(!is.na(cov$url))) return(NULL)
    p(class = "covers-credit",
      "Album covers from ",
      tags$a(href = "https://open.spotify.com", target = "_blank", rel = "noopener", "Spotify"),
      " · click a cover to select its song; the player links to it on Spotify.")
  })

  # Listen panel, top: the selected song
  output$now_playing <- renderUI({
    song <- selected_song()
    if (is.null(song)) {
      return(p("Pick a song in the playlist.", class = "muted"))
    }
    cur <- selected_curated()
    n <- nrow(current_playlist()$songs)
    title  <- if (!is.null(cur)) .txt(cur$song_title) else NULL
    artist <- if (!is.null(cur)) .txt(cur$artist) else NULL

    div(class = "np",
        div(class = "np-kicker",
            span(paste("Song", song$song_number, "of", n)),
            span(class = "feel-tag", song$feel)),
        if (!is.null(cur)) {
          tagList(div(class = "np-title", title %||% "Untitled"),
                  if (!is.null(artist)) div(class = "np-artist", artist))
        } else {
          div(class = "np-title muted", "No song for this tempo yet")
        })
  })

  # Listen panel, below the player: the song's slice of time, its CO2 and
  # tempo, how the song was picked, and events during the song
  output$song_facts <- renderUI({
    song <- selected_song()
    if (is.null(song)) return(NULL)
    cur <- selected_curated()
    ev <- events_in_window(input$selected_period, song$start_age, song$end_age)

    div(class = "np np-details",
        div(class = "np-facts",
            div(class = "np-fact",
                span(class = "np-label", "Years"),
                span(class = "np-value", title = song$age_range, song$age_range)),
            div(class = "np-fact",
                span(class = "np-label", "CO₂"),
                span(class = "np-value", paste(song$avg_co2, "ppm"))),
            div(class = "np-fact np-bpm",
                span(class = "np-label", "Tempo"),
                span(class = "np-value", style = paste0("color:", song$bpm_color),
                     song$bpm, span(class = "np-unit", "BPM")))),
        if (!is.null(cur)) {
          p(class = "np-match",
            tags$b(paste0("This song: ", cur$bpm, " BPM")), " – ",
            paste0(match_explanation(cur$bpm, song$bpm, cur$match_tol, cur$n_candidates), "."))
        },
        if (nrow(ev)) {
          div(class = "song-events",
              span(class = "np-label", "During this song"),
              lapply(seq_len(nrow(ev)), function(i)
                div("📍 ", tags$b(ev$when[i]), " – ", ev$title[i])))
        }
    )
  })

  # Listen panel: embedded player + direct links for a matched slot,
  # or search buttons for a slot no library song fits yet.
  output$music_panel <- renderUI({
    song <- selected_song()
    if (is.null(song)) {
      return(p("Select a song from the playlist to listen.", class = "muted"))
    }

    cur <- selected_curated()

    # Build embed URLs (NA if the relevant field is blank/unparseable).
    sp_embed <- if (!is.null(cur)) spotify_embed_url(cur$spotify_uri) else NA_character_
    sp_open  <- if (!is.null(cur)) spotify_open_url(cur$spotify_uri)  else NA_character_
    sc_embed <- if (!is.null(cur)) soundcloud_embed_url(cur$soundcloud_url) else NA_character_
    sc_open  <- if (!is.null(cur) && !is.na(cur$soundcloud_url) &&
                    nzchar(trimws(cur$soundcloud_url %||% ""))) {
      trimws(cur$soundcloud_url)
    } else {
      NA_character_
    }

    yt_id   <- if (!is.null(cur)) parse_youtube_id(cur$youtube_url) else NA_character_
    yt_open <- if (!is.na(yt_id)) paste0("https://www.youtube.com/watch?v=", yt_id) else NA_character_

    has_track <- (!is.na(sp_embed)) || (!is.na(sc_embed)) || (!is.na(yt_id))

    if (has_track) {
      title_txt  <- .txt(cur$song_title)
      artist_txt <- .txt(cur$artist)

      # ONE player per song, always from the service picked in "Play via" -
      # never another service's player (Spotify's and SoundCloud's terms don't
      # allow mixing). The playlist only holds songs that service can play;
      # the one exception is a YouTube video that failed mid-session, which
      # gets a short note instead of a player (the playlist moves on).
      # www/player.js wires each player up for progress / end-of-song events.
      sp_uri <- if (!is.na(sp_embed)) paste0("spotify:track:", parse_spotify_id(cur$spotify_uri))

      want <- play_service()
      use <- switch(want,
        # Spotify: the full player once connected, otherwise Spotify's 30-s
        # clip (auto-plays + auto-advances)
        spotify    = if (is.na(sp_embed)) NA_character_ else if (sdk_ready()) "spotify_full" else "spotify",
        youtube    = if (!is.na(yt_id) && !(yt_id %in% bad_yt())) "youtube" else NA_character_,
        soundcloud = if (!is.na(sc_embed)) "soundcloud" else NA_character_,
        NA_character_
      )
      label <- c(spotify_full = "Spotify", spotify = "Spotify",
                 youtube = "YouTube", soundcloud = "SoundCloud")
      want_label <- SERVICE_LABELS

      # Embedded players stay empty placeholders until the visitor presses
      # the ▶ Play gate (player_gate(), R/about.R): only then does
      # www/player.js load anything from Spotify / YouTube / SoundCloud.
      player <- if (is.na(use)) NULL else switch(use,
        spotify_full = div(id = "bpm-sdk", `data-uri` = sp_uri, style = "margin-top:0.75rem;",
                           tags$button(id = "bpm-sdk-toggle", type = "button",
                                       class = "btn btn-spotify", "▶ Play")),
        youtube = div(style = "border-radius:12px; overflow:hidden; margin-top:0.75rem;",
                      div(id = "bpm-youtube", `data-id` = yt_id)),
        soundcloud = div(style = "margin-top:0.75rem;",
                         div(id = "bpm-soundcloud", `data-src` = sc_embed)),
        spotify = div(style = "border-radius:12px; overflow:hidden; margin-top:0.75rem;",
                      div(id = "bpm-spotify", `data-uri` = sp_uri))
      )
      gated <- !is.na(use) && use != "spotify_full"     # the SDK needs a login first anyway
      service <- if (is.na(use)) want else sub("_full$", "", use)

      source_note <- p(class = "muted", style = "font-size:0.8rem; margin:0.4rem 0 0;",
        if (is.na(use)) {
          paste0("This song can't be played via ", want_label[[want]], " here",
                 if (want == "youtube" && !is.na(yt_id)) " (YouTube won't play this video on other websites)" else "",
                 ". Press Next ⏭ for the next song.")
        } else {
          paste0("Playing via ", label[[use]],
                 if (use == "spotify") {
                   if (isTRUE(login_ok())) " — 30-s clips; click Connect Spotify for whole songs."
                   else if (!is.na(yt_id) && !(yt_id %in% bad_yt())) " — 30-s clips; Play via YouTube for whole songs."
                   else " — 30-s clips."
                 } else "")
        })

      # Always one button per service: open the song if we have a link,
      # otherwise search that service for it.
      q_song <- utils::URLencode(paste(artist_txt %||% "", title_txt %||% ""), reserved = TRUE)
      links <- div(class = "button-row",
        span(class = "open-label", "Open in"),
        tags$a(href = if (!is.na(sp_open)) sp_open else paste0("https://open.spotify.com/search/", q_song),
               target = "_blank", class = "btn btn-spotify",
               title = if (!is.na(sp_open)) "Open this song in Spotify" else "Search Spotify for this song",
               if (!is.na(sp_open)) "Spotify" else "🔎 Spotify"),
        tags$a(href = if (!is.na(yt_open)) yt_open else paste0("https://www.youtube.com/results?search_query=", q_song),
               target = "_blank", class = "btn btn-youtube",
               title = if (!is.na(yt_open)) "Open this song on YouTube" else "Search YouTube for this song",
               if (!is.na(yt_open)) "YouTube" else "🔎 YouTube"),
        tags$a(href = if (!is.na(sc_open)) sc_open else paste0("https://soundcloud.com/search?q=", q_song),
               target = "_blank", class = "btn btn-soundcloud",
               title = if (!is.na(sc_open)) "Open this song in SoundCloud" else "Search SoundCloud for this song",
               if (!is.na(sc_open)) "SoundCloud" else "🔎 SoundCloud")
      )

      # Spotify preferred but not connected: say so right at the player,
      # with the one click that unlocks full songs.
      connect_hint <- if (want == "spotify" && !sdk_ready() &&
                          !is.na(sp_embed) && isTRUE(login_ok())) {
        div(class = "spotify-connect", style = "margin-top:0.75rem;",
            if (isTRUE(sp_connected())) {
              span(class = "muted", "Starting the Spotify player… (needs Spotify Premium)")
            } else {
              tagList(
                actionButton("sp_connect_inline", "▶ Connect Spotify to play the full song",
                             class = "btn btn-spotify"),
                div(class = "muted", style = "font-size:0.8rem; margin-top:0.3rem;",
                    "One-time login. Without it Spotify only allows 30-s previews.")
              )
            })
      }

      div(id = "bpm-player",
          `data-token`    = player_token(),
          `data-autoplay` = tolower(isolate(listening())),
          `data-service`  = service,
          connect_hint,
          if (gated) player_gate(service),
          if (gated) div(class = "player-slot", player) else player,
          source_note, links)

    } else {
      # ----- Blank slot: search buttons for this tempo -----
      query <- paste(song$bpm, "bpm", song$feel)
      spotify_search    <- paste0("https://open.spotify.com/search/",
                                  utils::URLencode(query, reserved = TRUE))
      youtube_search    <- paste0("https://www.youtube.com/results?search_query=",
                                  utils::URLencode(query, reserved = TRUE))
      soundcloud_search <- paste0("https://soundcloud.com/search?q=",
                                  utils::URLencode(query, reserved = TRUE))

      tagList(
        p(class = "description-text",
          "No", SERVICE_LABELS[[play_service()]],
          "song in the library fits this slot yet. Search for a song near",
          paste0(song$bpm, " BPM:")),
        div(class = "button-row",
            tags$a(href = spotify_search, target = "_blank",
                   class = "btn btn-spotify", "🎵 Spotify"),
            tags$a(href = youtube_search, target = "_blank",
                   class = "btn btn-youtube", "▶ YouTube"),
            tags$a(href = soundcloud_search, target = "_blank",
                   class = "btn btn-soundcloud", "☁️ SoundCloud")
        )
      )
    }
  })

  # Playback status under the player
  output$play_status <- renderUI({
    pp <- play_pos()
    if (is.null(pp) || is.null(selected_curated())) return(NULL)
    fmt <- function(ms) sprintf("%d:%02d", floor(ms / 60000), floor(ms / 1000) %% 60)
    div(class = "play-status",
        paste0("▶ ", fmt(pp$pos), " / ", fmt(pp$dur)))
  })

  # Playlist table: Song first, then the time slice, its CO2 and tempo, the
  # song's own tempo and the tempo's feel.
  playlist_display <- reactive({
    pl <- current_playlist()
    picks <- curated_picks()
    songs <- pl$songs
    m <- if (!is.null(picks) && nrow(picks)) match(songs$song_number, picks$song_number)
         else rep(NA_integer_, nrow(songs))
    title  <- if (!is.null(picks)) picks$song_title[m] else rep(NA_character_, nrow(songs))
    artist <- if (!is.null(picks)) picks$artist[m] else rep(NA_character_, nrow(songs))
    esc <- function(x) htmltools::htmlEscape(ifelse(is.na(x), "", x))
    song_html <- ifelse(
      is.na(m),
      '<span class="song-none">no song for this tempo yet</span>',
      paste0('<span class="song-title">', esc(title), '</span>',
             '<span class="song-artist">', esc(artist), '</span>')
    )
    data.frame(
      `#`        = songs$song_number,
      Song       = song_html,
      Years      = songs$age_range,
      `CO₂ ppm`  = songs$avg_co2,
      BPM        = songs$bpm,
      `Song BPM` = if (!is.null(picks)) picks$bpm[m] else NA_real_,
      Feel       = songs$feel,
      check.names = FALSE, stringsAsFactors = FALSE
    )
  })

  output$playlist_table <- renderDT({
    df <- playlist_display()
    datatable(
      df,
      escape = setdiff(names(df), "Song"),
      selection = "none",          # highlight + clicks: see bpm_select_row
      options = list(
        paging = FALSE,
        dom = "ft",
        scrollY = "380px",
        scrollX = TRUE,        # phones: swipe the table sideways
        scrollCollapse = TRUE,
        autoWidth = FALSE,
        order = list(),
        language = list(search = "", searchPlaceholder = "Filter songs, artists, years…",
                        zeroRecords = "No matching songs"),
        columnDefs = list(
          list(className = "dt-right", targets = c(0, 3, 4, 5)),
          list(className = "dt-nowrap", targets = c(2, 6)),
          list(width = "2.5em", targets = 0)
        )
      ),
      rownames = FALSE,
      class = "stripe"
    ) %>%
      formatStyle(
        "BPM",
        backgroundColor = styleInterval(
          c(75, 95, 115, 135),
          c("#1e3a5f", "#2d4a6f", "#3d5a7f", "#6d3a5f", "#8d2a4f")
        ),
        color = "white",
        fontWeight = "600"
      )
  }, server = FALSE)   # all rows in the browser (at most ~90): instant sort/filter

  # Download: the playlist as shown, with the matched songs and their links
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("playlist_", input$selected_period, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write_csv(playlist_export(current_playlist(), curated_picks()), file, na = "")
    }
  )
}

# -----------------------------------------------------------------------------
# RUN THE APP
# -----------------------------------------------------------------------------

# Locally: fixed port (the Spotify Redirect URI points here) and the system
# browser - the Spotify player can't run inside the RStudio Viewer.
# On a server the host chooses the port, so no options there.
if (SETTINGS$deployed) {
  shinyApp(ui = ui, server = server)
} else {
  shinyApp(ui = ui, server = server,
           options = list(port = SPOTIFY_PORT, launch.browser = TRUE))
}
