# =============================================================================
# CLIMATE PLAYLISTS - MAIN GENERATOR SCRIPT
# =============================================================================
#
# Run this script to generate all playlist templates.
#
# Usage:
#   source("run_generator.R")
#   
# Or from command line:
#   Rscript run_generator.R
#
# Output:
#   - output/playlist_template_[period].csv (one per period)
#   - output/all_playlist_templates.xlsx (combined)
#   - output/playlist_data.xlsx (full data with stats)
#
# =============================================================================

# -----------------------------------------------------------------------------
# SETUP
# -----------------------------------------------------------------------------

# Load required packages
library(tidyverse)
library(readxl)
library(writexl)

# Source shared modules
source("R/config.R")
source("R/functions.R")
source("R/load_data.R")

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------

OUTPUT_DIR <- "output"

# Create output directory if needed
if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

# -----------------------------------------------------------------------------
# MAIN EXECUTION
# -----------------------------------------------------------------------------

cat("\n")
cat("╔═══════════════════════════════════════════════════════════════════╗\n")
cat("║            CLIMATE PLAYLISTS GENERATOR v3.0                       ║\n")
cat("║         Translating Earth's Climate History into Music            ║\n")
cat("╚═══════════════════════════════════════════════════════════════════╝\n")
cat("\n")

# Load all CO2 data
co2_data <- load_co2_data("data")

# Validate
validate_co2_data(co2_data)

# Show summary
summarize_co2_data(co2_data)

# Generate all playlists
cat("Generating playlists...\n\n")
all_playlists <- generate_all_playlists(co2_data)

# Print summaries
for (playlist in all_playlists) {
  print_playlist_summary(playlist)
}

# -----------------------------------------------------------------------------
# EXPORT TEMPLATES (for adding songs)
# -----------------------------------------------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  EXPORTING PLAYLIST TEMPLATES\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

# Create templates for each period
templates <- list()

for (id in names(all_playlists)) {
  playlist <- all_playlists[[id]]
  template <- create_playlist_template(playlist)
  templates[[id]] <- template
  
  # Save individual CSV
  csv_file <- file.path(OUTPUT_DIR, paste0("playlist_template_", id, ".csv"))
  write_csv(template, csv_file)
  cat("  ✓", csv_file, "(", nrow(template), "songs )\n")
}

# Save combined Excel file
excel_file <- file.path(OUTPUT_DIR, "all_playlist_templates.xlsx")
write_xlsx(templates, excel_file)
cat("\n  ✓", excel_file, "\n")

# -----------------------------------------------------------------------------
# EXPORT FULL DATA (with stats)
# -----------------------------------------------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  EXPORTING FULL PLAYLIST DATA\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

# Create summary sheet
summary_df <- do.call(rbind, lapply(names(all_playlists), function(id) {
  s <- all_playlists[[id]]$stats
  tibble(
    period_id = s$period_id,
    period_name = s$period_name,
    years_span = s$years_span,
    years_per_minute = s$years_per_minute,
    playlist_minutes = s$playlist_minutes,
    num_songs = s$num_songs,
    co2_min = s$co2_min,
    co2_max = s$co2_max,
    bpm_min = s$bpm_min,
    bpm_max = s$bpm_max,
    data_points = s$data_points
  )
}))

# Combine all songs
all_songs <- do.call(rbind, lapply(names(all_playlists), function(id) {
  all_playlists[[id]]$songs %>%
    mutate(period_id = id, .before = 1)
}))

# Create workbook with multiple sheets
sheets <- list(
  Summary = summary_df,
  All_Songs = all_songs %>% select(-bpm_color)
)

# Add individual period sheets
for (id in names(all_playlists)) {
  sheet_name <- gsub("_", " ", id)
  sheets[[sheet_name]] <- all_playlists[[id]]$songs %>% select(-bpm_color)
}

data_file <- file.path(OUTPUT_DIR, "playlist_data.xlsx")
write_xlsx(sheets, data_file)
cat("  ✓", data_file, "\n")

# -----------------------------------------------------------------------------
# FINAL SUMMARY
# -----------------------------------------------------------------------------

cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("  GENERATION COMPLETE\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

cat("Summary:\n\n")

for (id in names(all_playlists)) {
  s <- all_playlists[[id]]$stats
  period <- get_period(id)
  
  cat(sprintf("  %-35s  %3d songs  |  BPM: %3d – %3d  |  CO₂: %4d – %4d ppm\n",
              s$period_name,
              s$num_songs,
              s$bpm_min,
              s$bpm_max,
              s$co2_min,
              s$co2_max))
}

total_songs <- sum(sapply(all_playlists, function(p) p$stats$num_songs))
cat("\n")
cat("  Total:", total_songs, "songs across", length(all_playlists), "time periods\n")
cat("\n")
cat("  Output files saved to:", normalizePath(OUTPUT_DIR), "\n")
cat("\n")
cat("═══════════════════════════════════════════════════════════════════\n")
cat("\n")

# Return playlists for interactive use
invisible(all_playlists)
