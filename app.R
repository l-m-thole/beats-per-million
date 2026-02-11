# =============================================================================
# CLIMATE PLAYLISTS - SHINY APPLICATION
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
#   install.packages(c("shiny", "readxl", "tidyverse", "plotly", "DT", "writexl"))
#
# =============================================================================

# -----------------------------------------------------------------------------
# LOAD PACKAGES
# -----------------------------------------------------------------------------

library(shiny)
library(readxl)
library(tidyverse)
library(plotly)
library(DT)
library(writexl)

# -----------------------------------------------------------------------------
# SOURCE SHARED MODULES
# -----------------------------------------------------------------------------

source("R/config.R")
source("R/functions.R")
source("R/load_data.R")

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

CO2_DATA <- load_co2_data("data")

# Pre-generate all playlists for faster switching
ALL_PLAYLISTS <- generate_all_playlists(CO2_DATA)

# -----------------------------------------------------------------------------
# USER INTERFACE
# -----------------------------------------------------------------------------

ui <- fluidPage(
  
  # Custom CSS
  tags$head(
    tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=JetBrains+Mono:wght@300;400;500&family=DM+Sans:wght@400;500;600&display=swap"),
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
    # Inline styles as fallback
    tags$style(HTML(app_css()))
  ),
  
  # JavaScript for Spotify/SoundCloud links
  tags$head(tags$script(HTML('
    Shiny.addCustomMessageHandler("updateSearchLinks", function(data) {
      var spotifyUrl = "https://open.spotify.com/search/" + encodeURIComponent(data.query);
      var soundcloudUrl = "https://soundcloud.com/search?q=" + encodeURIComponent(data.query);
      document.getElementById("spotify_link").href = spotifyUrl;
      document.getElementById("soundcloud_link").href = soundcloudUrl;
    });
  '))),
  
  # Header
  div(class = "main-header",
      h1(class = "main-title", "🌍 Climate Playlists"),
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
                        h3(class = "card-title", "Find Music"),
                        p(class = "description-text", 
                          "Search for songs matching the selected BPM:"),
                        div(class = "button-row",
                            tags$a(id = "spotify_link", href = "#", target = "_blank",
                                   class = "btn btn-spotify", "🎵 Spotify"),
                            tags$a(id = "soundcloud_link", href = "#", target = "_blank",
                                   class = "btn btn-soundcloud", "☁️ SoundCloud")
                        )
                    )
             ),
             
             column(7,
                    div(class = "card",
                        div(class = "playlist-header",
                            h3(class = "card-title", "Playlist"),
                            downloadButton("download_csv", "📥 CSV",
                                           class = "btn-download")
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
      p("A collaboration between Martin Wegmann and Lena Thöle")
  )
)

# -----------------------------------------------------------------------------
# SERVER LOGIC
# -----------------------------------------------------------------------------

server <- function(input, output, session) {
  
  # Get current playlist (pre-computed)
  current_playlist <- reactive({
    ALL_PLAYLISTS[[input$selected_period]]
  })
  
  # Get current period config
  current_period <- reactive({
    TIME_PERIODS[[input$selected_period]]
  })
  
  # Selected song index
  selected_idx <- reactiveVal(1)
  
  # Reset selection when period changes
  observeEvent(input$selected_period, {
    selected_idx(1)
  })
  
  # Update selection from table click
  observeEvent(input$playlist_table_rows_selected, {
    if (length(input$playlist_table_rows_selected) > 0) {
      selected_idx(input$playlist_table_rows_selected[1])
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
  
  # Update search links when song changes
  observe({
    song <- selected_song()
    if (!is.null(song)) {
      query <- paste(song$bpm, "bpm", gsub(" –.*", "", song$mood))
      session$sendCustomMessage("updateSearchLinks", list(query = query))
    }
  })
  
  # ----- OUTPUTS -----
  
  # Period description
  output$period_description <- renderUI({
    p(class = "description-text", current_period()$description)
  })
  
  # How it works - dynamic based on playlist
  output$how_it_works <- renderUI({
    s <- current_playlist()$stats
    p(class = "description-text",
      "CO₂ concentrations are mapped to beats per minute (BPM):",
      tags$br(), tags$br(),
      paste0("• Low CO₂ (", s$co2_min, " ppm) → ", BPM_MIN, " BPM (slow, ambient)"),
      tags$br(),
      paste0("• High CO₂ (", s$co2_max, " ppm) → ", BPM_MAX, " BPM (fast, intense)")
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
    is_modern <- (period$data_source == DATA_SOURCE_MODERN)
    
    if (is_modern) {
      # Modern: convert negative ages to CE years
      data <- data %>% mutate(x_val = REFERENCE_YEAR - age)
      x_title <- "Year (CE)"
      x_reversed <- FALSE
    } else if (period$data_source == DATA_SOURCE_CENOZOIC) {
      data <- data %>% mutate(x_val = age / 1e6)
      x_title <- "Age (millions of years ago)"
      x_reversed <- TRUE
    } else {
      data <- data %>% mutate(x_val = age / 1000)
      x_title <- "Age (thousands of years ago)"
      x_reversed <- TRUE
    }
    
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
    
    # Add marker for selected song
    song <- selected_song()
    if (!is.null(song)) {
      mid_age <- (song$start_age + song$end_age) / 2
      
      if (is_modern) {
        marker_x <- REFERENCE_YEAR - mid_age
      } else if (period$data_source == DATA_SOURCE_CENOZOIC) {
        marker_x <- mid_age / 1e6
      } else {
        marker_x <- mid_age / 1000
      }
      
      p <- p %>%
        add_trace(
          x = marker_x,
          y = song$avg_co2,
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
      div(class = "now-playing-bpm",
          span(class = "bpm-large", style = paste0("color:", song$bpm_color), song$bpm),
          span(class = "bpm-label", "BPM")
      ),
      div(class = "mood-tag", song$mood)
    )
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
    
    datatable(
      display_df,
      selection = list(mode = "single", selected = selected_idx()),
      options = list(
        pageLength = 10,
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

shinyApp(ui = ui, server = server)
