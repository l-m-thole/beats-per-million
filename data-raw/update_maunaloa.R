# data-raw/update_maunaloa.R -----------------------------------------------
# Bring the Modern playlist up to date: fetch NOAA's newest Mauna Loa monthly
# CO2 file, check it, and rebuild data/co2_data.xlsx. From the project root:
#
#   source("data-raw/update_maunaloa.R")
#
# Safe to run any time: the raw file is only replaced when NOAA has new or
# revised months, and a download that looks wrong (truncated, out of order,
# implausible values, big changes to old months) is refused - see
# check_maunaloa_update() in R/refresh_co2.R.
#
# GitHub runs this every month (.github/workflows/refresh-co2.yml) and opens a
# pull request when something changed. After merging: re-deploy.

root <- if (file.exists("R/config.R")) "." else
  if (file.exists("../R/config.R")) ".." else
    stop("Run this script from the project root (or data-raw/).")

source(file.path(root, "R", "refresh_co2.R"))

raw_file <- file.path(root, "data", "rawData", "co2_mm_mlo.csv")
message("Fetching ", MAUNALOA_URL, " ...")
chk <- download_maunaloa(raw_file)

summary_line <- if (!chk$changed) {
  paste0("Already up to date (data through ", chk$through, ").")
} else {
  paste0("Mauna Loa data now through ", chk$through,
         if (!is.na(chk$was)) paste0(" (was ", chk$was, ")"), ": ",
         chk$new_months, " new month(s)",
         if (chk$revised > 0) paste0(", ", chk$revised, " revised"), ".")
}
message(summary_line)

if (chk$changed) source(file.path(root, "data-raw", "build_co2_data.R"))

# For the GitHub Action: step outputs (title of the pull request)
gh_out <- Sys.getenv("GITHUB_OUTPUT")
if (nzchar(gh_out)) {
  cat(sprintf("changed=%s\nthrough=%s\nsummary=%s\n",
              tolower(chk$changed), chk$through, summary_line),
      file = gh_out, append = TRUE)
}
