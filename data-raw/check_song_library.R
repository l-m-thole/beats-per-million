# data-raw/check_song_library.R ------------------------------------------
# Is the song library good enough to launch?  From the project root:
#
#   source("data-raw/check_song_library.R")
#
# Prints a short report and a READY / NOT YET verdict, and writes the details
# to output/library_check/ (git-ignored):
#   issues.csv    rows to fix (errors first): missing BPM/links, broken links,
#                 BPM outside 60-150, duplicates, videos that can't be embedded
#   coverage.csv  every playlist slot: target BPM, how close the match is,
#                 how many songs it can choose from
#   gaps.csv      BPM ranges that need more songs (per player pool)
#   links.csv     online link check (only with CHECK_LINKS = TRUE)
#
# Launch criteria (for the scaling mode visitors start with, per period):
#   1. no rows with errors
#   2. every slot gets a song within the matcher's first window, ±3 BPM
#      (MATCH_TOLS in R/config.R; no ±5 / ±10 / "nearest" fallbacks)
#   3. at least VARIETY songs within ±3 BPM per slot, so Shuffle has choice
#   4. (with CHECK_LINKS) every link works and may be embedded
#
# With CHECK_LINKS it also lists YouTube links from channels that don't look
# official (lyrics / promo / fan uploads): swap those for the artist's own,
# VEVO or "Artist - Topic" upload (not a launch criterion, but do it).

CHECK_LINKS <- FALSE      # TRUE = also test every link online (no keys; ~1-2 min)
PUBLIC_POOL <- "spotify"  # what public visitors get by default:
                          #   "spotify" = Play via Spotify (BPM_DEFAULT_PLAYER=spotify)
                          #   "youtube" = Play via YouTube, whole songs without login
                          #   (a playlist never mixes services: one pool each)
SHUFFLES    <- 0:2        # Shuffle re-rolls to test (0 = what visitors see first)
VARIETY     <- 3          # songs within ±3 BPM (the first window) wanted per slot
OUT_DIR     <- file.path("output", "library_check")

suppressPackageStartupMessages(library(dplyr))
for (f in c("config.R", "functions.R", "load_data.R", "settings.R", "library_check.R")) {
  source(file.path("R", f))
}

# ---- data -------------------------------------------------------------------
co2       <- load_co2_data("data")
playlists <- suppressMessages(list(
  per_period = generate_all_playlists(co2),
  global     = generate_all_playlists(co2, co2_scale = global_co2_range(co2))
))
lib_raw <- read_library_raw("data/song_library.csv")
lib     <- load_song_library("data")
blocked <- read_blocked_youtube("data/youtube_blocked.csv")
pools   <- library_pools(lib, blocked)
# simulate only services that have songs (SoundCloud may have none)
pools   <- pools[vapply(pools, NROW, integer(1)) > 0 | names(pools) == PUBLIC_POOL]

# ---- checks -----------------------------------------------------------------
issues <- check_song_library(lib_raw, blocked_youtube = blocked)
message("Simulating the song matching (", length(SHUFFLES), " shuffle(s), all periods, both scalings)...")
cov  <- library_coverage(playlists, pools, shuffles = SHUFFLES)
summ <- coverage_summary(cov, variety = VARIETY)
gaps <- library_gaps(cov, pools, modes = "per_period", variety = VARIETY)
links <- if (isTRUE(CHECK_LINKS)) check_song_links(lib_raw, progress = TRUE) else NULL

# ---- report -----------------------------------------------------------------
rule <- function(title) cat("\n", title, "\n", strrep("-", nchar(title)), "\n", sep = "")

rule("SONG LIBRARY")
cat(sprintf("%d songs | %d playable | Spotify %d | YouTube %d (%d blocked) | SoundCloud %d\n",
            nrow(lib_raw), nrow(playable_songs(lib)), NROW(pools$spotify),
            sum(!is.na(vapply(lib$youtube_url, parse_youtube_id, character(1)))),
            length(blocked), sum(!is.na(lib$soundcloud_url) & nzchar(trimws(lib$soundcloud_url)))))

rule("ROWS TO FIX")
if (!nrow(issues)) {
  cat("None.\n")
} else {
  print(table(issue = issues$issue, severity = issues$severity))
  err <- issues[issues$severity == "error", ]
  if (nrow(err)) {
    cat("\nErrors:\n")
    cat(sprintf("  line %3d  %s - %s: %s\n", err$line, err$song_title, err$artist, err$issue),
        sep = "")
  }
}

rule("MATCHING, per-period scaling (the app default)")
show <- summ[summ$mode == "per_period" & summ$pool %in% c("spotify", "youtube"),
             c("pool", "period", "slots", "pct_good", "fallbacks", "wide", "thin_choice",
               "worst_gap")]
print(as.data.frame(show), row.names = FALSE)
cat(sprintf(paste0("pct_good = slots matched within ±%g BPM; fallbacks = slots that needed a wider\n",
                   "window; wide = slots beyond ±%g BPM; thin_choice = slots with < %d songs within ±%g BPM\n"),
            MATCH_TOLS[1], MATCH_TOLS[min(2, length(MATCH_TOLS))], VARIETY, MATCH_TOLS[1]))

rule(paste0("WHERE SONGS ARE MISSING [", PUBLIC_POOL, " pool]"))
need <- gaps[gaps$pool == PUBLIC_POOL & gaps$add_at_least > 0,
             c("bin", "songs", "busiest", "fallbacks", "add_at_least", "worst_in")]
if (nrow(need)) print(as.data.frame(need), row.names = FALSE) else cat("Nothing - every BPM range is covered.\n")
cat("songs = songs in that range now; add_at_least = rough number to add there\n")

glob <- summ[summ$mode == "global" & summ$pool == PUBLIC_POOL, ]
rule("GLOBAL scaling (not a launch criterion)")
cat(sprintf("%d of %d slots fall back. On the global scale the ice-core eras sit at ~60-66 BPM,\n",
            sum(glob$fallbacks), sum(glob$slots)))
cat("so their playlists would need ~90 different very slow songs; drift to faster songs is expected.\n")

if (!is.null(links)) {
  rule("LINKS (online)")
  bad <- links[links$ok %in% FALSE | links$title_match %in% FALSE, ]
  cat(sprintf("%d links checked: %d ok, %d broken/not embeddable, %d unreachable, %d possible wrong song\n",
              nrow(links), sum(links$ok %in% TRUE), sum(links$ok %in% FALSE),
              sum(is.na(links$ok)), sum(links$title_match %in% FALSE)))
  if (nrow(bad)) print(as.data.frame(bad[, c("line", "song_title", "service", "detail", "found_title")]),
                       row.names = FALSE)

  rule("YOUTUBE UPLOADS FROM CHANNELS THAT DON'T LOOK OFFICIAL")
  unoff <- links[links$service == "youtube" & links$official %in% FALSE, ]
  if (!nrow(unoff)) {
    cat("None - every YouTube link comes from a Topic, VEVO or artist channel.\n")
  } else {
    print(as.data.frame(unoff[, c("line", "song_title", "artist", "channel")]), row.names = FALSE)
    cat("Swap these for the artist's own, VEVO or 'Artist - Topic' upload (label channels\n",
        "are often fine too - check by hand). Embedding unofficial uploads is where the\n",
        "app's copyright risk sits.\n", sep = "")
  }
}

rule(paste0("VERDICT [", PUBLIC_POOL, " pool]"))
v <- library_verdict(issues, cov, pool = PUBLIC_POOL, links = links, variety = VARIETY)
cat(v$lines, sep = "\n")
cat(if (v$ready) "\nREADY TO LAUNCH\n" else "\nNOT YET - see above and output/library_check/\n")

# ---- files ------------------------------------------------------------------
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
readr::write_csv(issues, file.path(OUT_DIR, "issues.csv"), na = "")
readr::write_csv(cov,    file.path(OUT_DIR, "coverage.csv"), na = "")
readr::write_csv(gaps,   file.path(OUT_DIR, "gaps.csv"), na = "")
if (!is.null(links)) readr::write_csv(links, file.path(OUT_DIR, "links.csv"), na = "")
message("Details written to ", OUT_DIR, "/")

library_check <- list(issues = issues, coverage = cov, summary = summ, gaps = gaps,
                      links = links, verdict = v)
invisible(library_check)
