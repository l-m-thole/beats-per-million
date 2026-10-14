# Tripwires for the platform rules in DEVELOPMENT.md ("Platform rules &
# privacy (keep these)"). Spotify, YouTube and SoundCloud only allow their
# players in a non-commercial app, and Spotify forbids synchronising its
# recordings with visual media and letting visitors download its covers. So:
#   - no ads, sponsors, paid features or trackers,
#   - no export that puts the music together with the plot, and no plot
#     download at all (it can carry Spotify's covers).
# These tests only read the code that ships with the app. If one fails, check
# the change against that section of DEVELOPMENT.md before touching the test.

rules_root <- function() {
  for (d in c(file.path("..", ".."), ".", "..")) {
    if (file.exists(file.path(d, "app.R"))) return(normalizePath(d))
  }
  NULL
}

# app.R, R/*.R and www/*.js: one string per file, named by its path in the app
shipped_code <- function(root) {
  files <- c(file.path(root, "app.R"),
             list.files(file.path(root, "R"), pattern = "\\.[Rr]$", full.names = TRUE),
             list.files(file.path(root, "www"), pattern = "\\.js$", full.names = TRUE,
                        recursive = TRUE))
  code <- vapply(files, function(f) {
    paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }, character(1))
  stats::setNames(code, substring(files, nchar(root) + 2))
}

# Names of the files whose code matches `pattern`
files_matching <- function(code, pattern, ignore.case = FALSE) {
  names(code)[grepl(pattern, code, perl = TRUE, useBytes = TRUE,
                    ignore.case = ignore.case)]
}

expect_none <- function(hits, what) {
  expect(length(hits) == 0,
         sprintf("%s in %s - see DEVELOPMENT.md, \"Platform rules & privacy\".",
                 what, paste(hits, collapse = ", ")))
}

test_that("the app stays non-commercial: no ad, tracking or payment code", {
  root <- rules_root()
  skip_if(is.null(root), "app.R not found")
  code <- shipped_code(root)
  expect_true(all(c("app.R", "www/player.js") %in% names(code)))

  expect_none(files_matching(code, ignore.case = TRUE, paste0(
    "googlesyndication\\.com|adsbygoogle|doubleclick\\.net|googleadservices\\.com|",
    "amazon-adsystem\\.com|adnxs\\.com|taboola\\.com|outbrain\\.com|carbonads\\.|",
    "buysellads\\.com")), "Ad code")
  expect_none(files_matching(code, ignore.case = TRUE, paste0(
    "googletagmanager\\.com|google-analytics\\.com|\\bgtag\\(|plausible\\.io|",
    "matomo|hotjar\\.com")), "Tracking code")
  expect_none(files_matching(code, ignore.case = TRUE, paste0(
    "js\\.stripe\\.com|buy\\.stripe\\.com|checkout\\.stripe\\.com|paypal\\.(com|me)|",
    "ko-fi\\.com|buymeacoffee\\.com|patreon\\.com")), "Payment or donation code")
})

test_that("nothing exports the plot, alone or together with the music", {
  root <- rules_root()
  skip_if(is.null(root), "app.R not found")
  code <- shipped_code(root)
  all_code <- paste(code, collapse = "\n")

  # plotly's mode bar carries a "download plot as png" button: keep it off
  expect(grepl("displayModeBar\\s*=\\s*FALSE", code[["app.R"]], perl = TRUE),
         "The plot's mode bar is back (plot download): keep displayModeBar = FALSE.")

  # no screen/audio recording, animation or image export
  expect_none(files_matching(code, paste0(
    "MediaRecorder|captureStream|toImage|html2canvas|CCapture|gif\\.js|gifshot|",
    "gganimate|gifski|\\bav::|animation::|image_animate|image_write_gif|",
    "save_image|\\borca\\(")), "Recording, animation or image export code")

  # The only download is the playlist CSV (a song list: no audio, no pictures).
  # Adding one? Check it against the rules first, then add its id here.
  ui_ids <- regmatches(all_code, gregexpr(
    "download(Button|Link)\\(\\s*(outputId\\s*=\\s*)?\"[^\"]+\"", all_code,
    perl = TRUE))[[1]]
  handlers <- regmatches(all_code, gregexpr(
    "output\\$[A-Za-z0-9_.]+\\s*<-\\s*downloadHandler", all_code, perl = TRUE))[[1]]
  ids <- unique(c(sub(".*\"([^\"]+)\"$", "\\1", ui_ids),
                  sub("^output\\$([A-Za-z0-9_.]+).*$", "\\1", handlers)))
  expect_true("download_csv" %in% ids)   # the search still finds the CSV download
  extra <- setdiff(ids, "download_csv")
  expect(length(extra) == 0,
         sprintf(paste("New download %s - check it against DEVELOPMENT.md,",
                       "\"Platform rules & privacy\", then add its id here."),
                 paste(extra, collapse = ", ")))
})
