# =============================================================================
# SONG LIBRARY CHECK - is the library good enough to launch?
# =============================================================================
#
#   check_song_library()  rows with problems: missing BPM or links, broken
#                         links, BPM outside 60-150, duplicates, blocked videos
#   check_song_links()    online: does each link still work, may it be embedded,
#                         is it the right song? (free oEmbed endpoints, no keys)
#   library_coverage()    does every playlist slot get a song close to its BPM,
#                         with enough choice for Shuffle? Uses the app's own
#                         matcher (assign_songs_to_playlist), all periods, both
#                         scaling modes.
#   library_gaps()        which BPM ranges need more songs
#   library_verdict()     ready / not ready, criterion by criterion
#
# Run everything with:  source("data-raw/check_song_library.R")
# Needs: config.R, functions.R (and load_data.R for reading the files).
# =============================================================================

LIBRARY_COLS <- c("song_title", "artist", "spotify_uri", "soundcloud_url",
                  "youtube_url", "bpm", "notes")

# Pools of songs the app draws from, depending on how a visitor listens
LIBRARY_POOLS <- c(
  spotify = "Play via Spotify: songs with a Spotify link (30-s clips, or whole songs for connected testers)",
  youtube = "Play via YouTube/SoundCloud: whole songs without any login",
  all     = "Everything playable (Spotify connected + YouTube + SoundCloud)"
)

.blank <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))

# lower case, no punctuation/brackets, single spaces: for duplicate detection
.lib_norm <- function(x) {
  x <- tolower(as.character(x))
  x[is.na(x)] <- ""
  x <- gsub("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]", "", x, perl = TRUE)   # "(Remastered)"
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[^[:alnum:] ]", " ", x)
  trimws(gsub("\\s+", " ", x))
}

#' Read the song library exactly as typed (every column as text)
#'
#' Unlike load_song_library() this keeps a non-numeric bpm visible, so it can be
#' reported. Missing columns are added as blank.
read_library_raw <- function(path = "data/song_library.csv") {
  df <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                        na = character(), trim_ws = TRUE, show_col_types = FALSE)
  for (col in LIBRARY_COLS) if (!col %in% names(df)) df[[col]] <- ""
  df
}

#' Video ids listed in data/youtube_blocked.csv (can't be embedded)
read_blocked_youtube <- function(path = "data/youtube_blocked.csv") {
  if (!file.exists(path)) return(character(0))
  ids <- tryCatch(utils::read.csv(path, colClasses = "character")$video_id,
                  error = function(e) character(0))
  unique(ids[!is.na(ids) & nzchar(ids)])
}

# -----------------------------------------------------------------------------
# 1. ROW CHECKS (offline)
# -----------------------------------------------------------------------------

#' Find rows that need fixing
#'
#' @param lib Library as text (read_library_raw()) or as loaded by
#'   load_song_library(); bpm may be text or numeric.
#' @param bpm_range The app's tempo range (BPM_MIN, BPM_MAX).
#' @param blocked_youtube YouTube ids known not to play in the app.
#' @return Tibble: line (CSV line, header = 1), song_title, artist, severity
#'   (error / warning / info), issue, detail. Errors first.
check_song_library <- function(lib, bpm_range = c(BPM_MIN, BPM_MAX),
                               blocked_youtube = character(0)) {
  for (col in LIBRARY_COLS) if (!col %in% names(lib)) lib[[col]] <- NA_character_
  n <- nrow(lib)
  out <- list()
  add <- function(i, severity, issue, detail) {
    if (!length(i)) return(invisible())
    out[[length(out) + 1]] <<- tibble::tibble(
      line = i + 1L, song_title = as.character(lib$song_title[i]),
      artist = as.character(lib$artist[i]),
      severity = severity, issue = issue, detail = detail)
  }
  if (n == 0) {
    return(tibble::tibble(line = integer(), song_title = character(), artist = character(),
                          severity = character(), issue = character(), detail = character()))
  }

  # --- titles, artists ---
  add(which(.blank(lib$song_title)), "error", "missing_title",
      "No song_title.")
  add(which(.blank(lib$artist) & !.blank(lib$song_title)), "warning", "missing_artist",
      "No artist (needed for the link/BPM lookups and to tell songs apart).")

  # --- BPM ---
  bpm_txt <- trimws(as.character(lib$bpm))
  bpm_txt[is.na(bpm_txt)] <- ""
  bpm <- suppressWarnings(as.numeric(bpm_txt))
  add(which(!nzchar(bpm_txt)), "error", "missing_bpm",
      "No bpm: the song is never matched. Fill it by hand or with the enrichment.")
  bad_num <- which(nzchar(bpm_txt) & is.na(bpm))
  add(bad_num, "error", "bpm_not_a_number",
      paste0("bpm '", bpm_txt[bad_num], "' is not a number."))
  out_rng <- which(!is.na(bpm) & (bpm < bpm_range[1] | bpm > bpm_range[2]))
  if (length(out_rng)) {
    alt <- ifelse(bpm[out_rng] > bpm_range[2], bpm[out_rng] / 2, bpm[out_rng] * 2)
    hint <- ifelse(alt >= bpm_range[1] & alt <= bpm_range[2],
                   paste0(" Half/double time would be ", alt, " BPM - is that the felt tempo?"), "")
    add(out_rng, "warning", "bpm_out_of_range",
        paste0(bpm[out_rng], " BPM is outside ", bpm_range[1], "-", bpm_range[2],
               ": only used as a last-resort 'nearest' match.", hint))
  }

  # --- links ---
  sp_id <- vapply(lib$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
  yt_id <- vapply(lib$youtube_url, parse_youtube_id, character(1), USE.NAMES = FALSE)
  sc_ok <- !.blank(lib$soundcloud_url) &
    grepl("^https?://(www\\.|m\\.|on\\.)?soundcloud\\.com/", trimws(lib$soundcloud_url))

  bad_sp <- which(!.blank(lib$spotify_uri) & is.na(sp_id))
  add(bad_sp, "error", "bad_spotify_link",
      "spotify_uri is not a Spotify TRACK link (album/playlist links don't work).")
  odd_sp <- which(!is.na(sp_id) & nchar(sp_id) != 22)
  add(odd_sp, "warning", "odd_spotify_id",
      "Spotify track ids are 22 characters - check the link.")
  add(which(!.blank(lib$youtube_url) & is.na(yt_id)), "error", "bad_youtube_link",
      "youtube_url is not a YouTube video link.")
  add(which(!.blank(lib$soundcloud_url) & !sc_ok), "warning", "bad_soundcloud_link",
      "soundcloud_url should start with https://soundcloud.com/")
  add(which(.blank(lib$spotify_uri) & .blank(lib$youtube_url) & .blank(lib$soundcloud_url)),
      "error", "no_link",
      "No Spotify, YouTube or SoundCloud link: the song can't be played, so it's never matched.")
  blocked <- which(!is.na(yt_id) & yt_id %in% blocked_youtube)
  add(blocked, "warning", "youtube_blocked",
      "This YouTube video can't be played on other sites (data/youtube_blocked.csv). Try another upload, e.g. the artist's '- Topic' channel.")

  # --- duplicates ---
  dup_rows <- function(key, ok) {
    key[!ok] <- NA
    groups <- split(seq_len(n), key)
    groups[lengths(groups) > 1]
  }
  others <- function(g, i) paste0("line ", setdiff(g, i) + 1L, collapse = ", ")

  song_key <- paste(.lib_norm(lib$song_title), .lib_norm(lib$artist), sep = " | ")
  for (g in dup_rows(song_key, !.blank(lib$song_title))) {
    for (i in g) add(i, "warning", "duplicate_song",
                     paste0("Same song as ", others(g, i), "."))
  }
  title_key <- trimws(as.character(lib$song_title))
  for (g in dup_rows(title_key, !.blank(lib$song_title))) {
    if (length(unique(song_key[g])) == 1) next          # already a duplicate_song
    for (i in g) add(i, "info", "same_title",
                     paste0("Same title as ", others(g, i),
                            " (different artist). The matcher never repeats a title in a playlist, so only one of them can appear."))
  }
  for (g in dup_rows(sp_id, !is.na(sp_id))) {
    for (i in g) add(i, "warning", "duplicate_spotify",
                     paste0("Same Spotify track as ", others(g, i), "."))
  }
  for (g in dup_rows(yt_id, !is.na(yt_id))) {
    for (i in g) add(i, "warning", "duplicate_youtube",
                     paste0("Same YouTube video as ", others(g, i), "."))
  }

  if (!length(out)) {
    return(tibble::tibble(line = integer(), song_title = character(), artist = character(),
                          severity = character(), issue = character(), detail = character()))
  }
  res <- dplyr::bind_rows(out)
  res$severity <- factor(res$severity, levels = c("error", "warning", "info"))
  res <- res[order(res$severity, res$line), , drop = FALSE]
  res$severity <- as.character(res$severity)
  res
}

# -----------------------------------------------------------------------------
# 2. LINK CHECKS (online, no API keys)
# -----------------------------------------------------------------------------

#' Ask a service's public oEmbed endpoint about one link
#'
#' @return list(status = HTTP status or NA, title = what the service calls it)
oembed_fetch <- function(service, link) {
  endpoint <- switch(service,
    spotify    = "https://open.spotify.com/oembed",
    youtube    = "https://www.youtube.com/oembed",
    soundcloud = "https://soundcloud.com/oembed")
  resp <- tryCatch(
    httr2::request(endpoint) |>
      httr2::req_url_query(url = link, format = "json") |>
      httr2::req_user_agent("Beats per Million library check (R/httr2)") |>
      httr2::req_timeout(15) |>
      httr2::req_retry(max_tries = 3) |>
      httr2::req_throttle(rate = 4, realm = service) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(),
    error = function(e) e)
  if (inherits(resp, "error")) {
    return(list(status = NA_integer_, title = NA_character_,
                error = conditionMessage(resp)))
  }
  status <- httr2::resp_status(resp)
  title <- if (status == 200) {
    tryCatch(httr2::resp_body_json(resp)$title %||% NA_character_,
             error = function(e) NA_character_)
  } else NA_character_
  list(status = status, title = title)
}

# What an oEmbed status means for the app
.link_meaning <- function(service, status) {
  if (is.na(status)) return("could not reach the service (network) - try again")
  if (status == 200) return("ok")
  if (service == "youtube" && status == 401)
    return("the owner doesn't allow playing it on other websites - find another upload")
  if (status == 403) return("private or not allowed to be embedded")
  if (status %in% c(400, 404)) return("not found: removed, private or a wrong link")
  paste("unexpected answer, HTTP", status)
}

#' Check every link in the library online
#'
#' Spotify, YouTube and SoundCloud all answer public oEmbed requests without
#' keys. Besides "does it exist", YouTube says whether embedding is allowed,
#' and the returned title lets us spot links that point at the wrong song.
#' Throttled to 4 requests/second per service: ~1-2 minutes for 250 songs.
#'
#' @param lib Library (read_library_raw() or load_song_library())
#' @param services Any of "spotify", "youtube", "soundcloud"
#' @param fetch function(service, link) -> list(status, title); swap in a fake
#'   for tests
#' @param progress Print a progress line per service
#' @return Tibble: line, song_title, artist, service, link, status, ok,
#'   found_title, title_match, detail. ok is NA when the service couldn't be
#'   reached.
check_song_links <- function(lib, services = c("spotify", "youtube", "soundcloud"),
                             fetch = oembed_fetch, progress = interactive()) {
  services <- match.arg(services, several.ok = TRUE)
  for (col in LIBRARY_COLS) if (!col %in% names(lib)) lib[[col]] <- NA_character_
  jobs <- list()
  if ("spotify" %in% services) {
    id <- vapply(lib$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
    i <- which(!is.na(id))
    jobs$spotify <- data.frame(i = i, link = paste0("https://open.spotify.com/track/", id[i]))
  }
  if ("youtube" %in% services) {
    id <- vapply(lib$youtube_url, parse_youtube_id, character(1), USE.NAMES = FALSE)
    i <- which(!is.na(id))
    jobs$youtube <- data.frame(i = i, link = paste0("https://www.youtube.com/watch?v=", id[i]))
  }
  if ("soundcloud" %in% services) {
    i <- which(!.blank(lib$soundcloud_url))
    jobs$soundcloud <- data.frame(i = i, link = trimws(lib$soundcloud_url[i]))
  }

  rows <- list()
  for (svc in names(jobs)) {
    jb <- jobs[[svc]]
    if (!nrow(jb)) next
    if (progress) message(sprintf("Checking %d %s link(s)...", nrow(jb), svc))
    for (k in seq_len(nrow(jb))) {
      r <- fetch(svc, jb$link[k])
      i <- jb$i[k]
      found <- r$title %||% NA_character_
      want  <- .lib_norm(lib$song_title[i])
      match <- if (is.na(found) || !nzchar(want)) NA else
        grepl(want, .lib_norm(found), fixed = TRUE)
      rows[[length(rows) + 1]] <- tibble::tibble(
        line = i + 1L, song_title = as.character(lib$song_title[i]),
        artist = as.character(lib$artist[i]), service = svc, link = jb$link[k],
        status = as.integer(r$status), ok = if (is.na(r$status)) NA else r$status == 200,
        found_title = found, title_match = match,
        detail = .link_meaning(svc, r$status))
    }
  }
  if (!length(rows)) {
    return(tibble::tibble(line = integer(), song_title = character(), artist = character(),
                          service = character(), link = character(), status = integer(),
                          ok = logical(), found_title = character(),
                          title_match = logical(), detail = character()))
  }
  dplyr::bind_rows(rows)
}

# -----------------------------------------------------------------------------
# 3. COVERAGE: does every slot get a good match?
# -----------------------------------------------------------------------------

#' The song pools the app draws from (see LIBRARY_POOLS)
#'
#' @param lib Library as loaded by load_song_library() (numeric bpm)
#' @param blocked_youtube YouTube ids that can't be embedded
#' @return Named list of tibbles: spotify, youtube, all
library_pools <- function(lib, blocked_youtube = character(0)) {
  play <- playable_songs(lib)
  if (is.null(play) || !nrow(play)) {
    return(list(spotify = play, youtube = play, all = play))
  }
  sp <- !is.na(vapply(play$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE))
  yt <- vapply(play$youtube_url, parse_youtube_id, character(1), USE.NAMES = FALSE)
  sc <- !.blank(play$soundcloud_url)
  list(
    spotify = play[sp, , drop = FALSE],
    youtube = play[(!is.na(yt) & !(yt %in% blocked_youtube)) | sc, , drop = FALSE],
    all     = play
  )
}

#' Simulate the app's song matching for every slot
#'
#' For every scaling mode x period x pool, runs the app's own
#' assign_songs_to_playlist() for each Shuffle value and records how far the
#' picked song's BPM is from the slot's target.
#'
#' @param playlists list(per_period = generate_all_playlists(...),
#'   global = generate_all_playlists(..., co2_scale = ...)) - like ALL_PLAYLISTS
#' @param pools Named list of library subsets (library_pools())
#' @param shuffles Shuffle-button values to test (0 = what visitors see first)
#' @param tols The matcher's tolerances (first = "good match")
#' @return Tibble, one row per mode x period x pool x slot: target_bpm,
#'   choice (pool songs within tols[1] BPM), worst_gap / mean_gap over the
#'   shuffles, good_share (share of shuffles within tols[1]), status of the
#'   worst shuffle ("within 5", "within 10", "nearest", "none").
library_coverage <- function(playlists, pools, shuffles = 0:2, tols = c(5, 10)) {
  res <- list()
  # identical pools (e.g. every playable song has a Spotify link) are simulated once
  same_as <- vapply(seq_along(pools), function(k) {
    hit <- which(vapply(pools[seq_len(k - 1)], identical, logical(1), pools[[k]]))
    if (length(hit)) hit[1] else NA_integer_
  }, integer(1))
  for (mode in names(playlists)) {
    for (period in names(playlists[[mode]])) {
      slots <- playlists[[mode]][[period]]$songs
      if (is.null(slots) || !nrow(slots)) next
      done <- list()
      for (k in seq_along(pools)) {
        pool <- names(pools)[k]
        if (!is.na(same_as[k])) {
          copy <- done[[same_as[k]]]
          copy$pool <- pool
          res[[length(res) + 1]] <- copy
          done[[k]] <- copy
          next
        }
        lib <- pools[[pool]]
        n_lib <- if (is.null(lib)) 0L else nrow(lib)
        lib_bpm <- if (n_lib) lib$bpm[!is.na(lib$bpm)] else numeric(0)
        choice <- vapply(slots$bpm, function(t) sum(abs(lib_bpm - t) <= tols[1]), integer(1))
        gaps <- matrix(NA_real_, nrow(slots), length(shuffles))
        for (k in seq_along(shuffles)) {
          picks <- if (n_lib) assign_songs_to_playlist(slots, lib, period = period,
                                                       shuffle_counter = shuffles[k],
                                                       tols = tols) else NULL
          if (!is.null(picks) && nrow(picks)) {
            idx <- match(picks$song_number, slots$song_number)
            gaps[idx, k] <- abs(picks$bpm - slots$bpm[idx])
          }
        }
        worst <- apply(gaps, 1, function(g) if (all(is.na(g))) NA_real_ else max(g, na.rm = TRUE))
        worst[apply(gaps, 1, anyNA)] <- NA_real_                  # any unmatched draw = none
        one <- tibble::tibble(
          mode = mode, period = period, pool = pool,
          song_number = slots$song_number, target_bpm = slots$bpm,
          choice = choice,
          worst_gap = worst,
          mean_gap = rowMeans(gaps, na.rm = TRUE),
          good_share = rowMeans(!is.na(gaps) & gaps <= tols[1]),
          status = dplyr::case_when(
            is.na(worst)       ~ "none",
            worst <= tols[1]   ~ paste("within", tols[1]),
            worst <= tols[2]   ~ paste("within", tols[2]),
            TRUE               ~ "nearest")
        )
        res[[length(res) + 1]] <- one
        done[[k]] <- one
      }
    }
  }
  if (!length(res)) return(tibble::tibble())
  out <- dplyr::bind_rows(res)
  out$mean_gap[is.nan(out$mean_gap)] <- NA_real_
  out
}

#' One line per scaling mode x period x pool
#'
#' @param cov Output of library_coverage()
#' @param variety Songs within the first tolerance wanted per slot
coverage_summary <- function(cov, variety = 3) {
  if (!nrow(cov)) return(tibble::tibble())
  cov |>
    dplyr::group_by(pool, mode, period) |>
    dplyr::summarise(
      slots        = dplyr::n(),
      good_matches = sum(status == "within 5"),
      fallbacks    = sum(status != "within 5"),
      unmatched    = sum(status == "none"),
      thin_choice  = sum(choice < variety),
      worst_gap    = suppressWarnings(max(worst_gap, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    dplyr::mutate(pct_good = round(100 * good_matches / slots),
                  worst_gap = ifelse(is.finite(worst_gap), worst_gap, NA_real_)) |>
    dplyr::arrange(pool, mode, match(period, names(TIME_PERIODS)))
}

#' Which BPM ranges need more songs?
#'
#' Groups slots into BPM bins. Within ONE playlist a song can't repeat, so the
#' demand of a bin is the busiest playlist's number of slots there.
#'
#' @param cov Output of library_coverage()
#' @param pools The pools used for cov (to count songs per bin)
#' @param modes Scaling modes to include. Default: per_period only - on the
#'   global scale every ice-core era sits at ~60-66 BPM, which no library can
#'   fill without repeats (see the README).
#' @param step Bin width in BPM
#' @param variety Songs within ±5 BPM wanted per slot
#' @return Tibble per pool x bin: songs (in the pool, inside the bin),
#'   busiest (most slots in one playlist), fallbacks (most slots in one playlist
#'   without a ±5 match), min_choice, add_at_least (rough number of songs to
#'   add inside the bin), worst_in (which playlist is short)
library_gaps <- function(cov, pools, modes = "per_period", step = 5, variety = 3,
                         bpm_range = c(BPM_MIN, BPM_MAX)) {
  cov <- cov[cov$mode %in% modes, , drop = FALSE]
  if (!nrow(cov)) return(tibble::tibble())
  edges <- seq(bpm_range[1], bpm_range[2], by = step)
  bin_of <- function(b) {
    lo <- edges[findInterval(b, edges, rightmost.closed = TRUE)]
    lo[b >= bpm_range[2]] <- utils::tail(edges, 2)[1]       # 150 joins 145-149
    lo
  }
  cov$bin_lo <- bin_of(cov$target_bpm)

  per_pl <- cov |>
    dplyr::group_by(pool, bin_lo, mode, period) |>
    dplyr::summarise(slots = dplyr::n(),
                     fallbacks = sum(status != "within 5"),
                     min_choice = min(choice), .groups = "drop")

  worst <- per_pl |>
    dplyr::group_by(pool, bin_lo) |>
    dplyr::arrange(dplyr::desc(fallbacks), dplyr::desc(slots), .by_group = TRUE) |>
    dplyr::summarise(
      busiest    = max(slots),
      fallbacks  = max(fallbacks),
      min_choice = min(min_choice),
      worst_in   = paste0(period[1], " (", gsub("_", "-", mode[1]), ")"),
      .groups = "drop")

  have <- lapply(names(pools), function(p) {
    b <- pools[[p]]$bpm
    b <- b[!is.na(b) & b >= bpm_range[1] & b <= bpm_range[2]]
    tibble::tibble(pool = p, bin_lo = edges[-length(edges)],
                   songs = vapply(edges[-length(edges)], function(lo) {
                     hi <- if (lo + step >= bpm_range[2]) bpm_range[2] + 0.5 else lo + step
                     sum(b >= lo & b < hi)
                   }, integer(1)))
  })
  have <- dplyr::bind_rows(have)

  dplyr::left_join(have, worst, by = c("pool", "bin_lo")) |>
    dplyr::mutate(
      bin = ifelse(bin_lo + step >= bpm_range[2],
                   paste0(bin_lo, "-", bpm_range[2]),
                   paste0(bin_lo, "-", bin_lo + step - 1)),
      busiest    = dplyr::coalesce(busiest, 0L),
      fallbacks  = dplyr::coalesce(fallbacks, 0L),
      add_at_least = pmax(fallbacks, ifelse(is.na(min_choice), 0L, variety - min_choice), 0L),
      worst_in   = ifelse(add_at_least > 0, worst_in, "")
    ) |>
    dplyr::arrange(pool, bin_lo) |>
    dplyr::select(pool, bin, songs, busiest, fallbacks, min_choice, add_at_least, worst_in)
}

#' Ready to launch? One line per criterion.
#'
#' @param issues Output of check_song_library()
#' @param cov Output of library_coverage()
#' @param pool The pool public visitors will use ("spotify" or "youtube")
#' @param modes Scaling modes that count (default: per_period, the app default)
#' @param links Optional output of check_song_links()
#' @param variety Songs within ±5 BPM wanted per slot
#' @return list(ready = logical, lines = character)
library_verdict <- function(issues, cov, pool = "spotify", modes = "per_period",
                            links = NULL, variety = 3) {
  tick <- function(ok, yes, no) paste(if (ok) "✓" else "✗", if (ok) yes else no)
  c_pool <- cov[cov$pool == pool & cov$mode %in% modes, , drop = FALSE]
  n_err  <- length(unique(issues$line[issues$severity == "error"]))
  n_fb   <- sum(c_pool$status != "within 5")
  n_thin <- sum(c_pool$choice < variety)
  worst  <- if (n_fb) {
    tab <- sort(table(paste0(c_pool$period, " (", c_pool$mode, ")")[c_pool$status != "within 5"]),
                decreasing = TRUE)
    paste0(" - most in ", names(tab)[1], ": ", tab[[1]])
  } else ""

  scope <- sprintf("[%s pool, %s scaling]", pool, paste(gsub("_", "-", modes), collapse = " + "))
  lines <- c(
    tick(n_err == 0, "No rows with errors.",
         sprintf("%d row(s) with errors (see issues.csv).", n_err)),
    tick(n_fb == 0,
         sprintf("Every slot gets a song within ±5 BPM %s.", scope),
         sprintf("%d of %d slots fall back to ±10 BPM or the nearest song %s%s.",
                 n_fb, nrow(c_pool), scope, worst)),
    tick(n_thin == 0,
         sprintf("At least %d songs to choose from for every slot (Shuffle has variety).", variety),
         sprintf("%d slots have fewer than %d songs within ±5 BPM (Shuffle repeats).",
                 n_thin, variety))
  )
  ok <- c(n_err == 0, n_fb == 0, n_thin == 0)
  if (!is.null(links) && nrow(links)) {
    n_bad <- sum(links$ok %in% FALSE)
    n_mis <- sum(links$title_match %in% FALSE)
    lines <- c(lines,
               tick(n_bad == 0, "All links work and may be embedded.",
                    sprintf("%d link(s) broken or not embeddable (see links.csv).", n_bad)))
    ok <- c(ok, n_bad == 0)
    if (n_mis) lines <- c(lines, sprintf(
      "! %d link(s) may point to a different song (title doesn't match) - check found_title in links.csv.",
      n_mis))
  }
  list(ready = all(ok), lines = lines)
}
