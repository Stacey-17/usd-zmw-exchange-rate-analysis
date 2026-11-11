# Manually entered data

Some series have no reliable free API for Zambia at monthly frequency. Enter them here from the official publication, then re-run `scripts/01_data_collection.R`. Empty templates are created automatically on the first run.

**Rules**

* Dates as `YYYY-MM-DD`. For monthly data use the first day of the month (`2019-03-01`).
* One row per observation. Leave a value blank if it was not published; never estimate it.
* Use `source_note` to record the publication (e.g. "ZamStats Monthly Bulletin, Vol. 252, Mar 2024, Table 1") and the date you accessed it.
* Do not reformat numbers with thousands separators.

## 1. `boz_usdzmw_daily.csv`: Bank of Zambia exchange rates (optional but recommended)

| column | meaning |
|---|---|
| `date` | business day |
| `usd_zmw_mid` | BoZ mid / average rate, ZMW per USD (**required**) |
| `usd_zmw_buy`, `usd_zmw_sell` | optional |

Source: Bank of Zambia website, www.boz.zm, Statistics section, exchange rates. BoZ publishes historical daily rates as downloadable spreadsheets. Copy the USD rows from January 2013 onward into this template. If this file contains data it **takes priority** over the automated download.

## 2. `zambia_cpi_monthly.csv`: Zambia consumer prices

| column | meaning |
|---|---|
| `date` | month (first day) |
| `cpi_index` | All-items CPI index level (state the base year in `source_note`) |
| `inflation_yoy_pct` | annual (12-month) inflation rate, % |

Source: Zambia Statistics Agency (www.zamstats.gov.zm), *Monthly Bulletin*. Bank of Zambia's statistics also reproduce annual inflation. Either column may be filled; script 08 uses `inflation_yoy_pct` if the index is missing. The CPI base year has been revised during the sample, so if you mix bases, note the change in `source_note`. Script 02 will chain-link them.

## 3. `boz_policy_rate.csv`: Monetary Policy Rate

| column | meaning |
|---|---|
| `effective_date` | date the new rate took effect |
| `policy_rate_pct` | the Policy Rate, % |

Enter **only the dates the rate changed** (plus its level at January 2013). Script 02 carries each value forward to build a monthly series. Source: Bank of Zambia Monetary Policy Committee statements (www.boz.zm, Monetary Policy section).

## 4. `zambia_reserves_monthly.csv`: Gross international reserves

| column | meaning |
|---|---|
| `date` | month (first day), end-of-month stock |
| `gross_reserves_usd_mn` | gross international reserves, US$ million |

Source: Bank of Zambia statistics (Fortnightly/Monthly statistics releases) or IMF *International Reserves and Foreign Currency Liquidity* data for Zambia (data.imf.org). If only the "months of import cover" figure is available, do not convert it; leave this file empty and note it in the report.
