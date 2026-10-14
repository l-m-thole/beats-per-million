# =============================================================================
# SHARING: link previews and "Suggest a song"
# =============================================================================
#
#   social_meta_tags()   <head> tags that give a shared link a title, a short
#                        text and a picture (WhatsApp, Signal, Slack, ...)
#   suggest_song_tag()   the "Suggest a song" link: BPM_SUGGEST_URL if set,
#                        otherwise a pre-filled email to BPM_CONTACT
#   wanted_bpm_*()       tempo ranges where the song library is thin, shown
#                        under "Suggest a song" in About & privacy. The deploy
#                        script works them out with the library check and
#                        writes data/wanted_bpm.csv (git-ignored); the app
#                        only reads that file, so start-up stays fast.
# =============================================================================

APP_TITLE_LONG <- "Beats per Million — Dance While You Can"
APP_BLURB <- paste("Earth's CO₂ history as a playlist: the more CO₂, the faster the music.",
                   "From the end of the dinosaurs to the Keeling Curve today.")

OG_IMAGE     <- "og-image.png"   # www/og-image.png, made by data-raw/make_og_image.R
OG_IMAGE_ALT <- paste("Line chart of atmospheric CO₂ over the last 800,000 years: ice-age",
                      "cycles between about 180 and 300 ppm, then a near-vertical rise to",
                      "over 420 ppm today.")

WANTED_BPM_FILE <- file.path("data", "wanted_bpm.csv")

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

# -----------------------------------------------------------------------------
# Link previews
# -----------------------------------------------------------------------------

#' Address of a file next to the app: absolute when the app's URL is known
.abs_url <- function(base, file) {
  base <- trimws(base %||% "")
  if (!nzchar(base)) return(file)
  paste0(sub("/*$", "/", base), file)
}

#' <head> tags for link previews (Open Graph + Twitter/X card)
#'
#' Crawlers read these from the page's plain HTML, so they belong in the static
#' UI. og:image must be an absolute https:// address, hence `url`: the app's
#' public address (BPM_PUBLIC_URL, written by the deploy script). Without it
#' (locally) the tags are still there, just with a relative image.
#'
#' @param url The app's public address, e.g. "https://beatspermillion.shinyapps.io/dance/"
#' @return tagList of <meta> tags
social_meta_tags <- function(url = "", title = APP_TITLE_LONG, description = APP_BLURB,
                             image = OG_IMAGE, image_alt = OG_IMAGE_ALT,
                             image_size = c(1200, 630)) {
  url <- trimws(url %||% "")
  img <- .abs_url(url, image)
  og  <- function(property, content) tags$meta(property = property, content = content)
  nm  <- function(name, content) tags$meta(name = name, content = content)
  tagList(
    nm("description", description),
    og("og:type", "website"),
    og("og:site_name", "Beats per Million"),
    og("og:title", title),
    og("og:description", description),
    if (nzchar(url)) og("og:url", url),
    og("og:image", img),
    og("og:image:type", "image/png"),
    og("og:image:width", image_size[1]),
    og("og:image:height", image_size[2]),
    og("og:image:alt", image_alt),
    nm("twitter:card", "summary_large_image"),
    nm("twitter:title", title),
    nm("twitter:description", description),
    nm("twitter:image", img),
    nm("twitter:image:alt", image_alt)
  )
}

# -----------------------------------------------------------------------------
# Suggest a song
# -----------------------------------------------------------------------------

#' Where "Suggest a song" points
#'
#' BPM_SUGGEST_URL (e.g. a Google Form) if set; otherwise an email to
#' BPM_CONTACT with a short form in the body; a URL contact is used as it is.
#'
#' @param settings app_settings() (uses suggest_url and contact)
#' @return list(href, external) or NULL when there is nowhere to send it
suggest_song_link <- function(settings) {
  url <- trimws(settings$suggest_url %||% "")
  if (nzchar(url)) return(list(href = url, external = TRUE))
  contact <- trimws(settings$contact %||% "")
  if (grepl("^https?://", contact)) return(list(href = contact, external = TRUE))
  if (!grepl("@", contact)) return(NULL)
  enc <- function(x) utils::URLencode(x, reserved = TRUE)
  subject <- "Song suggestion for Beats per Million"
  body <- "Song:\nArtist:\nLink (Spotify or YouTube):\nTempo in BPM, if you know it:\n"
  list(href = paste0("mailto:", contact, "?subject=", enc(subject), "&body=", enc(body)),
       external = FALSE)
}

#' The "Suggest a song" link as a tag (NULL when there is nowhere to send it)
suggest_song_tag <- function(settings, text = "Suggest a song", ...) {
  lk <- suggest_song_link(settings)
  if (is.null(lk)) return(NULL)
  if (isTRUE(lk$external)) {
    tags$a(href = lk$href, target = "_blank", rel = "noopener", ..., text)
  } else {
    tags$a(href = lk$href, ..., text)
  }
}

# -----------------------------------------------------------------------------
# Tempos that need songs
# -----------------------------------------------------------------------------

#' Which library pool visitors draw from, given the default player
#' (see LIBRARY_POOLS in R/library_check.R; one pool per service, since a
#' playlist never mixes services)
pool_for_player <- function(player) {
  switch(tolower(player %||% ""),
         youtube = "youtube", soundcloud = "soundcloud",
         "spotify")
}

.no_wanted <- function() tibble::tibble(lo = numeric(), hi = numeric(), add = integer())

#' Tempo ranges that need more songs, from library_gaps()
#'
#' Bins with add_at_least > 0 are merged when they touch: 60-64 + 65-69 -> 60-69.
#'
#' @param gaps Output of library_gaps() (bin like "60-64", add_at_least)
#' @param pool Keep only this pool's rows (NULL: gaps is for one pool already)
#' @return tibble(lo, hi, add), slowest range first; add = rough number of
#'   songs to add in that range
wanted_bpm_ranges <- function(gaps, pool = NULL) {
  if (is.null(gaps) || !nrow(gaps)) return(.no_wanted())
  if (!is.null(pool) && "pool" %in% names(gaps)) gaps <- gaps[gaps$pool == pool, , drop = FALSE]
  gaps <- gaps[!is.na(gaps$add_at_least) & gaps$add_at_least > 0, , drop = FALSE]
  if (!nrow(gaps)) return(.no_wanted())

  ends <- strsplit(as.character(gaps$bin), "-", fixed = TRUE)
  lo  <- as.numeric(vapply(ends, `[`, character(1), 1))
  hi  <- as.numeric(vapply(ends, `[`, character(1), 2))
  add <- as.integer(gaps$add_at_least)
  o <- order(lo)
  lo <- lo[o]; hi <- hi[o]; add <- add[o]

  run <- cumsum(c(TRUE, lo[-1] > hi[-length(hi)] + 1))     # new run after a gap
  tibble::tibble(lo  = as.numeric(tapply(lo, run, min)),
                 hi  = as.numeric(tapply(hi, run, max)),
                 add = as.integer(tapply(add, run, sum)))
}

#' "60–69 BPM (slow)" - one label per range
wanted_bpm_labels <- function(ranges) {
  if (is.null(ranges) || !nrow(ranges)) return(character(0))
  mid  <- (ranges$lo + ranges$hi) / 2
  feel <- ifelse(mid < 80, "slow", ifelse(mid < 120, "mid-tempo", "fast"))
  sprintf("%g–%g BPM (%s)", ranges$lo, ranges$hi, feel)
}

#' Save the ranges for the app (called by the deploy script)
#'
#' @param ranges Output of wanted_bpm_ranges()
#' @param pool The pool they were computed for
write_wanted_bpms <- function(ranges, pool, path = WANTED_BPM_FILE) {
  out <- ranges
  out$pool    <- rep(pool, nrow(out))
  out$updated <- rep(format(Sys.Date()), nrow(out))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(out, path)              # header only = nothing missing
  invisible(path)
}

#' Read them back in the app
#'
#' @return tibble(lo, hi, add, ...); zero rows = every tempo is covered;
#'   NULL = not worked out yet (no file) or unreadable - then the app just
#'   doesn't mention tempos
read_wanted_bpms <- function(path = WANTED_BPM_FILE) {
  if (!file.exists(path)) return(NULL)
  x <- tryCatch(suppressWarnings(
    readr::read_csv(path, show_col_types = FALSE,
                    col_types = readr::cols(lo = "d", hi = "d", add = "i", .default = "c"))),
    error = function(e) NULL)
  if (is.null(x) || !all(c("lo", "hi", "add") %in% names(x))) return(NULL)
  x[!is.na(x$lo) & !is.na(x$hi), , drop = FALSE]
}
