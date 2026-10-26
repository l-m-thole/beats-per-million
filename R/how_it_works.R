# =============================================================================
# HOW IT WORKS + ABOUT THIS ERA - text for the two info windows
# =============================================================================
#
# "How it works" (button at the top of the app): the idea, how an era becomes
# a playlist, how songs are chosen and shuffled, where the CO2 numbers come
# from, how the app came about and who made it.
# "About this era" (button on the CO2 plot): the selected era's background,
# key events and how its CO2 was measured.
#
# APP_STORY and APP_MAKERS below are plain text - edit freely. Each element is
# shown as its own paragraph.
#
# Needs config.R, functions.R (TEMPO_FEELS) and period_context.R; shiny tags.
# =============================================================================

# ---- EDIT ME: how the app came about ------------------------------------------
APP_STORY <- c(
  "Beats per Million started as a small R script called Climate Playlists. It cut CO₂ records into song-length slices, turned each slice's CO₂ into a target tempo and wrote out playlist templates, which we then filled with songs by hand.",
  "Then it grew into this app. Songs placed by hand into fixed slots kept breaking whenever new data shifted the slices, so we built a song library instead: songs we like, each tagged with its real tempo (looked up on tunebat, songbpm and GetSongBPM) and matched to the slices automatically.",
  "Next came players inside the app (Spotify, YouTube, SoundCloud), a ball that rides along the CO₂ curve while you listen, the background and key events of each era, and a monthly update of the Mauna Loa data.",
  "The idea behind it: CO₂ numbers are easy to scroll past. Hearing the tempo creep up over millions of years – and then race in the last few decades – is harder to ignore."
)

# ---- EDIT ME: who made this ---------------------------------------------------
APP_MAKERS <- c(
  "Beats per Million is a collaboration between Martin Wegmann and Lena Thöle.",
  "Lena is the data steward at the Swedish Museum of Natural History, working on more open scientific data output. Her background is in paleoclimate research – she used to reconstruct past environments in the Southern Ocean and is still today in love with climate sciences.",
  "Martin's background is in climate sciences as well - that's how the two know each other. These days he is a systems engineer at ETH Zurich, trying to build up a digital data store for climate and atmospheric research data."
)

# ---- EDIT ME: ORCID iDs -------------------------------------------------------
APP_ORCIDS <- c(
  "Lena Thöle"     = "0000-0002-5405-3613",
  "Martin Wegmann" = "0000-0002-5294-2978"
  )
  
# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------

# "3 years", "60 years", "9,000 years", "750,000 years"
.years_txt <- function(x) {
  paste(format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE),
        if (round(x) == 1) "year" else "years")
}

#' Years of CO2 record per song, for every era (used in "How it works")
#'
#' @return data.frame(id, name, years_per_song)
years_per_song_table <- function() {
  data.frame(
    id   = names(TIME_PERIODS),
    name = vapply(TIME_PERIODS, function(p) p$short_name %||% p$name, character(1)),
    years_per_song = vapply(TIME_PERIODS, function(p) p$years_per_minute * AVG_SONG_LENGTH,
                            numeric(1)),
    stringsAsFactors = FALSE, row.names = NULL
  )
}

# "Glacial (under 70 BPM), Slow (70–84), ..., Intense (145 and faster)"
.feel_bands_txt <- function() {
  f <- TEMPO_FEELS
  lab <- ifelse(is.na(f$from), paste0("under ", f$to + 1, " BPM"),
         ifelse(is.na(f$to), paste0(f$from, "+"), paste0(f$from, "–", f$to)))
  paste0(f$feel, " (", lab, ")", collapse = ", ")
}

# "If none is left, it tries ±5, then ±10 BPM, then simply takes the closest song."
.widening_txt <- function(tols = MATCH_TOLS) {
  wider <- tols[-1]
  if (!length(wider)) return("If none is left, it simply takes the closest song.")
  paste0("If none is left, it tries ", paste0("±", wider, collapse = ", then "),
         " BPM, then simply takes the closest song.")
}

.ext_link <- function(href, text) tags$a(href = href, target = "_blank", rel = "noopener", text)

# -----------------------------------------------------------------------------
# HOW IT WORKS
# -----------------------------------------------------------------------------

#' Contents of the "How it works" window
#'
#' @param period_id Era the visitor is looking at (for the "In this era" box);
#'   NULL to leave the box out
#' @param stats That era's playlist stats (generate_playlist()$stats)
#' @param scaling "per_period" or "global" (the scale in use)
#' @param global_range c(min, max) CO2 of the global scale, optional
#' @param n_library Number of songs in the library, optional
#' @return tagList
how_it_works_content <- function(period_id = NULL, stats = NULL, scaling = "per_period",
                                 global_range = NULL, n_library = NULL) {
  yps <- years_per_song_table()
  first <- yps[1, ]; last <- yps[nrow(yps), ]
  glob <- if (length(global_range) == 2) {
    sprintf(" (%s–%s ppm)", format(round(global_range[1]), big.mark = ","),
            format(round(global_range[2]), big.mark = ","))
  } else ""

  era_box <- if (!is.null(period_id) && !is.null(stats) && !is.null(TIME_PERIODS[[period_id]])) {
    per <- TIME_PERIODS[[period_id]]
    div(class = "info-box",
        tags$b(paste0("In the era you have open (", per$short_name %||% per$name, "):")),
        sprintf(" %d songs, each standing for about %s of CO₂ record. ",
                as.integer(stats$num_songs), .years_txt(per$years_per_minute * AVG_SONG_LENGTH)),
        sprintf("%s ppm becomes %d BPM and %s ppm becomes %d BPM",
                format(stats$scale_min, big.mark = ","), BPM_MIN,
                format(stats$scale_max, big.mark = ","), BPM_MAX),
        if (identical(scaling, "global")) " (global scale)." else " (per-era scale).")
  }

  n_lib_txt <- if (!is.null(n_library) && n_library > 0) {
    paste0("our library of ", n_library, " hand-picked songs")
  } else "our library of hand-picked songs"

  tagList(
    tags$h4("The idea"),
    p("Beats per Million turns the CO₂ in Earth's atmosphere into tempo: the more",
      "CO₂, the faster the beat. Pick an era, press play and hear the climate speed",
      "up or slow down – from the end of the dinosaurs to the Keeling Curve today."),

    tags$h4("From an era to a playlist"),
    tags$ol(class = "steps",
      tags$li(tags$b("Slices of time."),
              "Each era's CO₂ record is cut into equal slices, one per song. A song",
              "stands for about", AVG_SONG_LENGTH, "minutes of music, so a slice covers",
              .years_txt(first$years_per_song), "in the", first$name, "and",
              .years_txt(last$years_per_song), "in the", paste0(last$name, ".")),
      tags$li(tags$b("CO₂ becomes tempo."),
              "The average CO₂ of each slice is turned into beats per minute along a",
              sprintf("straight line from %d to %d BPM.", BPM_MIN, BPM_MAX),
              tags$b("Per era:"), "the era's lowest CO₂ becomes", BPM_MIN, "BPM and its",
              "highest", BPM_MAX, "BPM – the most contrast.",
              tags$b("Global:"), paste0("one scale for all eras", glob, ","),
              "so tempos can be compared between eras. Switch between them with",
              tags$i("BPM scale"), "in the playlist."),
      tags$li(tags$b("A song for each slice."),
              "From", paste0(n_lib_txt, ","), "each tagged with its real tempo, the app",
              sprintf("takes the songs within ±%g BPM of the slice's tempo and picks one",
                      MATCH_TOLS[1]),
              "of them at random.", .widening_txt(),
              "A song is never used twice in the same playlist. The table",
              "shows the slice's tempo (", tags$i("BPM", .noWS = "outside"), ") next to the",
              "song's own (", tags$i("Song BPM", .noWS = "outside"), "), and the Listen",
              "panel says how the current song was picked."),
      tags$li(tags$b("\U0001F500 Shuffle songs"),
              "re-draws those random picks: other songs, same tempos. The order never",
              "changes – a playlist always runs from the oldest slice to the youngest,",
              "so you hear time moving forward."),
      tags$li(tags$b("Feel"), "describes the tempo, not the song:",
              paste0(.feel_bands_txt(), "."),
              "A rap song at 66 BPM is “Glacial” too.")
    ),
    era_box,

    tags$h4("Where the CO₂ numbers come from"),
    tags$ul(
      tags$li(tags$b("Modern Era:"), "measured directly in the air at Mauna Loa, Hawaii,",
              "since 1958 (monthly values, NOAA)."),
      tags$li(tags$b("Industrial Era:"), "the global-mean CO₂ history the CMIP7 climate",
              "models are run with – Antarctic ice and firn air before ~1958, direct",
              "measurements after – with Mauna Loa for the latest years (yearly values)."),
      tags$li(tags$b("Roman Empire to Full Ice Core:"), "air bubbles trapped in Antarctic",
              "ice cores – each sample holds a few decades to a few centuries of air",
              "(Bereiter et al. 2015)."),
      tags$li(tags$b("Cenozoic:"), "no ice is that old, so CO₂ is worked out from chemical",
              "fingerprints in deep-sea sediments: boron isotopes in plankton shells and",
              "alkenones from algae (Rae et al. 2021), averaged into 100,000-year steps.")
    ),
    p(class = "muted", "More on each method under", tags$i("About this era", .noWS = "after"),
      ". Caveats: per-era scaling exaggerates small changes (switch to Global to hear how",
      "flat the Roman era really was); the Cenozoic averages smooth out short events such",
      "as the PETM; and song databases sometimes list half or double the real tempo."),

    tags$h4("How this app came about"),
    lapply(APP_STORY, p),

    tags$h4("Who made this"),
    lapply(APP_MAKERS, p),
    lapply(names(APP_ORCIDS), function(nm) {
      url <- paste0("https://orcid.org/", APP_ORCIDS[[nm]])
      p(class = "muted", paste0(nm, ":"),
        tags$a(href = url, target = "_blank", rel = "noopener", url))
    })
  )
}

#' Show the "How it works" window
show_how_it_works <- function(...) {
  showModal(modalDialog(
    title = "How it works",
    how_it_works_content(...),
    size = "l", easyClose = TRUE, footer = modalButton("Close")
  ))
}

# -----------------------------------------------------------------------------
# ABOUT THIS ERA
# -----------------------------------------------------------------------------

#' The "How the CO2 was measured" box for one era
#'
#' @param period_id Period id
#' @return div, or NULL for an unknown period
measurement_box <- function(period_id) {
  m <- period_measurement(period_id)
  if (is.null(m)) return(NULL)
  div(class = "measure-box",
      div(class = "measure-kicker", "How the CO₂ was measured"),
      tags$h5(m$title),
      lapply(m$how, p),
      if (!is.null(m$note)) p(tags$b("In this era: "), m$note),
      p(class = "measure-source",
        tags$b("Resolution:"), paste0(m$resolution, "."), " ",
        tags$b("Data:"), m$source, "–", .ext_link(m$url, "source"))
  )
}

#' Contents of the "About this era" window
#'
#' @param period_id Period id
#' @param stats The era's playlist stats (generate_playlist()$stats), optional
#' @return tagList
era_info_content <- function(period_id, stats = NULL) {
  per <- TIME_PERIODS[[period_id]]
  if (is.null(per)) return(tagList())
  ctx <- period_context_text(period_id)
  ev  <- period_key_events(period_id)

  chips <- if (!is.null(stats)) {
    div(class = "era-stats",
        span(class = "stat-chip", tags$b(class = "gold",
             format(stats$years_span, big.mark = ",", scientific = FALSE)), "years"),
        span(class = "stat-chip", tags$b(class = "purple", stats$num_songs), "songs"),
        span(class = "stat-chip", "1 song ≈",
             tags$b(.years_txt(per$years_per_minute * AVG_SONG_LENGTH))),
        span(class = "stat-chip", "CO₂", tags$b(class = "cold", stats$co2_min), "–",
             tags$b(class = "warm", stats$co2_max), "ppm"))
  }

  tagList(
    p(class = "era-lead", per$description),
    chips,
    measurement_box(period_id),
    div(class = "era-grid",
        div(class = "era-story",
            tags$h4("The story"),
            lapply(ctx, p)),
        if (nrow(ev)) {
          div(class = "era-events",
              tags$h4("Key events (oldest → youngest)"),
              tags$ul(class = "event-list",
                      lapply(seq_len(nrow(ev)), function(i) {
                        tags$li(span(class = "event-when", ev$when[i]),
                                span(class = "event-name", ev$title[i]), " – ", ev$detail[i])
                      })))
        })
  )
}

#' Show the "About this era" window
show_era_info <- function(period_id, stats = NULL) {
  per <- TIME_PERIODS[[period_id]]
  showModal(modalDialog(
    title = per$name %||% "About this era",
    era_info_content(period_id, stats),
    size = "l", easyClose = TRUE, footer = modalButton("Close")
  ))
}
