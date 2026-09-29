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
source(here::here("R", "spotify.R"))

# -----------------------------------------------------------------------------
# CSS FUNCTION
# -----------------------------------------------------------------------------

app_css <- function() {
'
body {
  font-family: "DM Sans", -apple-system, BlinkMacSystemFont, sans-serif;
  background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
  color: #f5f5f7;
  min-height: 100vh;
}

.main-header {
  background: rgba(10, 10, 15, 0.9);
  border-bottom: 1px solid rgba(255,255,255,0.1);
  padding: 1.5rem 2rem;
  margin-bottom: 2rem;
}

.main-title {
  font-family: "Playfair Display", serif;
  font-size: 2rem;
  font-weight: 600;
  margin: 0;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.main-subtitle {
  color: #a1a1aa;
  font-size: 0.9rem;
  margin-top: 0.25rem;
}

.card {
  background: rgba(26, 26, 37, 0.8);
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 16px;
  padding: 1.5rem;
  margin-bottom: 1.5rem;
  backdrop-filter: blur(10px);
}

.card-title {
  font-family: "Playfair Display", serif;
  font-size: 1.25rem;
  margin-bottom: 1rem;
  margin-top: 0;
  color: #f5f5f7;
}

.stat-box {
  background: rgba(26, 26, 37, 0.8);
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 12px;
  padding: 1rem;
  text-align: center;
  margin-bottom: 1rem;
}

.stat-value {
  font-family: "JetBrains Mono", monospace;
  font-size: 1.5rem;
  font-weight: 500;
}

.stat-value.cold { color: #3b82f6; }
.stat-value.warm { color: #ef4444; }
.stat-value.gold { color: #f59e0b; }
.stat-value.purple { color: #8b5cf6; }

.stat-label {
  font-size: 0.7rem;
  color: #a1a1aa;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-top: 0.25rem;
}

.description-text {
  color: #a1a1aa;
  font-size: 1.05rem;
  line-height: 1.7;
}

.now-playing {
  background: linear-gradient(135deg, rgba(26, 26, 37, 0.9) 0%, rgba(102, 126, 234, 0.1) 100%);
  border: 1px solid rgba(102, 126, 234, 0.3);
  border-radius: 16px;
  padding: 1.5rem;
  margin-bottom: 1rem;
}

.now-playing-label {
  color: #a1a1aa;
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  margin-bottom: 1rem;
}

.now-playing-row {
  margin-bottom: 1rem;
}

/* Period context + key events */
.context-more summary {
  cursor: pointer;
  color: #3b82f6;
  font-size: 0.9rem;
  margin: 0.25rem 0 0.75rem;
}
.context-more p {
  color: #a1a1aa;
  font-size: 0.95rem;
  line-height: 1.6;
}
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
.song-events {
  margin: 0.5rem 0 1rem;
  padding: 0.6rem 0.8rem;
  border-radius: 10px;
  background: rgba(245, 158, 11, 0.08);
  border: 1px solid rgba(245, 158, 11, 0.25);
  font-size: 0.9rem;
  color: #f5f5f7;
}

.now-playing-label-small {
  display: block;
  color: #a1a1aa;
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.2rem;
}

.now-playing-value {
  font-family: "JetBrains Mono", monospace;
  font-size: 1.2rem;
}

.now-playing-bpm {
  margin: 1rem 0;
}

.bpm-large {
  font-family: "Playfair Display", serif;
  font-size: 3.5rem;
  font-weight: 600;
}

.bpm-label {
  color: #a1a1aa;
  font-size: 1.1rem;
  margin-left: 0.5rem;
}

.mood-tag {
  display: inline-block;
  padding: 0.5rem 1rem;
  background: rgba(255,255,255,0.1);
  border-radius: 20px;
  font-size: 1rem;
  color: #a1a1aa;
}

.button-row {
  display: flex;
  gap: 0.5rem;
  margin-top: 1rem;
  flex-wrap: wrap;
}

.curated-track {
  margin-bottom: 0.25rem;
}

.curated-badge {
  display: inline-block;
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #1DB954;
  background: rgba(29, 185, 84, 0.12);
  border: 1px solid rgba(29, 185, 84, 0.3);
  border-radius: 12px;
  padding: 0.2rem 0.6rem;
}

.curated-title {
  font-family: "JetBrains Mono", monospace;
  font-size: 1.05rem;
  margin-top: 0.5rem;
}

.play-status {
  font-family: "JetBrains Mono", monospace;
  font-size: 0.8rem;
  color: #a1a1aa;
  margin-top: 0.75rem;
}

#play_source .control-label, #play_length .control-label,
#snippet_start .control-label {
  color: #a1a1aa;
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

#play_source .radio-inline, #play_length .radio-inline,
#snippet_start .radio-inline {
  margin-right: 0.75rem;
  font-size: 0.9rem;
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
  font-size: 0.8rem !important;
}

.playlist-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.playlist-header .card-title {
  margin: 0;
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

/* Radio buttons styling */
.shiny-input-container {
  color: #f5f5f7;
}

.radio label {
  display: block;
  padding: 0.75rem 1rem;
  margin-bottom: 0.5rem;
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.05);
  border-radius: 10px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.radio label:hover {
  background: rgba(255,255,255,0.08);
}

.radio input:checked + span {
  color: #fff;
}

.radio input:checked ~ span {
  font-weight: 500;
}

/* DataTable styling */
.dataTables_wrapper {
  color: #a1a1aa;
}

table.dataTable {
  color: #f5f5f7 !important;
}

table.dataTable tbody tr {
  background: rgba(255,255,255,0.02) !important;
}

table.dataTable tbody tr:hover {
  background: rgba(255,255,255,0.06) !important;
}

table.dataTable tbody tr.selected {
  background: rgba(102, 126, 234, 0.2) !important;
}

.dataTables_info, .dataTables_length, .dataTables_filter {
  color: #a1a1aa !important;
}

.dataTables_filter input {
  background: rgba(255,255,255,0.05) !important;
  border: 1px solid rgba(255,255,255,0.1) !important;
  color: #f5f5f7 !important;
  border-radius: 6px !important;
  padding: 0.3rem 0.6rem !important;
}

/* Plotly modebar */
.plotly .modebar {
  background: transparent !important;
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

# -----------------------------------------------------------------------------
# USER INTERFACE
# -----------------------------------------------------------------------------

ui <- fluidPage(
  
  # Custom CSS
  tags$head(
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=JetBrains+Mono:wght@300;400;500&family=DM+Sans:wght@400;500;600&display=swap"),
    # App styles (defined inline in app_css())
    tags$style(HTML(app_css())),
    # Player APIs: progress events + auto-advance (see www/player.js)
    # player.js must load BEFORE the Spotify API: the API calls
    # window.onSpotifyIframeApiReady once, as soon as it has loaded.
    tags$script(src = "player.js"),
    tags$script(src = "https://sdk.scdn.co/spotify-player.js"),
    tags$script(src = "https://open.spotify.com/embed/iframe-api/v1"),
    tags$script(src = "https://w.soundcloud.com/player/api.js"),
    tags$script(src = "https://www.youtube.com/iframe_api")
  ),
  
  # Header
  div(class = "main-header",
      h1(class = "main-title", "🌍 Beats per Million"),
      p(class = "main-subtitle", "Dance While You Can — translating Earth's climate history into music")
  ),
  
  # Main content
  fluidRow(
    
    # Sidebar
    column(3,
           div(class = "card",
               h3(class = "card-title", "Select Time Period"),
               radioButtons(
                 "selected_period",
                 label = NULL,
                 choices = setNames(
                   names(TIME_PERIODS),
                   sapply(TIME_PERIODS, function(x) x$name)
                 ),
                 selected = "modern"
               )
           ),

           div(class = "card",
               h3(class = "card-title", "BPM Scaling"),
               radioButtons(
                 "scaling_mode",
                 label = NULL,
                 choices = c(
                   "Per period (max. contrast)" = "per_period",
                   "Global (comparable eras)"   = "global"
                 ),
                 selected = "per_period"
               )
           ),

           div(class = "card",
               h3(class = "card-title", "About This Period"),
               uiOutput("period_description")
           ),
           
           div(class = "card",
               h3(class = "card-title", "How It Works"),
               uiOutput("how_it_works")
           )
    ),
    
    # Main panel
    column(9,
           
           # Stats row
           fluidRow(
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value gold", textOutput("stat_years", inline = TRUE)),
                        div(class = "stat-label", "Years Covered")
                    )
             ),
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value purple", textOutput("stat_songs", inline = TRUE)),
                        div(class = "stat-label", "Songs")
                    )
             ),
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value cold", textOutput("stat_co2_min", inline = TRUE)),
                        div(class = "stat-label", "Min CO₂")
                    )
             ),
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value warm", textOutput("stat_co2_max", inline = TRUE)),
                        div(class = "stat-label", "Max CO₂")
                    )
             )
           ),
           
           # Timeline plot
           div(class = "card",
               h3(class = "card-title", "CO₂ Through Time"),
               plotlyOutput("timeline_plot", height = "280px")
           ),
           
           # Now playing and playlist
           fluidRow(
             column(5,
                    div(class = "now-playing",
                        div(class = "now-playing-label", "🎵 SELECTED SONG"),
                        uiOutput("now_playing")
                    ),
                    
                    div(class = "card",
                        div(class = "playlist-header",
                            h3(class = "card-title", "Listen"),
                            actionButton("shuffle", "🔀 Shuffle",
                                         class = "btn-download")
                        ),
                        uiOutput("spotify_connect"),
                        radioButtons("play_source", "Play via",
                                     choices = c("Best available" = "auto",
                                                 "Spotify" = "spotify",
                                                 "YouTube" = "youtube",
                                                 "SoundCloud" = "soundcloud"),
                                     selected = "spotify", inline = TRUE),
                        # Whole songs, or short snippets for a faster feel of
                        # the CO2 rise. Works with every full player (Spotify
                        # connected, YouTube, SoundCloud) and auto-advances.
                        radioButtons("play_length", "Song length",
                                     choices = c("Whole song" = "full",
                                                 "30-s snippets" = "snippet"),
                                     selected = "full", inline = TRUE),
                        conditionalPanel(
                          "input.play_length == 'snippet'",
                          radioButtons("snippet_start", "Snippets start at",
                                       choices = c("Beginning" = "0",
                                                   "0:30 (skip intro)" = "30",
                                                   "Middle of the song" = "-1"),
                                       selected = "30", inline = TRUE)
                        ),
                        uiOutput("music_panel"),
                        uiOutput("play_status"),
                        checkboxInput("auto_advance",
                                      "Auto-play next song",
                                      value = TRUE),
                        checkboxInput("full_only",
                                      "Skip songs that can only play the Spotify preview widget (it can't auto-play)",
                                      value = TRUE)
                    )
             ),
             
             column(7,
                    div(class = "card",
                        div(class = "playlist-header",
                            h3(class = "card-title", "Playlist"),
                            div(
                              actionButton("export_spotify", "➕ Save to Spotify",
                                           class = "btn-download"),
                              downloadButton("download_csv", "📥 CSV",
                                             class = "btn-download")
                            )
                        ),
                        DTOutput("playlist_table")
                    )
             )
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
      p("Song tempos (BPM) partly from ",
        tags$a(href = "https://getsongbpm.com", target = "_blank", "GetSongBPM")),
      p("A collaboration between Martin Wegmann and Lena Thöle")
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

  # Becomes TRUE once anything has played; from then on a newly selected song
  # (click or auto-advance) starts playing by itself.
  listening <- reactiveVal(FALSE)

  # Reset selection when period changes
  observeEvent(input$selected_period, {
    selected_idx(1L)
  })

  # Re-roll the BPM-matched song picks
  observeEvent(input$shuffle, {
    shuffle_counter(shuffle_counter() + 1)
  })

  # Update selection from table click
  observeEvent(input$playlist_table_rows_selected, {
    if (length(input$playlist_table_rows_selected) > 0) {
      selected_idx(as.integer(input$playlist_table_rows_selected[1]))
    }
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
  # across slots. Returns one row per MATCHED slot (song_number + library cols).
  curated_picks <- reactive({
    pl <- current_playlist()
    if (is.null(pl) || nrow(pl$songs) == 0) return(NULL)
    # Default: only songs that play in full (YouTube / SoundCloud, or Spotify
    # once the full player is connected), so every song plays to the end and
    # auto-advances. Untick "Full songs only" to also use Spotify-only songs
    # (30-s preview when Spotify isn't connected).
    # Play via Spotify: only songs with a Spotify link, so YouTube is never
    # needed (full songs once connected, otherwise Spotify's 30-s clips).
    lib <- if (identical(input$play_source %||% "spotify", "spotify")) {
      sp <- spotify_songs(SONG_LIBRARY)
      if (nrow(sp)) sp else SONG_LIBRARY
    } else if (isTRUE(input$full_only %||% TRUE)) {
      # isolate: a video failing mid-session must not reshuffle the whole list
      full_song_songs(SONG_LIBRARY, spotify_full = sdk_ready(),
                      bad_youtube = isolate(bad_yt()))
    } else {
      SONG_LIBRARY
    }
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

  # ----- SPOTIFY LOGIN / FULL PLAYER / EXPORT -----

  sp_connected <- reactiveVal(FALSE)

  # Hand the browser a fresh access token for the Web Playback SDK
  send_sp_token <- function() {
    tok <- spotify_access_token()
    if (is.null(tok)) { sp_connected(FALSE); return(invisible(FALSE)) }
    sp_connected(TRUE)
    session$sendCustomMessage("sp_token", list(
      token = tok,
      expires_in = .spotify$token$expires_at - as.numeric(Sys.time())
    ))
    invisible(TRUE)
  }

  # On page load: finish a login if Spotify just redirected back (?code=...),
  # otherwise reuse a cached login.
  observeEvent(session$clientData$url_search, {
    q <- parseQueryString(session$clientData$url_search %||% "")
    if (!is.null(q$error)) {
      showNotification(paste("Spotify login cancelled:", q$error), type = "warning")
    } else if (!is.null(q$code)) {
      tryCatch({
        spotify_complete_login(q$code, q$state)
        showNotification("Connected to Spotify.", type = "message")
      }, error = function(e) showNotification(conditionMessage(e), type = "error", duration = 15))
    }
    if (!is.null(q$code) || !is.null(q$error)) session$sendCustomMessage("sp_clean_url", list())
    send_sp_token()
  }, once = TRUE, ignoreNULL = FALSE)

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
    if (!spotify_configured()) return(spotify_setup_modal())
    session$sendCustomMessage("sp_goto", list(url = spotify_begin_login()))
  }
  observeEvent(input$sp_connect, start_spotify_login())
  observeEvent(input$sp_connect_inline, start_spotify_login())

  observeEvent(input$sp_disconnect, {
    spotify_forget_login()
    sp_connected(FALSE)
    session$reload()
  })

  # YouTube refused to play this video (removed, or embedding disabled by the
  # uploader). player.js then ends the song, so auto-play moves on.
  # The video is remembered as broken for this session and the Listen panel
  # re-renders with the next player for the same song (Spotify first), which
  # starts playing right away.
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
    listening(TRUE)
    showNotification(
      paste0("YouTube can't play this song here: ", why,
             ". Switching to another player; this video is skipped from now on ",
             "(listed in data/youtube_blocked.csv)."),
      type = "warning", duration = 10)
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
      return(div(class = "spotify-connect muted",
                 "Previews only. ",
                 actionLink("sp_connect", "Set up Spotify for full songs")))
    }
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

  # Save the current period's matched songs as a private Spotify playlist.
  # Nothing opens by itself: you get a notification with a link.
  observeEvent(input$export_spotify, {
    if (!spotify_configured()) return(spotify_setup_modal())
    if (is.null(spotify_access_token())) {
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
    res <- tryCatch(spotify_export_playlist(name, desc, uris),
                    error = function(e) { showNotification(conditionMessage(e), type = "error",
                                                           duration = 15); NULL })
    if (!is.null(res)) {
      showNotification(
        tagList("Saved ", res$n, " songs to your Spotify as \u201c", name, "\u201d. ",
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
    listening(TRUE)
    play_frac(as.numeric(ev$frac %||% 0))
    play_pos(list(pos = as.numeric(ev$pos %||% 0), dur = as.numeric(ev$dur %||% 0)))
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

  # Song finished (or its snippet did) -> next slot, which autoplays
  observeEvent(input$player_ended, {
    if (!identical(input$player_ended$token, player_token())) return()
    if (!isTRUE(input$auto_advance)) return()
    idx <- selected_idx()
    if (idx < nrow(current_playlist()$songs)) selected_idx(idx + 1L)
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

  # ----- OUTPUTS -----
  
  # Period description
  output$period_description <- renderUI({
    pid <- input$selected_period
    ctx <- period_context_text(pid)
    ev  <- period_key_events(pid)

    tagList(
      p(class = "description-text", current_period()$description),
      if (length(ctx)) {
        tags$details(class = "context-more",
          tags$summary("Read more about this period"),
          lapply(ctx, tags$p)
        )
      },
      if (nrow(ev)) {
        tagList(
          div(class = "events-title", "Key events (oldest → youngest)"),
          tags$ul(class = "event-list",
            lapply(seq_len(nrow(ev)), function(i) {
              tags$li(
                span(class = "event-when", ev$when[i]),
                span(class = "event-name", ev$title[i]), " – ", ev$detail[i]
              )
            })
          )
        )
      }
    )
  })
  
  # How it works - dynamic based on playlist
  output$how_it_works <- renderUI({
    s <- current_playlist()$stats
    p(class = "description-text",
      "CO₂ concentrations are mapped to beats per minute (BPM):",
      tags$br(), tags$br(),
      paste0("• Low CO₂ (", s$scale_min, " ppm) → ", BPM_MIN, " BPM (slow, ambient)"),
      tags$br(),
      paste0("• High CO₂ (", s$scale_max, " ppm) → ", BPM_MAX, " BPM (fast, intense)")
    )
  })
  
  # Statistics
  output$stat_years <- renderText({
    s <- current_playlist()$stats
    format(s$years_span, big.mark = ",", scientific = FALSE)
  })
  
  output$stat_songs <- renderText({
    current_playlist()$stats$num_songs
  })
  
  output$stat_co2_min <- renderText({
    paste0(current_playlist()$stats$co2_min, " ppm")
  })
  
  output$stat_co2_max <- renderText({
    paste0(current_playlist()$stats$co2_max, " ppm")
  })
  
  # Timeline plot
  output$timeline_plot <- renderPlotly({
    pl <- current_playlist()
    period <- current_period()
    data <- pl$raw_data
    
    if (nrow(data) == 0) return(NULL)
    
    # Determine x-axis based on timescale
    ax <- axis_for_period(period)
    
    data <- data %>% mutate(x_val = ax$scale(age))
    x_title <- ax$title
    x_reversed <- ax$reversed
    
    # Build plot
    p <- plot_ly() %>%
      add_trace(
        data = data,
        x = ~x_val,
        y = ~co2,
        type = "scatter",
        mode = "lines",
        fill = "tozeroy",
        fillcolor = "rgba(102, 126, 234, 0.2)",
        line = list(color = "#667eea", width = 2),
        hovertemplate = "<b>%{y:.0f} ppm</b><extra></extra>"
      ) %>%
      layout(
        xaxis = list(
          title = x_title,
          color = "#a1a1aa",
          gridcolor = "rgba(255,255,255,0.05)",
          autorange = if (x_reversed) "reversed" else TRUE
        ),
        yaxis = list(
          title = "CO₂ (ppm)",
          color = "#a1a1aa",
          gridcolor = "rgba(255,255,255,0.05)"
        ),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)",
        margin = list(l = 60, r = 20, t = 20, b = 50),
        showlegend = FALSE
      )
    
    # Ball for the selected song: sits on the curve at the current playback
    # position and is moved by the play_frac() observer while the song plays.
    # The song's time window is shaded so you can see where it will travel.
    # Key events: dotted vertical lines (shapes) + hoverable markers on top.
    ev <- period_key_events(input$selected_period)
    ev <- ev[ev$age >= min(data$age) & ev$age <= max(data$age), , drop = FALSE]
    event_shapes <- lapply(seq_len(nrow(ev)), function(i) list(
      type = "line", xref = "x", yref = "paper",
      x0 = ax$scale(ev$age[i]), x1 = ax$scale(ev$age[i]), y0 = 0, y1 = 1,
      line = list(color = "rgba(245,158,11,0.35)", width = 1, dash = "dot"),
      layer = "below"
    ))
    p <- p %>% layout(shapes = event_shapes)

    song <- selected_song()
    if (!is.null(song)) {
      pos <- ball_position(song, data, isolate(play_frac()))
      marker_x <- ax$scale(pos$age)
      
      p <- p %>%
        layout(shapes = c(event_shapes, list(list(
          type = "rect", xref = "x", yref = "paper",
          x0 = ax$scale(song$start_age), x1 = ax$scale(song$end_age),
          y0 = 0, y1 = 1,
          fillcolor = "rgba(255,255,255,0.06)",
          line = list(width = 0), layer = "below"
        )))) %>%
        add_trace(
          x = marker_x,
          y = pos$co2,
          type = "scatter",
          mode = "markers",
          marker = list(
            size = 14,
            color = song$bpm_color,
            line = list(color = "white", width = 2)
          ),
          hovertemplate = paste0(
            "<b>Song #", song$song_number, "</b><br>",
            song$avg_co2, " ppm → ", song$bpm, " BPM<extra></extra>"
          )
        )
    }

    # Added last on purpose: the play-progress observer restyles trace 1 (ball).
    if (nrow(ev)) {
      p <- p %>%
        add_trace(
          x = ax$scale(ev$age),
          y = rep(max(data$co2, na.rm = TRUE), nrow(ev)),
          type = "scatter", mode = "markers",
          marker = list(symbol = "triangle-down", size = 9, color = "#f59e0b"),
          text = paste0("<b>", ev$when, " – ", ev$title, "</b><br>",
                        vapply(strwrap(ev$detail, 50, simplify = FALSE),
                               paste, character(1), collapse = "<br>")),
          hovertemplate = "%{text}<extra></extra>"
        )
    }

    p
  })
  
  # Now playing display
  output$now_playing <- renderUI({
    song <- selected_song()
    if (is.null(song)) {
      return(p("Select a song from the playlist", class = "muted"))
    }
    
    tagList(
      div(class = "now-playing-row",
          span(class = "now-playing-label-small", "TIME PERIOD"),
          div(class = "now-playing-value", song$age_range)
      ),
      div(class = "now-playing-row",
          span(class = "now-playing-label-small", "CO₂ CONCENTRATION"),
          div(class = "now-playing-value", paste0(song$avg_co2, " ppm"))
      ),
      {
        ev <- events_in_window(input$selected_period, song$start_age, song$end_age)
        if (nrow(ev)) {
          div(class = "song-events",
              span(class = "now-playing-label-small", "DURING THIS SONG"),
              lapply(seq_len(nrow(ev)), function(i)
                div("📍 ", tags$b(ev$when[i]), " – ", ev$title[i]))
          )
        }
      },
      div(class = "now-playing-bpm",
          span(class = "bpm-large", style = paste0("color:", song$bpm_color), song$bpm),
          span(class = "bpm-label", "BPM")
      ),
      div(class = "mood-tag", song$mood)
    )
  })

  # Listen panel: embedded player(s) + direct links for a curated slot,
  # or the BPM/mood search buttons for a slot you haven't filled yet.
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
      # ----- Curated slot: show players + direct links -----
      title_txt  <- if (!is.null(cur) && !is.na(cur$song_title) &&
                        nzchar(trimws(cur$song_title))) trimws(cur$song_title) else NULL
      artist_txt <- if (!is.null(cur) && !is.na(cur$artist) &&
                        nzchar(trimws(cur$artist))) trimws(cur$artist) else NULL

      header <- if (!is.null(title_txt) || !is.null(artist_txt)) {
        div(class = "curated-track",
            span(class = "curated-badge", "🎵 Curated pick"),
            div(class = "curated-title",
                tags$strong(title_txt %||% "Untitled"),
                if (!is.null(artist_txt)) span(class = "muted", paste0("  ·  ", artist_txt))
            )
        )
      } else {
        div(class = "curated-track",
            span(class = "curated-badge", "🎵 Curated pick"))
      }

      # ONE player per song. "Play via" picks the service; if this song has
      # no link for it, fall back to the best available one:
      #   Spotify full player (connected) > YouTube > SoundCloud > Spotify preview
      # www/player.js wires each one up for progress / end-of-song events.
      sp_uri <- if (!is.na(sp_embed)) paste0("spotify:track:", parse_spotify_id(cur$spotify_uri))

      avail <- c(
        spotify_full = !is.na(sp_embed) && sdk_ready(),
        youtube      = !is.na(yt_id) && !(yt_id %in% bad_yt()),
        soundcloud   = !is.na(sc_embed),
        spotify      = !is.na(sp_embed)
      )
      want <- input$play_source %||% "auto"
      order <- switch(want,
        # Spotify is the default and stays on Spotify: the full player once
        # connected, otherwise Spotify's 30-s clip (auto-plays + auto-advances).
        spotify    = c("spotify_full", "spotify", "soundcloud", "youtube"),
        youtube    = c("youtube", "spotify_full", "soundcloud", "spotify"),
        soundcloud = c("soundcloud", "spotify_full", "youtube", "spotify"),
        c("spotify_full", "youtube", "soundcloud", "spotify")
      )
      use <- order[avail[order]][1]
      label <- c(spotify_full = "Spotify", spotify = "Spotify (30-s preview)",
                 youtube = "YouTube", soundcloud = "SoundCloud")
      want_label <- c(spotify = "Spotify", youtube = "YouTube", soundcloud = "SoundCloud")

      player <- switch(use,
        spotify_full = div(id = "bpm-sdk", `data-uri` = sp_uri, style = "margin-top:0.75rem;",
                           tags$button(id = "bpm-sdk-toggle", type = "button",
                                       class = "btn btn-spotify", "▶ Play")),
        youtube = div(style = "border-radius:12px; overflow:hidden; margin-top:0.75rem;",
                      div(id = "bpm-youtube", `data-id` = yt_id)),
        soundcloud = tags$iframe(
          id = "bpm-soundcloud", src = sc_embed,
          width = "100%", height = "166", frameborder = "no", scrolling = "no",
          allow = "autoplay", style = "margin-top:0.75rem;"
        ),
        spotify = div(style = "border-radius:12px; overflow:hidden; margin-top:0.75rem;",
                      div(id = "bpm-spotify", `data-uri` = sp_uri))
      )

      source_note <- p(class = "muted", style = "font-size:0.8rem; margin:0.4rem 0 0;",
        paste0("Playing via ", label[[use]],
               if (want != "auto" && !startsWith(use, want) &&
                   !isTRUE(c(spotify = !is.na(sp_embed), youtube = !is.na(yt_id),
                             soundcloud = !is.na(sc_embed))[[want]]))
                 paste0(" (no ", want_label[[want]], " link for this song)") else "",
               if (want == "youtube" && !is.na(yt_id) && yt_id %in% bad_yt())
                 " (this YouTube video can't be embedded)" else "",
               if (use == "spotify") " \u2014 30-s clip; click Connect Spotify for whole songs." else ""))

      # Always one button per service: open the song if we have a link,
      # otherwise search that service for it.
      q_song <- utils::URLencode(paste(artist_txt %||% "", title_txt %||% ""), reserved = TRUE)
      links <- div(class = "button-row",
        tags$a(href = if (!is.na(sp_open)) sp_open else paste0("https://open.spotify.com/search/", q_song),
               target = "_blank", class = "btn btn-spotify",
               if (!is.na(sp_open)) "🎵 Open in Spotify" else "🔎 Find on Spotify"),
        tags$a(href = if (!is.na(yt_open)) yt_open else paste0("https://www.youtube.com/results?search_query=", q_song),
               target = "_blank", class = "btn btn-youtube",
               if (!is.na(yt_open)) "▶ Open on YouTube" else "🔎 Find on YouTube"),
        tags$a(href = if (!is.na(sc_open)) sc_open else paste0("https://soundcloud.com/search?q=", q_song),
               target = "_blank", class = "btn btn-soundcloud",
               if (!is.na(sc_open)) "☁️ Open in SoundCloud" else "🔎 Find on SoundCloud")
      )

      # Spotify preferred but not connected: say so right at the player,
      # with the one click that unlocks full songs.
      connect_hint <- if (want %in% c("spotify", "auto") && !sdk_ready() &&
                          !is.na(sp_embed) && spotify_configured()) {
        div(class = "spotify-connect", style = "margin-top:0.75rem;",
            if (isTRUE(sp_connected())) {
              span(class = "muted", "Starting the Spotify player\u2026 (needs Spotify Premium)")
            } else {
              tagList(
                actionButton("sp_connect_inline", "\u25B6 Connect Spotify to play the full song",
                             class = "btn btn-spotify"),
                div(class = "muted", style = "font-size:0.8rem; margin-top:0.3rem;",
                    "One-time login. Without it Spotify only allows 30-s previews.")
              )
            })
      }

      div(id = "bpm-player",
          `data-token`    = player_token(),
          `data-autoplay` = tolower(isolate(listening())),
          header, connect_hint, player, source_note, links)

    } else {
      # ----- Blank slot: keep the BPM/mood search buttons -----
      query <- paste(song$bpm, "bpm", gsub(" –.*", "", song$mood))
      spotify_search    <- paste0("https://open.spotify.com/search/",
                                  utils::URLencode(query, reserved = TRUE))
      soundcloud_search <- paste0("https://soundcloud.com/search?q=",
                                  utils::URLencode(query, reserved = TRUE))

      tagList(
        p(class = "description-text",
          "No song in your library matches this slot yet. Add more tracks to ",
          tags$code("data/song_library.csv"),
          " (with their BPM) to fill it — or search for a song near this BPM:"),
        div(class = "button-row",
            tags$a(href = spotify_search, target = "_blank",
                   class = "btn btn-spotify", "🎵 Spotify"),
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
        paste0("▶ ", fmt(pp$pos), " / ", fmt(pp$dur),
               ""))
  })

  # Playlist table
  output$playlist_table <- renderDT({
    pl <- current_playlist()
    
    display_df <- pl$songs %>%
      select(
        `#` = song_number,
        `Time Period` = age_range,
        `CO₂` = avg_co2,
        `BPM` = bpm,
        `Mood` = mood
      )
    
    idx <- selected_idx()
    datatable(
      display_df,
      selection = list(mode = "single", selected = idx),
      options = list(
        pageLength = 10,
        displayStart = (ceiling(idx / 10) - 1) * 10,
        dom = "ftp",
        scrollY = "300px",
        scrollCollapse = TRUE,
        language = list(search = "Filter:")
      ),
      rownames = FALSE,
      class = "cell-border stripe"
    ) %>%
      formatStyle(
        "BPM",
        backgroundColor = styleInterval(
          c(75, 95, 115, 135),
          c("#1e3a5f", "#2d4a6f", "#3d5a7f", "#6d3a5f", "#8d2a4f")
        ),
        color = "white"
      )
  })
  
  # Download handler
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("playlist_", input$selected_period, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      template <- create_playlist_template(current_playlist())
      write_csv(template, file)
    }
  )
}

# -----------------------------------------------------------------------------
# RUN THE APP
# -----------------------------------------------------------------------------

# Fixed port (the Spotify Redirect URI points here) and the system browser:
# the Spotify player can't run inside the RStudio Viewer.
shinyApp(ui = ui, server = server,
         options = list(port = SPOTIFY_PORT, launch.browser = TRUE))
