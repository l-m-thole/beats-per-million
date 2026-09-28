# R/enrich_library.R ------------------------------------------------------
# Fill BLANK bpm / spotify_uri / soundcloud_url / youtube_url cells in
# data/song_library.csv.
#
#   * Never overwrites a value someone typed by hand.
#   * Only accepts a match when BOTH title and artist agree (karaoke, covers,
#     live and remix versions are penalised unless you asked for them).
#   * Every lookup is written to a review log so you can check the matches.
#
# Keys live in .Renviron (never commit it) - see .Renviron.example:
#   GETSONGBPM_KEY                               -> bpm        (getsongbpm.com/api)
#   SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET    -> spotify    (developer.spotify.com)
#   SOUNDCLOUD_CLIENT_ID / SOUNDCLOUD_CLIENT_SECRET -> soundcloud (developers.soundcloud.com)
#   YOUTUBE_API_KEY                              -> youtube    (console.cloud.google.com,
#                                                   "YouTube Data API v3"; free quota
#                                                   = ~100 searches/day, re-run next day)
# A step whose keys are missing is skipped with a message; the others still run.
#
# Depends on: httr2, readr

# ---- small helpers ---------------------------------------------------------

.or <- function(a, b) if (is.null(a)) b else a   # %||% needs R >= 4.4

.enrich_cache <- new.env(parent = emptyenv())    # OAuth tokens for this session

# readr writes "" as a quoted empty string; NA + na = "" gives a clean empty cell
.empty_to_na <- function(df) {
  df[] <- lapply(df, function(x) {
    if (is.character(x)) x[!is.na(x) & !nzchar(x)] <- NA
    x
  })
  df
}

# ---- string matching (pure; tested offline) ------------------------------

#' Normalise a title/artist for comparison:
#' ASCII, lower case, no "(Remastered 2011)", "- Live", "feat. X", punctuation.
normalise_str <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  x[is.na(x)] <- ""
  x <- tolower(x)
  x <- gsub("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]", "", x, perl = TRUE)
  x <- gsub(paste0("\\s+-\\s+(\\d{4}\\s+)?",
                   "(remaster\\w*|live|radio|single|mono|stereo|edit|version|",
                   "mix|from|original|bonus)\\b.*$"), "", x, perl = TRUE)
  x <- gsub("\\b(feat|ft|featuring)\\b.*$", "", x, perl = TRUE)
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("['`\"]", "", x)
  x <- gsub("[^a-z0-9 ]", " ", x)
  x <- trimws(gsub("\\s+", " ", x))
  sub("^the ", "", x)
}

#' First credited artist, as typed: "Jay-Z & Kanye West ft. X" -> "Jay-Z"
primary_artist_raw <- function(x) {
  x <- ifelse(is.na(x), "", as.character(x))
  parts <- strsplit(
    x, "(?i)\\s+(&|and|vs\\.?|x|with|feat\\.?|ft\\.?|featuring)\\s+|,\\s*",
    perl = TRUE
  )
  trimws(vapply(parts, function(p) if (length(p)) p[1] else "", character(1)))
}

primary_artist <- function(x) normalise_str(primary_artist_raw(x))

# Versions we don't want unless the library row asks for them
.junk_terms <- c("karaoke", "instrumental", "cover", "tribute", "originally performed",
                 "made famous", "in the style of", "8d", "sped up", "slowed", "nightcore",
                 "remix", "live", "acoustic", "piano version", "reprise", "demo", "workout")

#' Score a candidate. >= 3 means title AND artist agree.
#'   title: 2 = identical, 1 = wanted title contained in candidate title
#'   artist: 2 = primary artist found in candidate artist(s) or title
#'   -3 if candidate is karaoke/cover/live/remix/... and the wanted row isn't
match_score <- function(want_title, want_artist, got_title, got_artist) {
  ns <- function(x) gsub(" ", "", x, fixed = TRUE)
  wt <- normalise_str(want_title)
  gt <- normalise_str(got_title)
  if (!nzchar(wt) || !nzchar(gt)) return(0)
  wa <- primary_artist(want_artist)
  ga <- normalise_str(paste(got_artist, got_title))

  title_score <- if (ns(wt) == ns(gt)) 2 else if (grepl(ns(wt), ns(gt), fixed = TRUE)) 1 else 0
  artist_score <- if (nzchar(wa) && grepl(ns(wa), ns(ga), fixed = TRUE)) 2 else 0

  raw_got  <- tolower(paste(got_title, got_artist))
  raw_want <- tolower(paste(want_title, want_artist))
  junk <- vapply(.junk_terms, function(t) {
    p <- paste0("\\b", t, "\\b")
    grepl(p, raw_got, perl = TRUE) && !grepl(p, raw_want, perl = TRUE)
  }, logical(1))

  title_score + artist_score - 3 * any(junk)
}

#' Best candidate (data.frame with title, artist, value) or NULL if none is confident
pick_best <- function(cands, want_title, want_artist, min_score = 3) {
  if (is.null(cands) || !nrow(cands)) return(NULL)
  s <- mapply(match_score, want_title, want_artist, cands$title, cands$artist,
              USE.NAMES = FALSE)
  if (max(s) < min_score) return(NULL)
  i <- which.max(s)   # ties -> first, i.e. the API's own relevance order
  list(value = cands$value[i], matched_title = cands$title[i],
       matched_artist = cands$artist[i], score = s[i])
}

# ---- HTTP plumbing ---------------------------------------------------------

.enrich_req <- function(url) {
  httr2::request(url) |>
    httr2::req_user_agent("climate-playlist song-library enrichment (R/httr2)") |>
    httr2::req_retry(max_tries = 4) |>          # retries 429/503, honours Retry-After
    httr2::req_throttle(rate = 2) |>            # max 2 requests/second per host
    httr2::req_error(is_error = function(resp) FALSE)
}

# Condition that stops the current step (bad/missing keys, quota) but not the run
.stop_step <- function(msg) stop(errorCondition(msg, class = "enrich_stop_step"))

.check_resp <- function(resp, service) {
  st <- httr2::resp_status(resp)
  if (st %in% c(401, 403)) .stop_step(sprintf(
    "%s refused the request (HTTP %d) - check the keys in .Renviron.", service, st))
  if (st == 429) .stop_step(sprintf(
    "%s quota/rate limit reached (HTTP 429) - run again later.", service))
  if (st >= 400) stop(sprintf("%s returned HTTP %d", service, st))
  invisible(resp)
}

.need_env <- function(vars, service) {
  missing <- vars[!nzchar(Sys.getenv(vars))]
  if (length(missing)) .stop_step(sprintf(
    "%s skipped: set %s in .Renviron and restart R.", service,
    paste(missing, collapse = ", ")))
}

.get_token <- function(service) {
  tok <- .enrich_cache[[service]]
  if (!is.null(tok) && Sys.time() < tok$expires) return(tok$value)

  cfg <- switch(service,
    spotify    = list(url = "https://accounts.spotify.com/api/token",
                      id = "SPOTIFY_CLIENT_ID", secret = "SPOTIFY_CLIENT_SECRET"),
    soundcloud = list(url = "https://secure.soundcloud.com/oauth/token",
                      id = "SOUNDCLOUD_CLIENT_ID", secret = "SOUNDCLOUD_CLIENT_SECRET")
  )
  .need_env(c(cfg$id, cfg$secret), service)

  resp <- .enrich_req(cfg$url) |>
    httr2::req_auth_basic(Sys.getenv(cfg$id), Sys.getenv(cfg$secret)) |>
    httr2::req_body_form(grant_type = "client_credentials") |>
    httr2::req_perform()
  .check_resp(resp, paste(service, "login"))

  body <- httr2::resp_body_json(resp)
  .enrich_cache[[service]] <- list(
    value   = body$access_token,
    expires = Sys.time() + .or(body$expires_in, 3600) - 60
  )
  body$access_token
}

# ---- the three lookups -----------------------------------------------------
# Each takes (title, artist) and returns NULL or
# list(value, matched_title, matched_artist, score)

#' BPM from GetSongBPM (free key; their terms require a visible link back
#' to getsongbpm.com, e.g. in the app footer or README).
lookup_bpm <- function(title, artist) {
  .need_env("GETSONGBPM_KEY", "BPM (GetSongBPM)")
  resp <- .enrich_req("https://api.getsong.co/search/") |>
    httr2::req_headers(`X-API-KEY` = Sys.getenv("GETSONGBPM_KEY")) |>
    httr2::req_url_query(
      type   = "both",
      lookup = sprintf("song:%s artist:%s", title, primary_artist_raw(artist)),
      limit  = 10
    ) |>
    httr2::req_perform()
  .check_resp(resp, "GetSongBPM")

  hits <- httr2::resp_body_json(resp)$search
  if (!is.list(hits) || !is.null(names(hits)) || !length(hits)) return(NULL)  # {"error": "no result"}

  cands <- data.frame(
    title  = vapply(hits, function(h) .or(h$title, ""), character(1)),
    artist = vapply(hits, function(h) .or(h$artist$name, ""), character(1)),
    value  = vapply(hits, function(h) as.character(.or(h$tempo, NA)), character(1)),
    stringsAsFactors = FALSE
  )
  cands <- cands[!is.na(suppressWarnings(as.numeric(cands$value))), , drop = FALSE]
  pick_best(cands, title, artist)
}

#' Spotify track link via the Search API (client credentials).
#' Since Feb 2026 the app owner needs Spotify Premium and search returns max 10.
lookup_spotify <- function(title, artist) {
  token <- .get_token("spotify")
  search <- function(q) {
    resp <- .enrich_req("https://api.spotify.com/v1/search") |>
      httr2::req_auth_bearer_token(token) |>
      httr2::req_url_query(q = q, type = "track", limit = 10) |>
      httr2::req_perform()
    .check_resp(resp, "Spotify")
    items <- httr2::resp_body_json(resp)$tracks$items
    if (!length(items)) return(NULL)
    data.frame(
      title  = vapply(items, function(t) .or(t$name, ""), character(1)),
      artist = vapply(items, function(t) paste(
        vapply(t$artists, function(a) .or(a$name, ""), character(1)),
        collapse = ", "), character(1)),
      value  = vapply(items, function(t) paste0("https://open.spotify.com/track/", t$id),
                      character(1)),
      stringsAsFactors = FALSE
    )
  }
  t <- gsub('"', "", title)
  a <- gsub('"', "", primary_artist_raw(artist))
  res <- pick_best(search(sprintf('track:"%s" artist:"%s"', t, a)), title, artist)
  if (is.null(res)) res <- pick_best(search(paste(t, a)), title, artist)  # looser retry
  res
}

#' SoundCloud track link (client credentials). Many hits are fan uploads -
#' check the uploader in the log.
lookup_soundcloud <- function(title, artist) {
  token <- .get_token("soundcloud")
  resp <- .enrich_req("https://api.soundcloud.com/tracks") |>
    httr2::req_headers(Authorization = paste("OAuth", token)) |>
    httr2::req_url_query(q = paste(primary_artist_raw(artist), title), limit = 10) |>
    httr2::req_perform()
  .check_resp(resp, "SoundCloud")

  body  <- httr2::resp_body_json(resp)
  items <- if (!is.null(body$collection)) body$collection else body
  if (!length(items)) return(NULL)

  cands <- data.frame(
    title  = vapply(items, function(t) .or(t$title, ""), character(1)),
    artist = vapply(items, function(t) .or(t$user$username, ""), character(1)),
    value  = vapply(items, function(t) .or(t$permalink_url, ""), character(1)),
    stringsAsFactors = FALSE
  )
  pick_best(cands[nzchar(cands$value), , drop = FALSE], title, artist)
}

#' YouTube video link via the YouTube Data API v3 (search.list, Music category).
#' Each search costs 100 of the free 10,000 daily quota units (~100 songs/day);
#' when the quota is used up the step stops and the rest is filled next run.
lookup_youtube <- function(title, artist) {
  .need_env("YOUTUBE_API_KEY", "YouTube")
  resp <- .enrich_req("https://www.googleapis.com/youtube/v3/search") |>
    httr2::req_url_query(
      part = "snippet", type = "video", videoCategoryId = "10",
      videoEmbeddable = "true", maxResults = 10,
      q = paste(primary_artist_raw(artist), title),
      key = Sys.getenv("YOUTUBE_API_KEY")
    ) |>
    httr2::req_perform()
  if (httr2::resp_status(resp) == 403 &&
      grepl("quota", httr2::resp_body_string(resp), ignore.case = TRUE)) {
    .stop_step("YouTube daily quota used up - run again tomorrow (filled rows are kept).")
  }
  .check_resp(resp, "YouTube")

  items <- httr2::resp_body_json(resp)$items
  if (!length(items)) return(NULL)
  # YouTube titles are often "Artist - Title (Official Video)"; channel names
  # are "ArtistVEVO" or "Artist - Topic" - match_score handles both.
  cands <- data.frame(
    title  = vapply(items, function(v) .or(v$snippet$title, ""), character(1)),
    artist = vapply(items, function(v) .or(v$snippet$channelTitle, ""), character(1)),
    value  = vapply(items, function(v) paste0("https://www.youtube.com/watch?v=",
                                              .or(v$id$videoId, "")), character(1)),
    stringsAsFactors = FALSE
  )
  cands$title <- gsub("&amp;", "&", gsub("&#39;|&quot;", "'", cands$title))
  pick_best(cands, title, artist)
}

default_lookups <- function() {
  list(bpm = lookup_bpm, spotify = lookup_spotify, soundcloud = lookup_soundcloud,
       youtube = lookup_youtube)
}

# ---- driver ----------------------------------------------------------------

#' Fill blank cells in the song library and write a review log.
#'
#' @param path      the library CSV
#' @param steps     any of "bpm", "spotify", "soundcloud", "youtube"
#' @param lookups   named list of lookup functions (swap in fakes for tests)
#' @param bpm_range app tempo range; BPMs outside it are flagged in the log
#' @param log_path  where the review log goes
#' @param backup    copy the old CSV to data/backups/ before writing
#' @return the log (invisibly)
enrich_song_library <- function(path = "data/song_library.csv",
                                steps = c("bpm", "spotify", "soundcloud", "youtube"),
                                lookups = default_lookups(),
                                bpm_range = c(60, 150),
                                log_path = file.path(dirname(path), "song_library_enrich_log.csv"),
                                backup = TRUE) {
  steps <- match.arg(steps, several.ok = TRUE)
  cols  <- c(bpm = "bpm", spotify = "spotify_uri", soundcloud = "soundcloud_url",
             youtube = "youtube_url")

  lib <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                         na = character(), trim_ws = TRUE, show_col_types = FALSE)
  for (cl in c("song_title", "artist", cols, "notes")) {
    if (!cl %in% names(lib)) lib[[cl]] <- ""
  }
  blank <- function(x) is.na(x) | !nzchar(trimws(x))

  log <- list()
  for (st in steps) {
    if (is.null(lookups[[st]])) next
    col  <- cols[[st]]
    todo <- which(!blank(lib$song_title) & !blank(lib$artist) & blank(lib[[col]]))
    if (!length(todo)) { message(sprintf("[%s] nothing to fill", st)); next }
    message(sprintf("[%s] looking up %d song(s)...", st, length(todo)))

    for (i in todo) {
      res <- tryCatch(
        lookups[[st]](lib$song_title[i], lib$artist[i]),
        enrich_stop_step = function(e) e,
        error = function(e) {
          message(sprintf("  ! %s - %s: %s", lib$song_title[i], lib$artist[i],
                          conditionMessage(e)))
          NULL
        }
      )
      if (inherits(res, "enrich_stop_step")) {
        message("  ", conditionMessage(res))
        break
      }

      value <- if (is.null(res)) "" else as.character(res$value)
      flag  <- if (is.null(res)) "no confident match - fill by hand" else ""
      if (st == "bpm" && nzchar(value)) {
        bpm   <- round(as.numeric(value))
        value <- as.character(bpm)
        if (bpm < bpm_range[1] || bpm > bpm_range[2]) {
          flag <- sprintf("outside %g-%g BPM: consider half/double time",
                          bpm_range[1], bpm_range[2])
        }
      }
      if (nzchar(value)) lib[[col]][i] <- value

      log[[length(log) + 1]] <- data.frame(
        csv_line       = i + 1L,                  # +1 for the header row
        song_title     = lib$song_title[i],
        artist         = lib$artist[i],
        field          = col,
        value          = value,
        matched_title  = if (is.null(res)) "" else res$matched_title,
        matched_artist = if (is.null(res)) "" else res$matched_artist,
        score          = if (is.null(res)) NA_real_ else res$score,
        flag           = flag,
        stringsAsFactors = FALSE
      )
    }
  }

  log <- if (length(log)) do.call(rbind, log) else data.frame()
  filled <- if (nrow(log)) sum(nzchar(log$value)) else 0L

  if (filled > 0) {
    if (backup) {
      bdir <- file.path(dirname(path), "backups")
      dir.create(bdir, showWarnings = FALSE)
      file.copy(path, file.path(bdir, sprintf("song_library_%s.csv",
                                              format(Sys.time(), "%Y%m%d-%H%M%S"))))
    }
    readr::write_csv(.empty_to_na(lib), path, na = "")
  }
  if (nrow(log)) readr::write_csv(.empty_to_na(log), log_path, na = "")

  message(sprintf("Filled %d cell(s); %d need a look (see %s).",
                  filled, if (nrow(log)) sum(nzchar(log$flag)) else 0L, log_path))
  invisible(log)
}
