# =============================================================================
# PALEOCLIMATE PLAYLIST - SHINY APPLICATION
# =============================================================================
#
# Description:
#   Interactive web application that translates atmospheric CO2 concentrations
#   through geological time into "beats per minute" (BPM) values for creating
#   music playlists. Lower CO2 = slower/sadder songs; Higher CO2 = faster songs.
#
# To run this app:
#   1. Make sure you have the required packages installed (see below)
#   2. Set your working directory to the folder containing this file
#   3. Run: shiny::runApp()
#
# Required packages:
#   install.packages(c("shiny", "shinydashboard", "readxl", "tidyverse", 
#                      "plotly", "DT", "shinyWidgets", "bslib"))
#
# =============================================================================

# -----------------------------------------------------------------------------
# 1. LOAD PACKAGES
# -----------------------------------------------------------------------------

library(shiny)
library(shinydashboard)
library(readxl)
library(tidyverse)
library(plotly)
library(DT)
library(shinyWidgets)
library(bslib)

# -----------------------------------------------------------------------------
# 2. GLOBAL CONFIGURATION
# -----------------------------------------------------------------------------

# BPM range for music mapping
BPM_MIN <- 60
BPM_MAX <- 150

# Average song length in minutes
AVG_SONG_LENGTH <- 3

# Reference year for age calculations
REFERENCE_YEAR <- 1950

# Time period configurations
TIME_PERIODS <- list(
  modern = list(
    id = "modern",
    name = "Modern Era (1958-Present)",
    subtitle = "~67 years",
    years_span = 67,
    years_per_minute = 1,
    description = paste(
      "Direct atmospheric CO₂ measurements from Mauna Loa Observatory, Hawaii.",
      "This period captures the dramatic 'Keeling Curve' - the most famous graph",
      "in climate science showing CO₂ rising from ~315 to over 420 ppm."
    ),
    data_source = "modern",
    filter_max_age = Inf,
    color = "#3b82f6"
  ),
  
  roman = list(
    id = "roman",
    name = "Roman Empire Era (~2,000 years)",
    subtitle = "~2,000 years",
    years_span = 2000,
    years_per_minute = 20,
    description = paste(
      "Ice core records spanning the Roman Empire, Medieval Period, Little Ice Age,",
      "and Industrial Revolution. CO₂ remained remarkably stable at ~280 ppm for",
      "nearly 2000 years until the 1800s."
    ),
    data_source = "icecore",
    filter_max_age = 2000,
    color = "#8b5cf6"
  ),
  
  lgm = list(
    id = "lgm",
    name = "Last Glacial Maximum (~20,000 years)",
    subtitle = "~20,000 years",
    years_span = 20000,
    years_per_minute = 100,
    description = paste(
      "The transition from the Last Ice Age (~20,000 years ago) to our current",
      "warm period. CO₂ rose from ~180 ppm during peak glaciation to ~280 ppm",
      "as ice sheets retreated."
    ),
    data_source = "icecore",
    filter_max_age = 20000,
    color = "#06b6d4"
  ),
  
  humans = list(
    id = "humans",
    name = "Early Modern Humans (~250,000 years)",
    subtitle = "~250,000 years",
    years_span = 250000,
    years_per_minute = 1000,
    description = paste(
      "The entire existence of anatomically modern Homo sapiens. Multiple glacial",
      "cycles with CO₂ swinging between ~180 ppm (ice ages) and ~280 ppm (warm",
      "interglacials)."
    ),
    data_source = "icecore",
    filter_max_age = 250000,
    color = "#f59e0b"
  ),
  
  full = list(
    id = "full",
    name = "Full Ice Core Record (~800,000 years)",
    subtitle = "~800,000 years",
    years_span = 800000,
    years_per_minute = 3000,
    description = paste(
      "Eight complete glacial-interglacial cycles. Throughout 800,000 years,",
      "CO₂ NEVER exceeded 300 ppm until our modern era - a truly unprecedented",
      "geological moment."
    ),
    data_source = "icecore",
    filter_max_age = 800000,
    color = "#ef4444"
  )
)

# -----------------------------------------------------------------------------
# 3. HELPER FUNCTIONS
# -----------------------------------------------------------------------------

#' Convert CO2 concentration to beats per minute
#' @param co2 CO2 value(s) in ppm
#' @param co2_min Minimum CO2 in the dataset
#' @param co2_max Maximum CO2 in the dataset
#' @return Numeric BPM value(s)
co2_to_bpm <- function(co2, co2_min, co2_max) {
  bpm <- BPM_MIN + ((BPM_MAX - BPM_MIN) / (co2_max - co2_min)) * (co2 - co2_min)
  return(round(pmin(pmax(bpm, BPM_MIN), BPM_MAX), 0))
}

#' Get music mood/genre from BPM
#' @param bpm Beats per minute value
#' @return Character string with mood and genre
get_mood_from_bpm <- function(bpm) {
  case_when(
    bpm < 70 ~ "Glacial - Ambient / Drone",
    bpm < 90 ~ "Contemplative - Slow Jazz / Ballads",
    bpm < 110 ~ "Moderate - Pop / Soft Rock",
    bpm < 130 ~ "Energetic - Rock / Funk",
    TRUE ~ "Intense - Dance / Electronic"
  )
}

#' Format age for display
#' @param age Age in years (negative = CE, positive = BP)
#' @return Formatted string
format_age <- function(age) {
  sapply(age, function(a) {
    if (a < 0) {
      year <- round(REFERENCE_YEAR - a)
      return(paste0(year, " CE"))
    }
    if (a < 1000) return(paste0(round(a), " years BP"))
    if (a < 10000) return(paste0(round(a/1000, 1), "k years BP"))
    return(paste0(round(a/1000), "k years BP"))
  })
}

#' Get color for BPM value (blue to red gradient)
#' @param bpm BPM value
#' @return Hex color string
get_bpm_color <- function(bpm) {
  ratio <- (bpm - BPM_MIN) / (BPM_MAX - BPM_MIN)
  r <- round(59 + ratio * 180)
  g <- round(130 - ratio * 62)
  b <- round(246 - ratio * 178)
  return(sprintf("#%02x%02x%02x", r, g, b))
}

#' Generate playlist data for a time period
#' @param period_config Period configuration list
#' @param co2_data List with modern and icecore dataframes
#' @return List with songs dataframe and stats
generate_playlist <- function(period_config, co2_data) {
  
  # Select appropriate data source
  if (period_config$data_source == "modern") {
    data <- co2_data$modern
  } else {
    data <- co2_data$icecore %>%
      filter(age <= period_config$filter_max_age)
  }
  
  if (nrow(data) == 0) {
    return(list(songs = data.frame(), stats = list()))
  }
  
  # Calculate CO2 range
  co2_min <- min(data$co2, na.rm = TRUE)
  co2_max <- max(data$co2, na.rm = TRUE)
  
  # Calculate playlist metrics
  playlist_minutes <- period_config$years_span / period_config$years_per_minute
  num_songs <- ceiling(playlist_minutes / AVG_SONG_LENGTH)
  years_per_song <- period_config$years_span / num_songs
  
  # Generate songs
  songs <- tibble(
    song_number = 1:num_songs,
    start_age = (0:(num_songs-1)) * years_per_song,
    end_age = (1:num_songs) * years_per_song
  )
  
  # Calculate average CO2 for each song
  songs <- songs %>%
    rowwise() %>%
    mutate(
      # Find data points in this range
      relevant_data = list(
        if (period_config$data_source == "modern") {
          data %>% filter(-age >= start_age & -age < end_age)
        } else {
          data %>% filter(age >= start_age & age < end_age)
        }
      ),
      avg_co2 = if (nrow(relevant_data) > 0) {
        round(mean(relevant_data$co2, na.rm = TRUE), 0)
      } else {
        # Interpolate if no data points in range
        mid_age <- (start_age + end_age) / 2
        closest <- data %>%
          mutate(dist = abs(ifelse(period_config$data_source == "modern", -age, age) - mid_age)) %>%
          arrange(dist) %>%
          head(2)
        round(mean(closest$co2), 0)
      }
    ) %>%
    ungroup() %>%
    select(-relevant_data)
  
  # Add BPM and mood
  songs <- songs %>%
    mutate(
      bpm = co2_to_bpm(avg_co2, co2_min, co2_max),
      mood = get_mood_from_bpm(bpm),
      bpm_color = sapply(bpm, get_bpm_color)
    )
  
  # Adjust ages for display based on data source
  if (period_config$data_source == "modern") {
    songs <- songs %>%
      mutate(
        display_start = format_age(-end_age),
        display_end = format_age(-start_age)
      ) %>%
      arrange(desc(song_number)) %>%
      mutate(song_number = row_number())
  } else {
    songs <- songs %>%
      mutate(
        display_start = format_age(start_age),
        display_end = format_age(end_age)
      )
  }
  
  # Stats
  stats <- list(
    total_years = period_config$years_span,
    playlist_minutes = round(playlist_minutes, 0),
    num_songs = num_songs,
    co2_min = round(co2_min, 0),
    co2_max = round(co2_max, 0),
    years_per_song = round(years_per_song, 0)
  )
  
  return(list(songs = songs, stats = stats, raw_data = data))
}

# -----------------------------------------------------------------------------
# 4. LOAD DATA (or create sample data if file not found)
# -----------------------------------------------------------------------------

load_co2_data <- function() {
  
  # Try to load from file
  data_file <- "data/co2_data.xlsx"
  
  if (file.exists(data_file)) {
    modern <- read_excel(data_file, sheet = "maunaloa") %>%
      select(age, co2)
    icecore <- read_excel(data_file, sheet = "bereiter2014") %>%
      select(age, co2)
  } else {
    # Create sample data for demonstration
    message("Data file not found. Using sample data for demonstration.")
    
    # Sample modern data (1958-2024)
    modern <- tibble(
      age = seq(-8, -74, by = -1),
      co2 = c(315.7, 316.7, 317.6, 318.5, 319.7, 319.9, 320.8, 320.9, 322.4,
              323.0, 323.9, 325.6, 326.9, 327.2, 327.8, 330.3, 331.5, 331.9,
              333.4, 335.0, 336.7, 338.3, 340.1, 341.6, 342.8, 343.4, 345.7,
              347.9, 348.3, 349.8, 352.5, 354.1, 355.8, 357.3, 358.0, 358.6,
              360.1, 362.0, 364.3, 364.7, 367.4, 369.8, 370.8, 372.6, 374.3,
              376.6, 379.1, 381.0, 382.9, 384.8, 386.3, 389.0, 391.4, 392.8,
              394.6, 397.7, 399.9, 401.7, 405.1, 407.5, 409.6, 412.2, 414.7,
              417.6, 418.8, 421.0, 425.4)
    )
    
    # Sample ice core data (key points over 800,000 years)
    icecore <- tibble(
      age = c(-51, 0, 500, 1000, 2000, 5000, 8000, 10000, 11500, 12000,
              14000, 16000, 18000, 20000, 25000, 30000, 40000, 50000,
              60000, 70000, 80000, 90000, 100000, 110000, 120000, 130000,
              140000, 150000, 180000, 200000, 220000, 240000, 260000,
              280000, 300000, 320000, 340000, 400000, 450000, 500000,
              550000, 600000, 650000, 700000, 750000, 800000),
      co2 = c(368, 312, 283, 280, 277, 266, 260, 264, 267, 250, 240, 220,
              188, 190, 183, 188, 195, 204, 210, 215, 230, 230, 245, 255,
              275, 250, 195, 200, 210, 245, 210, 275, 210, 200, 230, 250,
              235, 280, 200, 230, 245, 240, 190, 235, 195, 200)
    )
  }
  
  return(list(modern = modern, icecore = icecore))
}

# Load data at startup
CO2_DATA <- load_co2_data()

# -----------------------------------------------------------------------------
# 5. USER INTERFACE
# -----------------------------------------------------------------------------

ui <- fluidPage(
  
  # Custom CSS
  tags$head(
    tags$style(HTML("
      @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=JetBrains+Mono:wght@300;400;500&family=DM+Sans:wght@400;500;600&display=swap');
      
      body {
        font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, sans-serif;
        background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 100%);
        color: #f5f5f7;
        min-height: 100vh;
      }
      
      .main-header {
        background: rgba(10, 10, 15, 0.9) !important;
        border-bottom: 1px solid rgba(255,255,255,0.1);
        padding: 1.5rem 2rem;
        margin-bottom: 2rem;
      }
      
      .main-title {
        font-family: 'Playfair Display', serif;
        font-size: 2rem;
        font-weight: 600;
        margin: 0;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
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
        font-family: 'Playfair Display', serif;
        font-size: 1.25rem;
        margin-bottom: 1rem;
        color: #f5f5f7;
      }
      
      .stat-box {
        background: rgba(255,255,255,0.03);
        border-radius: 12px;
        padding: 1rem;
        text-align: center;
        margin-bottom: 0.5rem;
      }
      
      .stat-value {
        font-family: 'JetBrains Mono', monospace;
        font-size: 1.75rem;
        font-weight: 500;
      }
      
      .stat-value.cold { color: #3b82f6; }
      .stat-value.warm { color: #ef4444; }
      .stat-value.gold { color: #f59e0b; }
      
      .stat-label {
        font-size: 0.75rem;
        color: #a1a1aa;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        margin-top: 0.25rem;
      }
      
      .period-btn {
        width: 100%;
        padding: 1rem;
        margin-bottom: 0.5rem;
        background: rgba(255,255,255,0.03);
        border: 1px solid rgba(255,255,255,0.05);
        border-radius: 12px;
        color: #f5f5f7;
        text-align: left;
        transition: all 0.3s ease;
        cursor: pointer;
      }
      
      .period-btn:hover {
        background: rgba(255,255,255,0.08);
        border-color: rgba(255,255,255,0.1);
        transform: translateX(4px);
      }
      
      .period-btn.active {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        border-color: transparent;
      }
      
      .now-playing {
        background: linear-gradient(135deg, rgba(26, 26, 37, 0.9) 0%, rgba(102, 126, 234, 0.1) 100%);
        border: 1px solid rgba(102, 126, 234, 0.3);
        border-radius: 16px;
        padding: 1.5rem;
        margin-bottom: 1rem;
      }
      
      .bpm-large {
        font-family: 'Playfair Display', serif;
        font-size: 3rem;
        font-weight: 600;
      }
      
      .mood-tag {
        display: inline-block;
        padding: 0.4rem 0.8rem;
        background: rgba(255,255,255,0.1);
        border-radius: 20px;
        font-size: 0.8rem;
        color: #a1a1aa;
      }
      
      .description-text {
        color: #a1a1aa;
        font-size: 0.9rem;
        line-height: 1.6;
      }
      
      .btn-spotify {
        background: #1DB954 !important;
        color: #000 !important;
        border: none;
        border-radius: 20px;
        padding: 0.6rem 1.2rem;
        font-weight: 500;
      }
      
      .btn-soundcloud {
        background: #ff5500 !important;
        color: #fff !important;
        border: none;
        border-radius: 20px;
        padding: 0.6rem 1.2rem;
        font-weight: 500;
      }
      
      .dataTables_wrapper {
        color: #a1a1aa;
      }
      
      .dataTable {
        color: #f5f5f7 !important;
      }
      
      .dataTables_info, .dataTables_length, .dataTables_filter {
        color: #a1a1aa !important;
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
      
      .plotly .modebar {
        background: transparent !important;
      }
      
      .shiny-input-container {
        color: #f5f5f7;
      }
      
      .form-control {
        background: rgba(255,255,255,0.05);
        border: 1px solid rgba(255,255,255,0.1);
        color: #f5f5f7;
      }
      
      .selectize-input {
        background: rgba(255,255,255,0.05) !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
        color: #f5f5f7 !important;
      }
      
      .selectize-dropdown {
        background: #1a1a2e !important;
        border: 1px solid rgba(255,255,255,0.1) !important;
      }
      
      .selectize-dropdown-content .option {
        color: #f5f5f7 !important;
      }
      
      .selectize-dropdown-content .option.active {
        background: rgba(102, 126, 234, 0.3) !important;
      }
    "))
  ),
  
  # Header
  div(class = "main-header",
      h1(class = "main-title", "🌍 Paleoclimate Playlist"),
      p(class = "main-subtitle", "Translating Earth's Climate History into Music")
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
               h3(class = "card-title", "About This Period"),
               uiOutput("period_description")
           ),
           
           div(class = "card",
               h3(class = "card-title", "How It Works"),
               p(class = "description-text",
                 "CO₂ concentrations are mapped to beats per minute (BPM).",
                 br(), br(),
                 "• Lower CO₂ (ice ages, ~180 ppm) → 60 BPM (slow, ambient)",
                 br(),
                 "• Higher CO₂ (modern, 420+ ppm) → 150 BPM (fast, electronic)"
               )
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
                        div(class = "stat-value", style = "color: #8b5cf6;", 
                            textOutput("stat_songs", inline = TRUE)),
                        div(class = "stat-label", "Songs")
                    )
             ),
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value cold", textOutput("stat_co2_min", inline = TRUE)),
                        div(class = "stat-label", "Min CO₂ (ppm)")
                    )
             ),
             column(3,
                    div(class = "stat-box",
                        div(class = "stat-value warm", textOutput("stat_co2_max", inline = TRUE)),
                        div(class = "stat-label", "Max CO₂ (ppm)")
                    )
             )
           ),
           
           # Timeline plot
           div(class = "card",
               h3(class = "card-title", "CO₂ Timeline"),
               plotlyOutput("timeline_plot", height = "250px")
           ),
           
           # Now playing and playlist
           fluidRow(
             column(5,
                    div(class = "now-playing",
                        h4(style = "color: #a1a1aa; font-size: 0.8rem; margin-bottom: 1rem;",
                           "🎵 SELECTED SONG"),
                        uiOutput("now_playing")
                    ),
                    
                    div(class = "card",
                        h3(class = "card-title", "Find Music"),
                        p(class = "description-text", 
                          "Search for songs matching the selected BPM:"),
                        br(),
                        fluidRow(
                          column(6,
                                 actionButton("btn_spotify", "🎵 Spotify", 
                                              class = "btn-spotify", 
                                              onclick = "window.open(document.getElementById('spotify_url').href, '_blank')")),
                          column(6,
                                 actionButton("btn_soundcloud", "☁️ SoundCloud", 
                                              class = "btn-soundcloud",
                                              onclick = "window.open(document.getElementById('soundcloud_url').href, '_blank')"))
                        ),
                        # Hidden links for URL generation
                        tags$a(id = "spotify_url", href = "", style = "display:none;"),
                        tags$a(id = "soundcloud_url", href = "", style = "display:none;")
                    )
             ),
             
             column(7,
                    div(class = "card",
                        div(style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;",
                            h3(class = "card-title", style = "margin: 0;", "Playlist"),
                            downloadButton("download_playlist", "📥 Download CSV", 
                                           style = "background: rgba(255,255,255,0.1); border: none; color: #f5f5f7; border-radius: 8px;")
                        ),
                        DTOutput("playlist_table")
                    )
             )
           )
    )
  ),
  
  # Footer
  div(style = "text-align: center; padding: 2rem; color: #a1a1aa; font-size: 0.8rem; border-top: 1px solid rgba(255,255,255,0.05); margin-top: 2rem;",
      p("Data sources: ",
        tags$a(href = "https://gml.noaa.gov/ccgg/trends/", target = "_blank", 
               style = "color: #3b82f6;", "NOAA Mauna Loa CO₂"),
        " • ",
        tags$a(href = "https://www.ncei.noaa.gov/access/paleo-search/", target = "_blank",
               style = "color: #3b82f6;", "NOAA Paleoclimatology"),
        " (Bereiter et al., 2015)"
      )
  )
)

# -----------------------------------------------------------------------------
# 6. SERVER LOGIC
# -----------------------------------------------------------------------------

server <- function(input, output, session) {
  
  # Reactive: Get current period configuration
  current_period <- reactive({
    TIME_PERIODS[[input$selected_period]]
  })
  
  # Reactive: Generate playlist for current period
  playlist_data <- reactive({
    generate_playlist(current_period(), CO2_DATA)
  })
  
  # Reactive: Selected song (from table click)
  selected_song_index <- reactiveVal(1)
  
  # Observe table row selection
  observeEvent(input$playlist_table_rows_selected, {
    if (length(input$playlist_table_rows_selected) > 0) {
      selected_song_index(input$playlist_table_rows_selected[1])
    }
  })
  
  # Reset selection when period changes
  observeEvent(input$selected_period, {
    selected_song_index(1)
  })
  
  # Get selected song
  selected_song <- reactive({
    pd <- playlist_data()
    idx <- selected_song_index()
    if (nrow(pd$songs) >= idx) {
      pd$songs[idx, ]
    } else if (nrow(pd$songs) > 0) {
      pd$songs[1, ]
    } else {
      NULL
    }
  })
  
  # Output: Period description
  output$period_description <- renderUI({
    p(class = "description-text", current_period()$description)
  })
  
  # Output: Statistics
  output$stat_years <- renderText({
    format(playlist_data()$stats$total_years, big.mark = ",")
  })
  
  output$stat_songs <- renderText({
    playlist_data()$stats$num_songs
  })
  
  output$stat_co2_min <- renderText({
    paste0(playlist_data()$stats$co2_min, " ppm")
  })
  
  output$stat_co2_max <- renderText({
    paste0(playlist_data()$stats$co2_max, " ppm")
  })
  
  # Output: Timeline plot
  output$timeline_plot <- renderPlotly({
    pd <- playlist_data()
    period <- current_period()
    
    data <- pd$raw_data
    if (nrow(data) == 0) return(NULL)
    
    # Prepare x-axis (time)
    if (period$data_source == "modern") {
      data <- data %>% mutate(x_val = REFERENCE_YEAR - age)
      x_title <- "Year (CE)"
    } else {
      data <- data %>% mutate(x_val = age / 1000)
      x_title <- "Age (thousands of years BP)"
    }
    
    # Get current song position for marker
    song <- selected_song()
    
    p <- plot_ly() %>%
      add_trace(
        data = data,
        x = ~x_val,
        y = ~co2,
        type = 'scatter',
        mode = 'lines',
        fill = 'tozeroy',
        fillcolor = 'rgba(102, 126, 234, 0.2)',
        line = list(color = '#667eea', width = 2),
        hovertemplate = paste0(
          "<b>%{y:.0f} ppm</b><br>",
          "%{x}<extra></extra>"
        )
      ) %>%
      layout(
        xaxis = list(
          title = x_title,
          color = '#a1a1aa',
          gridcolor = 'rgba(255,255,255,0.05)',
          zerolinecolor = 'rgba(255,255,255,0.1)',
          autorange = if (period$data_source != "modern") "reversed" else TRUE
        ),
        yaxis = list(
          title = "CO₂ (ppm)",
          color = '#a1a1aa',
          gridcolor = 'rgba(255,255,255,0.05)',
          zerolinecolor = 'rgba(255,255,255,0.1)'
        ),
        paper_bgcolor = 'rgba(0,0,0,0)',
        plot_bgcolor = 'rgba(0,0,0,0)',
        margin = list(l = 50, r = 20, t = 20, b = 50),
        showlegend = FALSE
      )
    
    # Add marker for current song
    if (!is.null(song)) {
      if (period$data_source == "modern") {
        marker_x <- REFERENCE_YEAR + (song$start_age + song$end_age) / 2
      } else {
        marker_x <- (song$start_age + song$end_age) / 2 / 1000
      }
      
      p <- p %>%
        add_trace(
          x = c(marker_x),
          y = c(song$avg_co2),
          type = 'scatter',
          mode = 'markers',
          marker = list(
            size = 15,
            color = song$bpm_color,
            line = list(color = 'white', width = 2)
          ),
          hovertemplate = paste0(
            "<b>Song #", song$song_number, "</b><br>",
            song$avg_co2, " ppm → ", song$bpm, " BPM<extra></extra>"
          )
        )
    }
    
    p
  })
  
  # Output: Now playing
  output$now_playing <- renderUI({
    song <- selected_song()
    if (is.null(song)) {
      return(p("Select a song from the playlist", style = "color: #a1a1aa;"))
    }
    
    tagList(
      div(style = "margin-bottom: 1rem;",
          span(style = "color: #a1a1aa; font-size: 0.75rem;", "TIME PERIOD"),
          div(style = "font-family: 'JetBrains Mono', monospace; font-size: 1.1rem;",
              paste(song$display_start, "→", song$display_end))
      ),
      div(style = "margin-bottom: 1rem;",
          span(style = "color: #a1a1aa; font-size: 0.75rem;", "CO₂ CONCENTRATION"),
          div(style = "font-family: 'JetBrains Mono', monospace; font-size: 1.1rem;",
              paste0(song$avg_co2, " ppm"))
      ),
      div(
        span(class = "bpm-large", style = paste0("color: ", song$bpm_color, ";"), song$bpm),
        span(style = "color: #a1a1aa; margin-left: 0.5rem;", "BPM")
      ),
      div(style = "margin-top: 0.75rem;",
          span(class = "mood-tag", song$mood)
      )
    )
  })
  
  # Output: Playlist table
  output$playlist_table <- renderDT({
    pd <- playlist_data()
    
    songs_display <- pd$songs %>%
      select(
        `#` = song_number,
        `Time Period` = display_start,
        `CO₂ (ppm)` = avg_co2,
        `BPM` = bpm,
        `Mood` = mood
      )
    
    datatable(
      songs_display,
      selection = list(mode = 'single', selected = selected_song_index()),
      options = list(
        pageLength = 10,
        dom = 'ftp',
        scrollY = '300px',
        scrollCollapse = TRUE,
        language = list(
          search = "Search:",
          info = "Showing _START_ to _END_ of _TOTAL_ songs"
        )
      ),
      rownames = FALSE,
      class = 'cell-border stripe'
    ) %>%
      formatStyle(
        'BPM',
        backgroundColor = styleInterval(
          c(70, 90, 110, 130),
          c('#1e3a5f', '#2d4a6f', '#3d5a7f', '#5d3a5f', '#7d2a4f')
        ),
        color = 'white'
      )
  })
  
  # Update Spotify/SoundCloud URLs
  observe({
    song <- selected_song()
    if (!is.null(song)) {
      # Extract genre from mood
      genre <- gsub(".*- ", "", song$mood)
      genre <- gsub(" /.*", "", genre)
      
      search_query <- paste(song$bpm, "bpm", genre)
      
      spotify_url <- paste0("https://open.spotify.com/search/", URLencode(search_query))
      soundcloud_url <- paste0("https://soundcloud.com/search?q=", URLencode(search_query))
      
      session$sendCustomMessage("updateLink", list(
        spotify = spotify_url,
        soundcloud = soundcloud_url
      ))
    }
  })
  
  # Download handler
  output$download_playlist <- downloadHandler(
    filename = function() {
      paste0("paleoclimate_playlist_", current_period()$id, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      pd <- playlist_data()
      write_csv(pd$songs %>% select(-bpm_color), file)
    }
  )
}

# Add JavaScript for link updates
js <- '
Shiny.addCustomMessageHandler("updateLink", function(message) {
  document.getElementById("spotify_url").href = message.spotify;
  document.getElementById("soundcloud_url").href = message.soundcloud;
});
'

# Modify UI to include JavaScript
ui <- tagList(
  tags$head(tags$script(HTML(js))),
  ui
)

# -----------------------------------------------------------------------------
# 7. RUN THE APP
# -----------------------------------------------------------------------------

shinyApp(ui = ui, server = server)
