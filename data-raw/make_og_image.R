# data-raw/make_og_image.R -------------------------------------------------
# The picture shown when someone shares the app's link (WhatsApp, Signal,
# Slack, ...): www/og-image.png, 1200 x 630 px. From the project root:
#
#   source("data-raw/make_og_image.R")
#
# Draws the last 800,000 years of CO2 (Bereiter ice-core composite, then
# Mauna Loa) in the app's colours. Uses the app's fonts if they are installed
# (Playfair Display, DM Sans, JetBrains Mono from Google Fonts), otherwise
# the system's serif / sans / mono. Re-run after big data changes and
# re-deploy; the link-preview tags are in R/share.R.

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(grid)
})

root <- if (file.exists("R/config.R")) "." else
  if (file.exists("../R/config.R")) ".." else
    stop("Run this script from the project root (or data-raw/).")
for (f in c("config.R", "load_data.R")) source(file.path(root, "R", f))

OUT    <- file.path(root, "www", "og-image.png")
WIDTH  <- 1200
HEIGHT <- 630

# App colours (app.R: app_css())
BG_FROM <- "#0a0a0f"
BG_TO   <- "#1a1a2e"
INK     <- "#f5f5f7"
MUTED   <- "#a1a1aa"
LINE    <- "#ef4444"       # the app's "warm" red (Max CO2)

# First installed family wins; plain "serif"/"sans"/"mono" otherwise
pick_font <- function(candidates, fallback) {
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    have <- unique(systemfonts::system_fonts()$family)
    hit <- candidates[candidates %in% have]
    if (length(hit)) return(hit[1])
  }
  fallback
}
FONT_TITLE <- pick_font("Playfair Display", "serif")
FONT_BODY  <- pick_font(c("DM Sans", "DM Sans 9pt"), "sans")
FONT_MONO  <- pick_font("JetBrains Mono", "mono")

# ---- data: ice core up to 1950, then Mauna Loa ------------------------------
invisible(utils::capture.output(co2 <- load_co2_data(file.path(root, "data"))))
series <- bind_rows(
  co2$icecore %>% filter(age >= 0) %>% transmute(t = -age, co2),   # years before 1950
  co2$modern  %>% transmute(t = -age, co2)                         # years after 1950
) %>% arrange(t)
now_ppm <- floor(max(co2$modern$co2) / 10) * 10                     # "420+ ppm"

# ---- chart: one line, no axes (the labels around it do that job) -------------
chart <- ggplot(series, aes(t, co2)) +
  geom_line(colour = LINE, linewidth = 4, alpha = 0.18, lineend = "round") +   # soft glow
  geom_line(colour = LINE, linewidth = 1.3, lineend = "round", linejoin = "round") +
  scale_x_continuous(expand = expansion(0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.02))) +
  theme_void() +
  theme(plot.background = element_rect(fill = NA, colour = NA),
        panel.background = element_rect(fill = NA, colour = NA))

# ---- draw ----------------------------------------------------------------------
dev_png <- if (requireNamespace("ragg", quietly = TRUE)) {
  function() ragg::agg_png(OUT, width = WIDTH, height = HEIGHT, units = "px", res = 72)
} else {
  function() grDevices::png(OUT, width = WIDTH, height = HEIGHT, units = "px", res = 72,
                            type = "cairo")
}
dir.create(dirname(OUT), showWarnings = FALSE)
dev_png()

px <- function(x) unit(x, "native")
pushViewport(viewport(xscale = c(0, WIDTH), yscale = c(0, HEIGHT)))

# background: the app's diagonal gradient (solid where the device can't)
bg <- tryCatch(linearGradient(c(BG_FROM, BG_TO), x1 = 0, y1 = 1, x2 = 1, y2 = 0),
               error = function(e) BG_TO)
grid.rect(gp = gpar(fill = bg, col = NA))

grid.text(expression(paste("800,000 YEARS OF CO"[2], ", TURNED INTO TEMPO")),
          x = px(WIDTH / 2), y = px(HEIGHT - 92),
          gp = gpar(fontfamily = FONT_MONO, fontsize = 22, col = MUTED))
grid.text("Beats per Million", x = px(WIDTH / 2), y = px(HEIGHT - 172),
          gp = gpar(fontfamily = FONT_TITLE, fontface = "bold", fontsize = 92, col = INK))
grid.text(expression(paste("Dance While You Can — the more CO"[2], ", the faster the music")),
          x = px(WIDTH / 2), y = px(HEIGHT - 246),
          gp = gpar(fontfamily = FONT_BODY, fontsize = 34, col = MUTED))

# chart band
left <- 72; right <- WIDTH - 72; bottom <- 96; top <- 330
print(chart, vp = viewport(x = px((left + right) / 2), y = px((bottom + top) / 2),
                           width = px(right - left), height = px(top - bottom)), newpage = FALSE)

# direct labels: the two ends of the time axis, and today's value
grid.text("800,000 years ago", x = px(left), y = px(bottom - 30), just = "left",
          gp = gpar(fontfamily = FONT_BODY, fontsize = 22, col = MUTED))
grid.text("today", x = px(right), y = px(bottom - 30), just = "right",
          gp = gpar(fontfamily = FONT_BODY, fontsize = 22, col = MUTED))
grid.text(paste0(now_ppm, "+ ppm"), x = px(right - 22), y = px(top - 10), just = "right",
          gp = gpar(fontfamily = FONT_MONO, fontsize = 22, col = INK))

popViewport()
invisible(dev.off())
message("Wrote ", normalizePath(OUT), " (", WIDTH, " x ", HEIGHT, " px; fonts: ",
        FONT_TITLE, " / ", FONT_BODY, " / ", FONT_MONO, ")")
