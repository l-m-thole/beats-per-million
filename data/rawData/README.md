# Raw data — sources & provenance

Raw inputs for the climate playlists. The processed file `../co2_data.xlsx` is
built from these by `data-raw/build_co2_data.R`.

| File | What it is | Used by |
|------|------------|---------|
| `co2_mm_mlo.csv` | Monthly mean atmospheric CO2 at Mauna Loa, 1958–present (the "Keeling Curve"). Refreshed from NOAA by `data-raw/update_maunaloa.R` (monthly GitHub Action). | Builds the `maunaloa` sheet → Modern playlist. |
| `co2_1750-2022.csv` | Annual global-mean atmospheric CO2, 1750–2022: CMIP7 historical greenhouse-gas concentration forcing (CR-CMIP-1-0-0, Climate Resource). From Martin, Oct 2026. | Builds the `cmip7` sheet (from 1850, + Mauna Loa after 2022) → Industrial playlist. |
| `rae2021co2.xlsx` | Cenozoic (0–66 Ma) CO2 from marine proxies: alkenone δ13C + boron δ11B. | Read directly by `load_rae2021_data()` → Cenozoic playlist. |
| `eggleston2016.xlsx` | Antarctic ice-core CO2 + carbon-isotope (δ13CO2) record, ~155 kyr (EDC / EDML / Talos cores). | **Not currently used** — kept as a reference dataset; overlaps the Bereiter record for 0–155 kyr. |

The 800 kyr ice-core composite (Bereiter et al. 2015) is stored *processed* in the
`bereiter2014` sheet of `../co2_data.xlsx`; there is no separate raw file here, and
that is intentional — the processed sheet is the source of record for the ice-core
playlists. `co2_data.xlsx` therefore holds three sheets: `maunaloa`, `cmip7` and `bereiter2014`
(the Cenozoic record is derived from `rae2021co2.xlsx` at run time, not cached).

## Sources

- **Mauna Loa CO2** — NOAA Global Monitoring Laboratory. https://gml.noaa.gov/ccgg/trends/data.html
- **CMIP7 CO2 (CR-CMIP-1-0-0)** — Nicholls, Z., Meinshausen, M., Pflüger, M. & Lewis, J. (2025) *CMIP GHG Forcing* (v1.0.0). Zenodo. https://doi.org/10.5281/zenodo.14892947
- **Rae et al. (2021)** — Atmospheric CO2 over the Past 66 Million Years from Marine Archives. *Annual Review of Earth and Planetary Sciences*, 49, 609–641. https://doi.org/10.1146/annurev-earth-082420-063026
- **Bereiter et al. (2015)** — Revision of the EPICA Dome C CO2 record from 800 to 600 kyr before present. *Geophysical Research Letters*, 42(2), 542–549. https://www.ncei.noaa.gov/access/paleo-search/
- **Eggleston et al. (2016)** — Evolution of the stable carbon isotope composition of atmospheric CO2 over the last glacial cycle. *Paleoceanography*. https://doi.org/10.1002/2015PA002874 · data: https://doi.org/10.1594/PANGAEA.859181
