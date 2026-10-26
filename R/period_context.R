# =============================================================================
# CLIMATE PLAYLISTS - PERIOD CONTEXT & KEY EVENTS
# =============================================================================
#
# Longer background text, a timeline of key events and how the CO2 was
# measured, for each time period. Shown in the app ("About this era" window,
# markers on the CO2 plot, "During this song" in the Listen panel, and the
# "How it works" window).
#
# Ages are in years BP (before 1950, the paleoclimate convention used by the
# data): age = 1950 - year CE. Modern-era events therefore have NEGATIVE ages
# (2015 CE -> -65). Ages of prehistoric events are rounded, best-estimate
# values; the `when` column is what the app displays.
#
# Source after config.R (needs TIME_PERIODS). Base R only.
# =============================================================================

.ev <- function(...) {
  x <- rbind(...)
  data.frame(
    age    = as.numeric(x[, 1]),
    when   = x[, 2],
    title  = x[, 3],
    detail = x[, 4],
    stringsAsFactors = FALSE
  )
}
.yr <- function(year_ce) as.character(REFERENCE_YEAR - year_ce)   # CE -> years BP

PERIOD_CONTEXT <- list(

  # ---------------------------------------------------------------------------
  modern = list(
    context = c(
      "In 1958 Charles David Keeling started measuring CO₂ in the clean air on top of Mauna Loa, Hawaii. The record has run almost without a break ever since and is the longest direct measurement of atmospheric CO₂.",
      "Two signals stand out. The sawtooth is the planet breathing: CO₂ drops every northern summer when plants grow and rises again in winter. Underneath, the trend climbs relentlessly — from ~315 ppm in 1958 to more than 420 ppm today, and the yearly increase itself keeps getting bigger.",
      "Listen for: the tempo only goes one way. Each song is about three years of measurements, so the playlist speeds up as fossil-fuel emissions grow."
    ),
    key_events = .ev(
      c(.yr(1958), "1958", "Keeling starts measuring",
        "First continuous CO₂ measurements at Mauna Loa: ~315 ppm."),
      c(.yr(1970), "1970", "First Earth Day",
        "Environmental protection becomes a mass movement."),
      c(.yr(1988), "1988", "IPCC founded",
        "The Intergovernmental Panel on Climate Change is set up to assess climate science."),
      c(.yr(1992), "1992", "Rio Earth Summit",
        "The UN Framework Convention on Climate Change (UNFCCC) is signed."),
      c(.yr(1997), "1997", "Kyoto Protocol",
        "First treaty with binding emission cuts for industrialised countries."),
      c(.yr(2013), "2013", "400 ppm crossed",
        "Daily CO₂ at Mauna Loa passes 400 ppm for the first time in human history."),
      c(.yr(2015), "2015", "Paris Agreement",
        "Nearly every country agrees to keep warming well below 2 °C, aiming for 1.5 °C."),
      c(.yr(2020), "2020", "COVID-19 pandemic",
        "Global emissions drop ~6-7 % for a year - hardly visible in the CO₂ curve."),
      c(.yr(2024), "2024", "Record rise, 1.5 °C year",
        "Largest yearly CO₂ jump on record, and the first calendar year more than 1.5 °C warmer than pre-industrial.")
    )
  ),

  # ---------------------------------------------------------------------------
  industrial = list(
    context = c(
      "Climate models need to know how much CO₂ was in the air in every year to re-run the past. For the newest generation of models (CMIP7) this history was compiled from Antarctic ice and firn air, which hold the air of the 1800s and early 1900s, and from direct air measurements at stations around the globe since the late 1950s. Model runs of the historical climate start in 1850 - so does this playlist.",
      "For a century CO₂ creeps up: from ~285 ppm in 1850 to ~310 ppm in 1950, as coal, land clearing and later oil add carbon faster than oceans and forests can take it up. After World War II the 'Great Acceleration' begins - cars, plastics, fertiliser, air travel - and CO₂ climbs faster with every decade, to more than 420 ppm today. More than half of all the fossil CO₂ humans have ever emitted was released after 1990.",
      "Listen for: a long, slow first half (with per-era scaling the 1800s sit at the slowest tempos), then the beat picks up after 1950 and gets faster song by song. The Modern Era playlist zooms into the last 70 years of this one."
    ),
    key_events = .ev(
      c(.yr(1850), "1850", "Industrial Revolution spreads",
        "Coal-powered industry and railways spread from Britain across Europe and North America; CO₂ ~285 ppm."),
      c(.yr(1896), "1896", "Arrhenius' calculation",
        "Svante Arrhenius (Stockholm) calculates that doubling CO₂ would warm the Earth by several degrees."),
      c(.yr(1914), "1914-1918", "First World War",
        "A brief dip in emissions, invisible in the CO₂ curve."),
      c(.yr(1930), "1930s", "Great Depression",
        "Emissions fall for a few years; CO₂ keeps rising, only more slowly."),
      c(.yr(1950), "~1950", "Great Acceleration",
        "After the Second World War, energy use, population and emissions take off together."),
      c(.yr(1958), "1958", "Keeling starts measuring",
        "Direct CO₂ measurements at Mauna Loa begin: ~315 ppm. The Modern Era playlist starts here."),
      c(.yr(1988), "1988", "IPCC founded",
        "The Intergovernmental Panel on Climate Change is set up to assess climate science."),
      c(.yr(1997), "1997", "Kyoto Protocol",
        "First treaty with binding emission cuts for industrialised countries."),
      c(.yr(2015), "2015", "Paris Agreement",
        "Nearly every country agrees to keep warming well below 2 °C, aiming for 1.5 °C."),
      c(.yr(2024), "2024", "Record rise, 1.5 °C year",
        "Largest yearly CO₂ jump on record, and the first calendar year more than 1.5 °C warmer than pre-industrial.")
    )
  ),

  # ---------------------------------------------------------------------------
  roman = list(
    context = c(
      "Air bubbles trapped in Antarctic ice preserve samples of the atmosphere from the last two thousand years - from the height of the Roman Empire through the Middle Ages to the start of industrialisation.",
      "Europe's climate swung noticeably in this time (the warm Roman and Medieval periods, the cold Little Ice Age), mostly driven by the Sun and volcanic eruptions. CO₂ barely moved: it stayed within ~275-285 ppm for 1,800 years. A small dip around 1600 CE may partly reflect forests regrowing in the Americas after the population collapse that followed European contact.",
      "Then, from the mid-1800s, CO₂ rises steeply as coal burning spreads. Listen for: a long, calm, nearly flat stretch, and a sudden acceleration at the very end. With per-period scaling even tiny wiggles become audible - switch to Global scaling to hear how flat this era really was."
    ),
    key_events = .ev(
      c(.yr(-27), "27 BCE", "Roman Empire begins",
        "Augustus becomes the first emperor; the 'Roman Climate Optimum' (warm and stable) lasts until ~200 CE."),
      c(.yr(476), "476 CE", "Fall of Western Rome",
        "End of the Western Roman Empire."),
      c(.yr(536), "536 CE", "Volcanic 'year without sun'",
        "Large eruptions start the Late Antique Little Ice Age (536-660 CE)."),
      c(.yr(985), "~985 CE", "Norse settle Greenland",
        "During the Medieval Climate Anomaly (~950-1250 CE), a warm period in the North Atlantic."),
      c(.yr(1257), "1257 CE", "Samalas eruption",
        "One of the largest eruptions of the last 2,000 years (Lombok, Indonesia) helps trigger the Little Ice Age."),
      c(.yr(1610), "~1610 CE", "CO₂ dip ('Orbis spike')",
        "A ~7-10 ppm CO₂ minimum, linked to forest regrowth after the collapse of Indigenous populations in the Americas."),
      c(.yr(1815), "1815 CE", "Tambora eruption",
        "1816 becomes the 'Year Without a Summer' in Europe and North America."),
      c(.yr(1850), "~1850 CE", "Industrial Revolution",
        "Coal burning spreads; CO₂ starts its climb above the pre-industrial ~280 ppm.")
    )
  ),

  # ---------------------------------------------------------------------------
  lgm = list(
    context = c(
      "Twenty thousand years ago the world was in the depth of the last ice age. Ice sheets up to 3 km thick covered Scandinavia and most of North America, sea level was ~120 m lower than today, and CO₂ was around 185 ppm - among the lowest values in the whole ice-core record.",
      "Small changes in Earth's orbit started the melt, and the ocean - especially the Southern Ocean - released CO₂, which amplified the warming. The rise came in steps, with abrupt warm and cold spells along the way. By ~11,700 years ago the stable, warm Holocene had begun, and with it farming and the first villages.",
      "Listen for: slow, ambient songs at the start, a stepped climb in tempo through the deglaciation, and a calm, mid-tempo plateau through the Holocene."
    ),
    key_events = .ev(
      c("20000", "~20,000 yrs ago", "Last Glacial Maximum",
        "Ice sheets at their largest; sea level ~120 m lower; CO₂ ~185 ppm."),
      c("18000", "~18,000 yrs ago", "Deglaciation begins",
        "Orbital changes warm the north; the Southern Ocean starts releasing CO₂."),
      c("14700", "~14,700 yrs ago", "Bølling-Allerød warming",
        "Abrupt warming in the North Atlantic, a rapid CO₂ jump and a large meltwater pulse raises sea level."),
      c("12900", "~12,900 yrs ago", "Younger Dryas",
        "A sudden return to near-glacial cold in the north for ~1,200 years."),
      c("11700", "~11,700 yrs ago", "Holocene begins",
        "The current warm, stable interglacial starts; farming emerges in the Fertile Crescent soon after."),
      c("10000", "~10,000 yrs ago", "Sweden emerges from the ice",
        "The Scandinavian ice sheet melts back; most of Sweden becomes ice-free."),
      c("8200", "~8,200 yrs ago", "8.2 kyr cold event",
        "A meltwater flood into the North Atlantic causes a brief (~150-year) cold snap."),
      c("7000", "~7,000 yrs ago", "Holocene CO₂ low",
        "CO₂ bottoms out near 260 ppm and then slowly rises to ~280 ppm."),
      c("5000", "~5,000 yrs ago", "First writing",
        "Writing in Mesopotamia and Egypt; Stonehenge is begun."),
      c("2000", "~2,000 yrs ago", "Roman Empire",
        "See the Roman Empire playlist for a zoom-in.")
    )
  ),

  # ---------------------------------------------------------------------------
  humans = list(
    context = c(
      "Our species, Homo sapiens, appeared in Africa roughly 300,000 years ago. This playlist covers the last 250,000 years - almost the whole story of anatomically modern humans.",
      "Throughout that time Earth swung between long ice ages (glacials, CO₂ ~180-190 ppm) and shorter warm interglacials (~280 ppm), paced by slow changes in Earth's orbit. Humans lived through two full glacial cycles, spread out of Africa across the world during the last ice age, and only started farming once the climate stabilised in the Holocene.",
      "Listen for: two big waves - a fast peak at the Last Interglacial (~125,000 years ago), a long slow descent into the last ice age, and a second rise into the Holocene at the end."
    ),
    key_events = .ev(
      c("240000", "~240,000 yrs ago", "MIS 7 interglacial",
        "A warm interglacial with CO₂ near 280 ppm."),
      c("160000", "~160,000 yrs ago", "Penultimate ice age",
        "Deep glacial (MIS 6); CO₂ ~190 ppm. Early Homo sapiens live in Africa."),
      c("125000", "~125,000 yrs ago", "Last Interglacial (Eemian)",
        "Slightly warmer than today; sea level 6-9 m higher; hippos live in Britain."),
      c("74000", "~74,000 yrs ago", "Toba supereruption",
        "The largest volcanic eruption of the last 2 million years (Sumatra)."),
      c("65000", "~65,000 yrs ago", "Out of Africa",
        "Homo sapiens spread across Asia and reach Australia."),
      c("40000", "~40,000 yrs ago", "Humans in Europe",
        "Homo sapiens settle Europe; Neanderthals disappear soon after."),
      c("20000", "~20,000 yrs ago", "Last Glacial Maximum",
        "Coldest point of the last ice age; CO₂ ~185 ppm."),
      c("11700", "~11,700 yrs ago", "Holocene & farming",
        "The warm, stable Holocene begins; agriculture starts soon after.")
    )
  ),

  # ---------------------------------------------------------------------------
  icecore = list(
    context = c(
      "The EPICA Dome C ice core, drilled more than 3 km deep in East Antarctica, reaches back about 800,000 years. Combined with other Antarctic cores it gives the Bereiter et al. (2015) composite: the longest direct record of past atmospheric CO₂.",
      "The record shows eight glacial-interglacial cycles, each about 100,000 years long and paced by changes in Earth's orbit (Milankovitch cycles). CO₂ always moved between ~180 ppm in ice ages and ~280-300 ppm in warm periods. After the Mid-Brunhes Event (~430,000 years ago) the warm peaks became higher.",
      "Today's ~425 ppm would sit far above the top of this plot: in 800,000 years CO₂ never exceeded 300 ppm. Listen for: a regular rhythm - long slow slides into ice ages and fast climbs out of them."
    ),
    key_events = .ev(
      c("800000", "~800,000 yrs ago", "Oldest ice",
        "The record begins in the deepest ice of EPICA Dome C."),
      c("430000", "~430,000 yrs ago", "Mid-Brunhes Event",
        "Interglacials after this point are warmer, with higher CO₂ peaks."),
      c("400000", "~400,000 yrs ago", "MIS 11 super-interglacial",
        "An unusually long (~30,000-year) warm period - often compared to the Holocene."),
      c("300000", "~300,000 yrs ago", "Homo sapiens appear",
        "The oldest known fossils of our species (Jebel Irhoud, Morocco)."),
      c("125000", "~125,000 yrs ago", "Last Interglacial (Eemian)",
        "Sea level 6-9 m higher than today."),
      c("20000", "~20,000 yrs ago", "Last Glacial Maximum",
        "The most recent ice-age low, CO₂ ~185 ppm."),
      c("11700", "~11,700 yrs ago", "Holocene",
        "Our current interglacial begins.")
    )
  ),

  # ---------------------------------------------------------------------------
  cenozoic = list(
    context = c(
      "The Cenozoic - the 'Age of Mammals' - starts with the asteroid impact that ended the dinosaurs 66 million years ago. There is no ice this old, so CO₂ is reconstructed from chemical fingerprints in fossil plankton shells (boron isotopes) and organic molecules (alkenones) in deep-sea sediments (Rae et al. 2021).",
      "The big story is a long cooling. In the early Eocene hothouse, CO₂ reached well above 1,000 ppm, there was no permanent ice, and forests grew near the poles. As CO₂ fell, Antarctica froze over about 34 million years ago, and ice sheets in the Northern Hemisphere followed ~2.7 million years ago, starting the ice-age cycles of the other playlists.",
      "Resolution note: the data are binned into ~100,000-year steps, so sharp events like the PETM are smoothed out. Listen for: high-energy songs in the Eocene and a long, uneven slowdown towards the present."
    ),
    key_events = .ev(
      c("66000000", "66 Ma", "Asteroid impact (K-Pg)",
        "The Chicxulub impact ends the age of dinosaurs; mammals diversify."),
      c("56000000", "56 Ma", "PETM",
        "Paleocene-Eocene Thermal Maximum: massive carbon release warms Earth by ~5 °C - the closest geological analogue to today's emissions."),
      c("51000000", "~53-49 Ma", "Early Eocene hothouse",
        "Peak Cenozoic warmth: CO₂ well above 1,000 ppm, no polar ice, crocodiles and palms in the Arctic."),
      c("40000000", "~40 Ma", "Middle Eocene Climatic Optimum",
        "A ~500,000-year warm spike during the long cooling."),
      c("33900000", "~34 Ma", "Antarctica freezes",
        "Eocene-Oligocene transition: CO₂ falls and a permanent Antarctic ice sheet forms."),
      c("15500000", "~17-14 Ma", "Miocene Climatic Optimum",
        "A warm interval with CO₂ around 400-600 ppm."),
      c("7000000", "~7 Ma", "Human lineage splits",
        "Our ancestors split from those of chimpanzees in Africa."),
      c("3200000", "~3.3-3.0 Ma", "Mid-Pliocene Warm Period",
        "CO₂ ~400 ppm - similar to today - with sea level 10-20 m higher."),
      c("2700000", "~2.7 Ma", "Northern ice sheets",
        "Large ice sheets start to form in the Northern Hemisphere; the ice-age cycles begin.")
    )
  )
)

# -----------------------------------------------------------------------------
# HOW THE CO2 WAS MEASURED
# -----------------------------------------------------------------------------
# One entry per data source (config.R: DATA_SOURCE_*), shown in the "About this
# era" window (CO2_MEASUREMENT_NOTES add a sentence for the eras that come from
# a particular part of a source). "How it works" has a short summary.

CO2_MEASUREMENT <- list(

  modern = list(
    title  = "Measured directly in the air",
    method = "Direct air measurements, Mauna Loa Observatory (Hawaii)",
    how = c(
      "Since March 1958, air has been drawn in high up on a tower at the Mauna Loa Observatory, 3,400 m up a Hawaiian volcano, and analysed for CO₂ around the clock – first with infrared gas analysers, today with laser instruments, all checked against reference gases of known CO₂ content.",
      "The site is far from cities and forests, so it samples well-mixed air. Hours affected by gas from the volcano or by plants on the island are filtered out. The app uses NOAA's monthly means."
    ),
    resolution = "monthly values",
    source = "NOAA Global Monitoring Laboratory (data before 1974: C. D. Keeling, Scripps Institution of Oceanography)",
    url = "https://gml.noaa.gov/ccgg/trends/"
  ),

  cmip7 = list(
    title  = "The CO₂ history climate models use",
    method = "CMIP7 historical CO₂: ice cores and firn air, then direct air measurements",
    how = c(
      "Before the late 1950s there were no reliable direct measurements, so the 1800s and early 1900s come from air trapped in Antarctic ice and in firn – the packed old snow above the ice – mostly from Law Dome, where so much snow falls that the record resolves single decades.",
      "From the late 1950s on, the record uses direct air measurements from monitoring stations all over the world (such as NOAA's network), combined into one global-mean value per year and smoothly joined to the ice-core part. This is the CO₂ the CMIP7 climate models – the next generation behind the IPCC reports – are run with.",
      "The record ends in 2022. For the years after, the app uses yearly means from Mauna Loa, lowered by ~1 ppm: Mauna Loa reads slightly above the global mean (most CO₂ is emitted in the north), so the app subtracts the average difference of the last ten years both records share."
    ),
    resolution = "yearly global means",
    source = "CMIP7 greenhouse-gas concentration forcing CR-CMIP-1-0-0 (Climate Resource; Nicholls et al. 2025); after 2022 NOAA Mauna Loa",
    url = "https://doi.org/10.5281/zenodo.14892947"
  ),

  icecore = list(
    title  = "Air bubbles trapped in Antarctic ice",
    method = "Air bubbles in Antarctic ice cores",
    how = c(
      "Snow that falls on Antarctica is slowly buried and pressed into ice. About 50 to 120 m down, the gaps between the snow grains close and seal off tiny bubbles of air – real samples of the atmosphere of the time.",
      "In the lab, pieces of the core are crushed, melted or evaporated in a vacuum and the CO₂ of the released air is measured. The ages come from counting yearly layers, from volcanic ash and dust layers that can be matched between cores, and from ice-flow models.",
      "Because the bubbles close slowly, each sample averages a few decades of air where lots of snow falls, and several centuries where little does – and the air is always younger than the ice around it."
    ),
    resolution = "decades to centuries per sample",
    source = "Bereiter et al. (2015): a composite of several Antarctic cores (among them Law Dome, WAIS Divide, EPICA Dome C and Vostok)",
    url = "https://doi.org/10.1002/2014GL061957"
  ),

  cenozoic = list(
    title  = "Chemical fingerprints in deep-sea mud",
    method = "Proxies in marine sediments (boron isotopes, alkenones)",
    how = c(
      "No ice is this old, so CO₂ is worked out from 'proxies' – chemical traces kept in the sediments on the sea floor.",
      "Boron isotopes: tiny plankton called foraminifera build their shells from seawater. The ratio of two boron isotopes in a shell records how acidic the surface ocean was, and from that – plus an estimate of the ocean's carbonate chemistry – the CO₂ of the air above it can be calculated.",
      "Alkenones: fat molecules made by microscopic algae (coccolithophores). How strongly the algae prefer the lighter carbon isotope during photosynthesis depends on how much CO₂ is dissolved in the water.",
      "These estimates are much less precise than ice-core measurements, and the uncertainty grows the further back you go. The app averages them into 100,000-year steps."
    ),
    resolution = "100,000-year averages (in this app)",
    source = "Rae et al. (2021), a compilation of boron-isotope and alkenone records",
    url = "https://doi.org/10.1146/annurev-earth-082420-063026"
  )
)

# Extra sentence for eras that use a particular part of a source
CO2_MEASUREMENT_NOTES <- c(
  roman   = "This era comes mostly from the Law Dome cores in East Antarctica. So much snow falls there that the bubbles close quickly, and the record shows changes of just a few decades.",
  lgm     = "The end of the ice age comes from the WAIS Divide core in West Antarctica – a high-snowfall site that shows the steps of the deglaciation in detail – and most of the Holocene from EPICA Dome C.",
  humans  = "Several Antarctic cores are stitched together here; in the older part each value averages a few centuries of air.",
  icecore = "The older part comes from EPICA Dome C and Vostok, high on the East Antarctic plateau: little snow, so each sample averages several centuries – but the ice reaches 800,000 years back."
)

# -----------------------------------------------------------------------------
# ACCESSORS
# -----------------------------------------------------------------------------

#' How the CO2 of a period was measured
#'
#' @param period_id Period id (names(TIME_PERIODS))
#' @return The CO2_MEASUREMENT entry of the period's data source (title,
#'   method, how, resolution, source, url) plus `note` (era-specific sentence
#'   or NULL); NULL for an unknown period
period_measurement <- function(period_id) {
  per <- TIME_PERIODS[[period_id]]
  if (is.null(per)) return(NULL)
  m <- CO2_MEASUREMENT[[per$data_source]]
  if (is.null(m)) return(NULL)
  note <- unname(CO2_MEASUREMENT_NOTES[period_id])
  m$note <- if (length(note) && !is.na(note)) note else NULL
  m
}

#' Background paragraphs for a period (character vector; empty if none)
period_context_text <- function(period_id) {
  PERIOD_CONTEXT[[period_id]]$context %||% character(0)
}

#' Key events for a period, ordered oldest -> youngest (the playback order).
#' Returns a data.frame(age, when, title, detail); zero rows if none.
period_key_events <- function(period_id) {
  ev <- PERIOD_CONTEXT[[period_id]]$key_events
  if (is.null(ev) || !nrow(ev)) {
    return(data.frame(age = numeric(0), when = character(0), title = character(0),
                      detail = character(0), stringsAsFactors = FALSE))
  }
  ev <- ev[order(-ev$age), , drop = FALSE]
  rownames(ev) <- NULL
  ev
}

#' Key events that fall inside a song's time window (either order of ages).
events_in_window <- function(period_id, start_age, end_age) {
  ev <- period_key_events(period_id)
  lo <- min(start_age, end_age)
  hi <- max(start_age, end_age)
  ev[ev$age >= lo & ev$age <= hi, , drop = FALSE]
}
