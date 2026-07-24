# Raw data — sources & provenance

Raw inputs for the climate playlists. The processed file `../co2_data.xlsx` is
built from these by `data-raw/build_co2_data.R`.

| File | What it is | Used by |
|------|------------|---------|
| `co2_mm_mlo.csv` | Monthly mean atmospheric CO2 at Mauna Loa, 1958–present (the "Keeling Curve"). | Builds the `maunaloa` sheet → Modern playlist. |
| `rae2021co2.xlsx` | Cenozoic (0–66 Ma) CO2 from marine proxies: alkenone δ13C + boron δ11B. | Read directly by `load_rae2021_data()` → Cenozoic playlist. |
| `eggleston2016.xlsx` | Antarctic ice-core CO2 + carbon-isotope (δ13CO2) record, ~155 kyr (EDC / EDML / Talos cores). | **Not currently used** — kept as a reference dataset; overlaps the Bereiter record for 0–155 kyr. |

The 800 kyr ice-core composite (Bereiter et al. 2015) is stored *processed* in the
`bereiter2014` sheet of `../co2_data.xlsx`; there is no separate raw file here, and
that is intentional — the processed sheet is the source of record for the ice-core
playlists. `co2_data.xlsx` therefore holds two sheets: `maunaloa` and `bereiter2014`
(the Cenozoic record is derived from `rae2021co2.xlsx` at run time, not cached).

## Sources

- **Mauna Loa CO2** — NOAA Global Monitoring Laboratory. https://gml.noaa.gov/ccgg/trends/data.html
- **Rae et al. (2021)** — Atmospheric CO2 over the Past 66 Million Years from Marine Archives. *Annual Review of Earth and Planetary Sciences*, 49, 609–641. https://doi.org/10.1146/annurev-earth-082420-063026
- **Bereiter et al. (2015)** — Revision of the EPICA Dome C CO2 record from 800 to 600 kyr before present. *Geophysical Research Letters*, 42(2), 542–549. https://www.ncei.noaa.gov/access/paleo-search/
- **Eggleston et al. (2016)** — Evolution of the stable carbon isotope composition of atmospheric CO2 over the last glacial cycle. *Paleoceanography*. https://doi.org/10.1002/2015PA002874 · data: https://doi.org/10.1594/PANGAEA.859181
