# Script 01: Data Collection

## 1. Purpose

This script gathers every raw input the project needs, saves each one **unchanged** with a date stamp, and writes a provenance log. Later scripts never download anything; they read only from `data/raw/`. Keeping raw data separate from processed data means a reviewer can audit exactly what came from where.

## 2. Statistical and data concepts

* **Provenance and reproducibility.** A forecast is only as credible as its inputs. Logging the URL, retrieval time and coverage of every series lets someone else rebuild the dataset, and is what makes the "no fabricated data" claim verifiable.
* **Source hierarchy.** Official central-bank data is preferred to vendor composites. Yahoo's `ZMW=X` aggregates dealer quotes, can contain stale prints, and is not what Zambian contracts settle on, so it is used only if both BoZ routes fail.
* **Daily before monthly.** Daily data are collected even though the analysis is monthly, because (a) the monthly *average* and *end-of-month* series can both be built from them, (b) data-quality checks need daily resolution, and (c) a daily GARCH robustness check becomes possible.
* **Quote convention.** All rates are stored as ZMW per USD. Where a source quotes USD per ZMW, the script takes `1/rate` and records this in the provenance notes.
* **Frequency mismatch.** World Bank series are annual. They are used for context and to cross-check the annual average of the monthly FX series, never as monthly regressors (interpolating annual data to monthly would create artificial smoothness and spurious correlation).

## 3. How to run it in RStudio

1. Open `USD_ZMW_Exchange_Rate_Forecasting.Rproj` (File → Open Project).
2. First time only: `source("scripts/00_setup_packages.R")`. `rugarch` and `tidyverse` take several minutes to install.
3. Run `source("scripts/01_data_collection.R")`, or open the file and press **Ctrl+Shift+S** (Cmd+Shift+S on Mac).

On the first run the script creates empty templates in `data/raw/manual/`. Fill them from the official publications (instructions in `data/raw/manual/README_manual_data.md`) and run the script again. The project still runs without them; the regression in script 08 then uses only the variables that are available.

## 4. Expected outputs

| File | Content |
|---|---|
| `data/raw/fx_frankfurter_boz_raw_<date>.csv` | API response exactly as received |
| `data/raw/fx_usdzmw_daily_primary.csv` | Daily ZMW-per-USD series from the highest-priority available source |
| `data/raw/fred_<ID>_<date>.csv` | Copper, US CPI, Fed funds |
| `data/raw/worldbank_zmb_annual_<date>.csv` | Five WDI indicators for Zambia |
| `data/raw/data_provenance.csv` | One row per dataset: source, URL, retrieval time, coverage |
| `outputs/tables/01_data_inventory.csv` | Status of every dataset (OK / FAILED / MISSING) |
| `outputs/tables/01_fx_source_crosscheck.csv` | Monthly averages from each FX source side by side (only if you supply the manual BoZ file) |

The console ends with a **DATA INVENTORY** table.

## 5. How to interpret the results

* **USD/ZMW (primary)** should show about 250 business days per year since January 2013, so roughly 3,400+ rows. A much lower count means the source returned monthly rather than daily data (the script warns you) or has gaps; script 02 quantifies these.
* **Frequency = daily** in the provenance log is what you want for the FX series. If it says `monthly`, the provider aggregated the data and you cannot confirm whether the values are averages or end-of-period figures. Supply the manual BoZ file in that case.
* **Cross-source check.** If you supply the manual BoZ file, a maximum monthly difference below about 0.5% confirms that the API reproduces BoZ's rates. Larger gaps usually mean one source uses buying/selling rates and the other uses mid rates; check before proceeding.
* **World Bank `n_obs`.** Recent years are often `NA` because of the publication lag. This is normal and is printed explicitly.
* **MISSING - manual entry needed** is a to-do, not an error.

## 6. Common errors and fixes

| Message | Cause | Fix |
|---|---|---|
| `there is no package called 'here'` (or any package) | Packages not installed | `source("scripts/00_setup_packages.R")` |
| `cannot open file '.../scripts/utils.R'` | Working directory is not the project root | Open the `.Rproj` file instead of the script alone; check with `here::here()` |
| `First Frankfurter request failed` | No internet, firewall/proxy, or service down | Check your connection; on a corporate network try `options(download.file.method = "wininet")` on Windows; otherwise use the manual BoZ file |
| `No USD/ZMW data could be obtained` | All three FX sources failed | Fill `boz_usdzmw_daily.csv` manually and re-run |
| `boz_usdzmw_daily.csv has rows but no 'usd_zmw_mid' values` | Column renamed while pasting | Keep the template's header row exactly |
| `INVALID ... unparseable dates` | Dates typed as `03/01/2019` or Excel serial numbers | Format the date column as `YYYY-MM-DD` before saving as CSV |
| Yahoo returns data but with long flat stretches | Stale vendor quotes | Do not use Yahoo for the final analysis; obtain BoZ data |
| FRED download fails while other sources work | FRED temporarily rate-limits | Wait a minute and re-run; the script overwrites only that day's files |

## Next step

Script **02_data_cleaning.R** will: check gaps, duplicates and outlier jumps in the daily series; build the monthly-average and end-of-month series; compute log returns; cross-check annual averages against the World Bank's `PA.NUS.FCRF`; align and transform the macro series (inflation differential, interest differential, Δlog copper, Δlog reserves); and save `data/processed/usdzmw_monthly.csv` and `data/processed/analysis_dataset.csv`.
