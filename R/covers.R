# =============================================================================
# ALBUM COVERS - for "Show covers on the plot"
# =============================================================================
#
# Covers come from Spotify's public oEmbed endpoint (no key needed): for a
# track link it answers with a `thumbnail_url`, the album cover (300 x 300 px).
# They are cached in data/song_covers.csv (spotify_id, cover_url), which
# data-raw/fetch_covers.R and the deploy script keep up to date - so the app
# normally never has to ask Spotify while someone is using it. A song missing
# from the file is looked up once per R session when covers are switched on.
#
# Covers are only shown while playing via Spotify, and only Spotify covers:
# Spotify's terms allow cover art next to Spotify's own player (credited, with
# a link back), not next to songs played from another service. Songs without
# a Spotify cover simply get none - no YouTube thumbnails mixed in.
#
# Needs functions.R (parse_spotify_id). httr2 for fetching.
# =============================================================================

COVERS_CSV <- "song_covers.csv"   # in data/

.no_covers <- function() stats::setNames(character(0), character(0))

#' Cover address from a parsed oEmbed answer
#'
#' @param body Parsed JSON (list) from an oEmbed endpoint, or NULL
#' @return The https thumbnail_url, or NA_character_
oembed_thumbnail <- function(body) {
  url <- tryCatch(body$thumbnail_url, error = function(e) NULL)
  if (is.null(url) || length(url) != 1 || is.na(url)) return(NA_character_)
  url <- trimws(as.character(url))
  if (!grepl("^https://[^ ]+$", url)) return(NA_character_)
  url
}

#' Ask Spotify's oEmbed endpoint for the covers of several tracks
#'
#' Requests run in parallel, so a whole playlist takes about a second.
#'
#' @param ids Spotify track ids
#' @param timeout Seconds per request
#' @return Named character vector (names = ids); NA where no cover was found
#'   (unknown track, or Spotify couldn't be reached)
fetch_spotify_covers <- function(ids, timeout = 10) {
  ids <- unique(ids[!is.na(ids) & nzchar(ids)])
  out <- stats::setNames(rep(NA_character_, length(ids)), ids)
  if (!length(ids)) return(out)

  reqs <- lapply(ids, function(id) {
    httr2::request("https://open.spotify.com/oembed") |>
      httr2::req_url_query(url = paste0("https://open.spotify.com/track/", id)) |>
      httr2::req_user_agent("Beats per Million album covers (R/httr2)") |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = function(r) FALSE)
  })
  resps <- tryCatch(
    httr2::req_perform_parallel(reqs, on_error = "continue", progress = FALSE),
    error = function(e) vector("list", length(reqs))
  )
  for (i in seq_along(ids)) {
    r <- resps[[i]]
    if (inherits(r, "httr2_response") && httr2::resp_status(r) == 200) {
      out[[i]] <- oembed_thumbnail(tryCatch(httr2::resp_body_json(r),
                                            error = function(e) NULL))
    }
  }
  out
}

#' Read the cover cache
#'
#' @param path data/song_covers.csv
#' @return Named character vector: names = Spotify track ids, values = cover
#'   addresses. Empty if the file doesn't exist (yet).
read_cover_cache <- function(path) {
  if (!file.exists(path)) return(.no_covers())
  x <- tryCatch(utils::read.csv(path, colClasses = "character",
                                na.strings = c("", "NA"), encoding = "UTF-8"),
                error = function(e) NULL)
  if (is.null(x) || !all(c("spotify_id", "cover_url") %in% names(x))) return(.no_covers())
  x <- x[!is.na(x$spotify_id) & nzchar(x$spotify_id) & !is.na(x$cover_url), , drop = FALSE]
  stats::setNames(x$cover_url, x$spotify_id)
}

#' Write the cover cache (sorted, so git diffs stay small)
#'
#' @param cache Named character vector (read_cover_cache())
#' @param path Where to write
write_cover_cache <- function(cache, path) {
  cache <- cache[!is.na(cache) & !is.na(names(cache))]
  df <- data.frame(spotify_id = names(cache), cover_url = unname(cache),
                   stringsAsFactors = FALSE)
  df <- df[order(df$spotify_id), , drop = FALSE]
  utils::write.csv(df, path, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  invisible(path)
}

#' Fetch the covers the cache doesn't have yet, and save it
#'
#' Used by data-raw/fetch_covers.R and the deploy script. Songs that are no
#' longer in the library are dropped from the file.
#'
#' @param lib Song library (load_song_library())
#' @param path data/song_covers.csv
#' @param refetch TRUE = ask Spotify again for every song
#' @param fetch function(ids) -> named character vector (swap in a fake for tests)
#' @return The updated cache (invisibly), with attributes `asked` (songs looked
#'   up) and `missing` (Spotify ids still without a cover)
update_cover_cache <- function(lib, path, refetch = FALSE, fetch = fetch_spotify_covers) {
  cache <- if (isTRUE(refetch)) .no_covers() else read_cover_cache(path)
  ids <- vapply(lib$spotify_uri %||% character(0), parse_spotify_id, character(1),
                USE.NAMES = FALSE)
  ids <- unique(ids[!is.na(ids)])
  todo <- setdiff(ids, names(cache))
  if (length(todo)) {
    got <- fetch(todo)
    got <- got[!is.na(got) & names(got) %in% todo]
    cache[names(got)] <- got
  }
  cache <- cache[names(cache) %in% ids]
  write_cover_cache(cache, path)
  attr(cache, "asked")   <- length(todo)
  attr(cache, "missing") <- setdiff(ids, names(cache))
  invisible(cache)
}

#' Cover image for each song: its Spotify cover from the cache, otherwise NA
#'
#' @param spotify_uri Song links (Spotify URI / URL / id)
#' @param cache Named character vector (read_cover_cache())
#' @return Character vector of image addresses (NA = no image)
song_cover_urls <- function(spotify_uri, cache = .no_covers()) {
  n <- length(spotify_uri)
  if (!n) return(character(0))
  sp <- vapply(spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
  out <- rep(NA_character_, n)
  hit <- !is.na(sp) & sp %in% names(cache)
  out[hit] <- unname(cache[sp[hit]])
  out
}

#' An in-memory cover store for the running app
#'
#' Starts from data/song_covers.csv; covers looked up while the app runs are
#' added to it (shared by all visitors of this R process, never written to
#' disk). Each missing track is asked for at most once per process.
#'
#' @param path data/song_covers.csv
#' @return An environment with `cache` and `tried`
cover_store <- function(path) {
  st <- new.env(parent = emptyenv())
  st$cache <- read_cover_cache(path)
  st$tried <- character(0)
  st
}

#' Covers for a set of songs, looking up missing Spotify covers on the way
#'
#' @param store cover_store()
#' @param picks Matched songs (needs spotify_uri)
#' @param fetch function(ids) -> named character vector; NULL = cache only
#' @return Character vector of image addresses, one per row of `picks`
store_cover_urls <- function(store, picks, fetch = fetch_spotify_covers) {
  if (is.null(picks) || !nrow(picks)) return(character(0))
  sp <- vapply(picks$spotify_uri, parse_spotify_id, character(1), USE.NAMES = FALSE)
  todo <- setdiff(unique(sp[!is.na(sp)]), c(names(store$cache), store$tried))
  if (!is.null(fetch) && length(todo)) {
    got <- tryCatch(fetch(todo), error = function(e) NULL)
    got <- got[!is.na(got) & names(got) %in% todo]
    if (length(got)) store$cache[names(got)] <- got
    store$tried <- union(store$tried, todo)
  }
  song_cover_urls(picks$spotify_uri, store$cache)
}
