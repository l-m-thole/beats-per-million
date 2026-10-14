# =============================================================================
# ABOUT & PRIVACY - text for the in-app "About & privacy" window
# =============================================================================
#
# Opened from the footer link, or directly with ?about in the URL (use that
# address wherever a privacy-policy link is asked for, e.g. the Spotify
# dashboard). Keep it in sync with what the app actually does: if you add
# analytics, a new player, or move to another host, update the privacy part.
# Also here: the "▶ Play via ..." gate in the Listen panel (player_gate()),
# which says the same in two lines before any player loads.
# =============================================================================

#' "November 2024": month of the Modern record's last data point
#'
#' Uses `age` (years before 1950, negative = after 1950; mid-month decimal),
#' because the sheet's `year` column holds whole years only.
modern_data_through <- function(modern) {
  if (is.null(modern) || !"age" %in% names(modern) || !nrow(modern)) return(NULL)
  y <- suppressWarnings(REFERENCE_YEAR - min(modern$age, na.rm = TRUE))
  if (!is.finite(y)) return(NULL)
  m <- min(12, floor((y - floor(y)) * 12) + 1)
  paste(month.name[m], floor(y))
}

# External link; `after` (e.g. ".") is glued to it without a space
.ext <- function(href, text, after = NULL) {
  a <- tags$a(href = href, target = "_blank", rel = "noopener", text,
              .noWS = if (!is.null(after)) "after")
  if (is.null(after)) a else tagList(a, after)
}

# -----------------------------------------------------------------------------
# Players and privacy
# -----------------------------------------------------------------------------
# Who gets what when a visitor presses play. Used by the ▶ Play gate in the
# Listen panel and by About & privacy, so both always say the same.

YOUTUBE_TERMS_URL <- "https://www.youtube.com/t/terms"
GOOGLE_PRIVACY_URL <- "https://policies.google.com/privacy"

PLAYER_PRIVACY <- list(
  spotify    = list(name = "Spotify", who = "Spotify", btn = "btn-spotify",
                    privacy = "https://www.spotify.com/legal/privacy-policy/"),
  youtube    = list(name = "YouTube", who = "Google", btn = "btn-youtube",
                    privacy = GOOGLE_PRIVACY_URL),
  soundcloud = list(name = "SoundCloud", who = "SoundCloud", btn = "btn-soundcloud",
                    privacy = "https://soundcloud.com/pages/privacy")
)

#' The "▶ Play" gate shown in place of a player until the visitor presses it
#'
#' The page itself loads nothing from Spotify, YouTube or SoundCloud. Pressing
#' Play is the visitor's OK to load that service's player, which then gets
#' their IP address and may set cookies; for YouTube it is also the agreement
#' to YouTube's Terms of Service that YouTube's developer policies ask for.
#' www/player.js swaps the gate for the player and remembers the OK per
#' service until the page is reloaded.
#'
#' @param service "spotify", "youtube" or "soundcloud"
#' @return tag
player_gate <- function(service) {
  info <- PLAYER_PRIVACY[[service]]
  if (is.null(info)) return(NULL)
  div(class = "player-gate", `data-service` = service,
      tags$button(type = "button", class = paste("btn gate-play", info$btn),
                  paste0("▶ Play via ", info$name)),
      p(class = "gate-note",
        span(paste0("This loads ", info$name, "'s player: ", info$who,
                    " then gets your IP address and may set cookies ("), .noWS = "after"),
        .ext(info$privacy, paste(info$who, "privacy policy"), after = ")."),
        if (identical(service, "youtube")) {
          tagList("By playing you agree to the",
                  .ext(YOUTUBE_TERMS_URL, "YouTube Terms of Service", after = "."))
        },
        actionLink("about_gate", "More in About & privacy", .noWS = "after"), "."))
}

#' "Suggest a song": the link, plus the tempos the library is short of
#'
#' @param settings app_settings()
#' @param wanted read_wanted_bpms(): NULL = unknown (tempos not mentioned),
#'   zero rows = every tempo covered
#' @return tagList, or NULL when there is nowhere to send a suggestion
suggest_section <- function(settings, wanted = NULL) {
  link <- suggest_song_tag(settings, "✉️ Suggest a song")
  if (is.null(link)) return(NULL)
  need <- wanted_bpm_labels(wanted)
  tagList(
    tags$h4("Suggest a song"),
    p("Know a song that would fit? Send us the title, the artist and a Spotify or",
      "YouTube link (and its tempo, if you know it).",
      if (length(need)) {
        tagList("Right now we're short of songs at", tags$b(paste(need, collapse = ", "),
                                                           .noWS = "after"), ".")
      } else if (!is.null(wanted)) {
        "Every tempo is covered right now, but more choice always helps."
      }),
    p(link)
  )
}

#' Contents of the About & privacy window
#'
#' @param settings app_settings()
#' @param co2_data CO2 data list (for the Modern record's end date), optional
#' @param wanted Tempos that need songs (read_wanted_bpms()), optional
#' @return tagList
about_content <- function(settings = app_settings(), co2_data = NULL, wanted = NULL) {
  through <- modern_data_through(co2_data$modern)
  contact <- trimws(settings$contact %||% "")
  contact_href <- if (grepl("@", contact) && !grepl("^https?://", contact)) {
    paste0("mailto:", contact)
  } else contact

  tagList(
    tags$h4("What is this?"),
    p("Beats per Million turns atmospheric CO₂ through Earth's history into tempo:",
      "the more CO₂, the faster the music. Pick an era, press play and listen to",
      "the climate speed up or slow down – from the end of the dinosaurs to the",
      "Keeling Curve today."),
    p("How CO₂ becomes tempo, how the songs are picked and how the CO₂ was measured:",
      "see", tags$b("How it works", .noWS = "after"), " at the top of the app, and",
      tags$b("About this era", .noWS = "after"), " on the CO₂ plot."),

    tags$h4("Data"),
    tags$ul(
      tags$li(tags$b(paste0("Modern (1958–", through %||% "today", "):")),
              "monthly mean CO₂ at Mauna Loa from the NOAA Global Monitoring Laboratory",
              "(Xin Lan, NOAA/GML,", .ext("https://gml.noaa.gov/ccgg/trends/",
                                           "gml.noaa.gov/ccgg/trends", after = ");"),
              "data from 1958 to 1974 by C. D. Keeling, Scripps Institution of Oceanography."),
      tags$li(tags$b("Ice cores (0–800,000 years):"),
              "Bereiter, B. et al. (2015) Revision of the EPICA Dome C CO₂ record from 800 to",
              "600 kyr before present.", tags$i("Geophysical Research Letters"), "42, 542–549.",
              .ext("https://doi.org/10.1002/2014GL061957", "doi:10.1002/2014GL061957")),
      tags$li(tags$b("Cenozoic (0–66 million years):"),
              "Rae, J. W. B. et al. (2021) Atmospheric CO₂ over the past 66 million years from",
              "marine archives.", tags$i("Annual Review of Earth and Planetary Sciences"),
              "49, 609–641.",
              .ext("https://doi.org/10.1146/annurev-earth-082420-063026",
                   "doi:10.1146/annurev-earth-082420-063026"))
    ),

    tags$h4("Music"),
    p("Songs are picked by us and played through the official embedded players of",
      "Spotify, YouTube and SoundCloud – one service per playlist, the one you pick",
      "under", tags$i("Play via", .noWS = "after"), ". We only link to official uploads",
      "where we can. This site doesn't host or change any audio; all rights stay with",
      "the artists and labels. Album covers come from Spotify. Song tempos (BPM) partly from",
      .ext("https://getsongbpm.com", "GetSongBPM", after = ".")),
    p("Without a login, Spotify plays 30-second previews and YouTube plays whole songs.",
      "Whole songs inside the app via Spotify need Spotify Premium and, while the app",
      "is in beta, an invitation: Spotify only allows a handful of test accounts for",
      "apps like this one."),

    suggest_section(settings, wanted),

    tags$h4("Privacy"),
    tags$ul(
      tags$li("The app itself uses no analytics and no tracking cookies, and keeps no",
              "record of who you are. Its fonts come from this site too."),
      tags$li("Nothing from Spotify, YouTube (Google) or SoundCloud loads until you press",
              tags$b("▶ Play", .noWS = "after"), ". Then that service's player loads: the",
              "service gets your IP address and may set its own cookies under its own",
              "policy –",
              .ext(PLAYER_PRIVACY$spotify$privacy, "Spotify"), "·",
              .ext(GOOGLE_PRIVACY_URL, "Google/YouTube"), "·",
              .ext(PLAYER_PRIVACY$soundcloud$privacy, "SoundCloud", after = "."),
              "Album covers (if you switch them on) load from Spotify the same way.",
              "Your OK lasts until you reload the page. To block these cookies, use your",
              "browser's settings for third-party cookies."),
      tags$li("Playing via YouTube uses the YouTube API Services: by playing YouTube videos",
              "here you agree to the",
              .ext(YOUTUBE_TERMS_URL, "YouTube Terms of Service", after = ","),
              "and Google's", .ext(GOOGLE_PRIVACY_URL, "privacy policy"), "applies."),
      tags$li("If you connect Spotify (invited testers), the app receives a temporary",
              "access token from Spotify. It is kept in memory for your browser session only,",
              "never written to disk, and only used to play songs in this tab and, if you",
              "click Save to Spotify, to create a private playlist in your account.",
              "Disconnect or close the tab to end it; you can also remove the app's access at",
              .ext("https://www.spotify.com/account/apps/", "spotify.com/account/apps", after = ".")),
      tags$li("The site is hosted on shinyapps.io (Posit PBC), which processes technical",
              "data such as IP addresses to deliver the page:",
              .ext("https://posit.co/about/privacy-policy/", "Posit privacy policy", after = ".")),
      tags$li("Questions about your data, or want something deleted (e.g. a song suggestion",
              "you emailed)? Write to us – see below. You can also complain to the Swedish",
              "Authority for Privacy Protection,",
              .ext("https://www.imy.se/en/", "IMY", after = "."))
    ),

    tags$h4("Who made this"),
    p("A collaboration between Martin Wegmann and Lena Thöle. Code under the MIT license.",
      if (nzchar(contact)) {
        tagList("Questions or requests:",
                tags$a(href = contact_href, target = "_blank", contact, .noWS = "after"), ".")
      })
  )
}

#' Show the About & privacy window
show_about <- function(settings = app_settings(), co2_data = NULL, wanted = NULL) {
  showModal(modalDialog(
    title = "About & privacy",
    about_content(settings, co2_data, wanted),
    size = "l", easyClose = TRUE, footer = modalButton("Close")
  ))
}
