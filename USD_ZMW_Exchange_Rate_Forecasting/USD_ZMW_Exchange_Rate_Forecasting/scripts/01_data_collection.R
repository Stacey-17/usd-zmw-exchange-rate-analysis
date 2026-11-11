# =============================================================================
# 01_data_collection.R
# -----------------------------------------------------------------------------
# PURPOSE
#   Retrieve every raw dataset used in the project, save it UNCHANGED to
#   data/raw/ with a date stamp, and log its provenance (source, URL,
#   retrieval time, coverage) to data/raw/data_provenance.csv.
#
#   No cleaning, aggregation or modelling happens here. The only
#   transformation is inverting ZMW-per-USD quotes where a source publishes
#   USD per ZMW, and that is recorded in the provenance notes.
#
# DATA (priority order for the exchange rate)
#   1. Bank of Zambia daily rates downloaded by YOU from boz.zm and pasted
#      into data/raw/manual/boz_usdzmw_daily.csv            (most authoritative)
#   2. Bank of Zambia daily rates via the Frankfurter API (providers=boz)
#   3. Yahoo Finance "ZMW=X" via quantmod                   (last resort)
#   Plus: FRED (copper, US CPI, Fed funds), World Bank WDI (annual context and
#   cross-check), and manual templates for Zambia CPI, BoZ policy rate and
#   international reserves.
#
# OUTPUTS
#   data/raw/fx_usdzmw_daily_<source>_<date>.csv     one file per FX source
#   data/raw/fx_usdzmw_daily_primary.csv             chosen primary FX series
#   data/raw/fred_<ID>_<date>.csv                    FRED series
#   data/raw/worldbank_zmb_annual_<date>.csv         World Bank indicators
#   data/raw/manual/*.csv                            templates / your files
#   data/raw/data_provenance.csv                     provenance log
#   outputs/tables/01_data_inventory.csv             summary of what was found
# =============================================================================

source(here::here("scripts", "utils.R"))
suppressPackageStartupMessages({
  library(tidyr)
  library(purrr)
  library(jsonlite)
})

log_msg("=== 01 DATA COLLECTION ===")
log_msg("Sample window: ", CONFIG$start_date, " to ", CONFIG$end_date)

# Collect a status line for every dataset; written to the inventory at the end.
inventory <- list()
add_inventory <- function(dataset, status, n_obs = NA, first = NA, last = NA, note = "") {
  inventory[[dataset]] <<- tibble(dataset = dataset, status = status, n_obs = n_obs,
                                  first_date = as.character(first),
                                  last_date = as.character(last), note = note)
}

# Infer frequency from the median gap between observations.
infer_frequency <- function(dates) {
  if (length(dates) < 3) return("unknown")
  gap <- median(as.numeric(diff(sort(unique(dates)))))
  if (gap <= 4) "daily" else if (gap <= 10) "weekly" else if (gap <= 40) "monthly" else "annual"
}

# =============================================================================
# SECTION 1. USD/ZMW EXCHANGE RATE
# =============================================================================

fx_sources <- list()   # each element: tibble(date, usd_zmw, source)

# ---- 1A. Manual Bank of Zambia file (preferred if you supply it) -------------
boz_manual_file <- file.path(PATHS$manual, "boz_usdzmw_daily.csv")

if (!file.exists(boz_manual_file)) {
  write_csv(tibble(date = character(), usd_zmw_mid = numeric(),
                   usd_zmw_buy = numeric(), usd_zmw_sell = numeric()),
            boz_manual_file)
  log_msg("Created empty template: ", boz_manual_file)
}

boz_manual <- tryCatch(
  read_csv(boz_manual_file, col_types = cols(date = col_date(), .default = col_double())),
  error = function(e) { log_msg("Could not read ", boz_manual_file, ": ", conditionMessage(e), level = "WARN"); NULL }
)

if (!is.null(boz_manual) && nrow(boz_manual) > 0) {
  if (!"usd_zmw_mid" %in% names(boz_manual) || all(is.na(boz_manual$usd_zmw_mid))) {
    stop("boz_usdzmw_daily.csv has rows but no 'usd_zmw_mid' values. ",
         "Use the column names in the template (date, usd_zmw_mid, ...).", call. = FALSE)
  }
  fx_sources$boz_manual <- boz_manual %>%
    filter(!is.na(date), !is.na(usd_zmw_mid)) %>%
    transmute(date, usd_zmw = usd_zmw_mid, source = "Bank of Zambia (manual download)")
  log_msg("Manual BoZ file found: ", nrow(fx_sources$boz_manual), " rows.")
} else {
  log_msg("Manual BoZ file is empty - will rely on automated sources.")
}

# ---- 1B. Frankfurter API: Bank of Zambia rates --------------------------------
# The API republishes BoZ reference rates. Base = ZMW is requested and the rate
# is inverted to obtain ZMW per USD. Data are requested one calendar year at a
# time to keep each response small.
get_frankfurter_boz_year <- function(year) {
  from <- max(as.Date(sprintf("%d-01-01", year)), CONFIG$start_date)
  to   <- min(as.Date(sprintf("%d-12-31", year)), CONFIG$end_date)
  url  <- sprintf(
    "https://api.frankfurter.dev/v2/rates.csv?base=zmw&quotes=usd&providers=boz&from=%s&to=%s",
    from, to)
  tmp <- tempfile(fileext = ".csv")
  if (!safe_download(url, tmp)) return(NULL)
  out <- tryCatch(read_csv(tmp, show_col_types = FALSE), error = function(e) NULL)
  if (is.null(out) || nrow(out) == 0) return(NULL)
  names(out) <- tolower(names(out))
  needed <- c("date", "base", "quote", "rate")
  if (!all(needed %in% names(out))) {
    log_msg("Unexpected Frankfurter columns: ", paste(names(out), collapse = ", "), level = "WARN")
    return(NULL)
  }
  out %>% select(all_of(needed)) %>% mutate(date = as.Date(date), rate = as.numeric(rate))
}

years <- seq(year(CONFIG$start_date), year(CONFIG$end_date))
log_msg("Requesting BoZ rates from the Frankfurter API for ", min(years), "-", max(years), " ...")
fk_list <- list()
for (yr in years) {
  res <- get_frankfurter_boz_year(yr)
  # If the very first request fails the service is unreachable: stop trying
  # rather than waiting through every remaining year.
  if (is.null(res) && length(fk_list) == 0 && yr == years[1]) {
    log_msg("First Frankfurter request failed; skipping remaining years.", level = "WARN")
    break
  }
  if (is.null(res)) log_msg("No Frankfurter data for ", yr, level = "WARN")
  fk_list[[as.character(yr)]] <- res
}
fk_raw <- bind_rows(fk_list)

if (nrow(fk_raw) > 0) {
  fk_file <- file.path(PATHS$raw, sprintf("fx_frankfurter_boz_raw_%s.csv", stamp()))
  write_csv(fk_raw, fk_file)          # raw response, untouched

  fk <- fk_raw %>%
    filter(toupper(base) == "ZMW", toupper(quote) == "USD", rate > 0) %>%
    distinct(date, .keep_all = TRUE) %>%
    arrange(date) %>%
    transmute(date, usd_zmw = 1 / rate, source = "Bank of Zambia via Frankfurter API")

  fk_freq <- infer_frequency(fk$date)
  if (fk_freq != "daily") {
    log_msg("Frankfurter returned ", fk_freq, " data, not daily. Monthly averages ",
            "cannot be verified; prefer the manual BoZ download.", level = "WARN")
  }
  fx_sources$frankfurter <- fk
  record_provenance(
    dataset = "usd_zmw_frankfurter_boz", source = "Bank of Zambia (via api.frankfurter.dev)",
    url = "https://api.frankfurter.dev/v2/rates.csv?base=zmw&quotes=usd&providers=boz&from=YYYY-01-01&to=YYYY-12-31",
    file = fk_file, n_obs = nrow(fk), first_date = min(fk$date), last_date = max(fk$date),
    frequency = fk_freq, notes = "Published as USD per ZMW; inverted to ZMW per USD (1/rate).")
  log_msg("Frankfurter/BoZ: ", nrow(fk), " observations (", fk_freq, ").")
} else {
  log_msg("Frankfurter API unavailable or returned no data.", level = "WARN")
}

# ---- 1C. Yahoo Finance fallback (quantmod) ------------------------------------
# Used ONLY if neither BoZ route works. Yahoo's ZMW=X is a vendor composite,
# not an official BoZ rate, and is known to contain stale prints and gaps.
if (length(fx_sources) == 0) {
  log_msg("Trying Yahoo Finance (ZMW=X) as a last resort ...")
  yh <- tryCatch({
    x <- quantmod::getSymbols("ZMW=X", src = "yahoo", from = CONFIG$start_date,
                              to = CONFIG$end_date + 1, auto.assign = FALSE)
    tibble(date = as.Date(zoo::index(x)), usd_zmw = as.numeric(quantmod::Cl(x)))
  }, error = function(e) { log_msg("Yahoo failed: ", conditionMessage(e), level = "WARN"); NULL })

  if (!is.null(yh) && nrow(yh) > 0) {
    yh <- yh %>% filter(!is.na(usd_zmw), usd_zmw > 0) %>%
      mutate(source = "Yahoo Finance ZMW=X (vendor composite)")
    yh_file <- file.path(PATHS$raw, sprintf("fx_yahoo_zmw_daily_%s.csv", stamp()))
    write_csv(yh, yh_file)
    fx_sources$yahoo <- yh
    record_provenance(
      dataset = "usd_zmw_yahoo", source = "Yahoo Finance via quantmod",
      url = "https://finance.yahoo.com/quote/ZMW%3DX/history", file = yh_file,
      n_obs = nrow(yh), first_date = min(yh$date), last_date = max(yh$date),
      frequency = infer_frequency(yh$date),
      notes = "Daily close. NOT an official BoZ rate - use only if BoZ data unavailable.")
  }
}

# ---- 1D. Choose the primary FX series -----------------------------------------
priority <- c("boz_manual", "frankfurter", "yahoo")
primary_name <- priority[priority %in% names(fx_sources)][1]

if (is.na(primary_name)) {
  stop(
    "\nNo USD/ZMW data could be obtained.\n",
    "Fix: download daily rates from the Bank of Zambia website and paste them into\n  ",
    boz_manual_file, "\nusing columns: date (YYYY-MM-DD), usd_zmw_mid. Then re-run this script.",
    call. = FALSE)
}

fx_primary <- fx_sources[[primary_name]] %>%
  filter(date >= CONFIG$start_date, date <= CONFIG$end_date) %>%
  arrange(date)

primary_file <- file.path(PATHS$raw, "fx_usdzmw_daily_primary.csv")
write_csv(fx_primary, primary_file)
if (primary_name == "boz_manual") {
  record_provenance(
    dataset = "usd_zmw_boz_manual", source = "Bank of Zambia (manual download by author)",
    url = "https://www.boz.zm/ (Statistics section - exchange rates)",
    file = boz_manual_file, n_obs = nrow(fx_primary),
    first_date = min(fx_primary$date), last_date = max(fx_primary$date),
    frequency = infer_frequency(fx_primary$date),
    notes = "Mid rate. Record your download date in the README.")
}
log_msg("PRIMARY FX SOURCE: ", unique(fx_primary$source), " (", nrow(fx_primary), " rows)")
add_inventory("USD/ZMW (primary)", "OK", nrow(fx_primary),
              min(fx_primary$date), max(fx_primary$date), unique(fx_primary$source))

# ---- 1E. Cross-check between FX sources (if more than one) --------------------
if (length(fx_sources) > 1) {
  cmp <- bind_rows(fx_sources) %>%
    group_by(source, month = floor_date(date, "month")) %>%
    summarise(avg = mean(usd_zmw), .groups = "drop") %>%
    pivot_wider(names_from = source, values_from = avg) %>%
    drop_na()
  if (nrow(cmp) > 0) {
    v <- as.matrix(cmp[, -1])
    max_pct_diff <- max(abs(v[, 1] / v[, 2] - 1)) * 100
    log_msg(sprintf("Cross-source check: max monthly-average difference = %.2f%% over %d months.",
                    max_pct_diff, nrow(cmp)))
    write_csv(cmp, file.path(PATHS$tables, "01_fx_source_crosscheck.csv"))
  }
}

# =============================================================================
# SECTION 2. FRED SERIES (copper, US CPI, US policy rate)
# =============================================================================
fred_series <- tribble(
  ~id,          ~name,                 ~description,
  "PCOPPUSDM",  "copper_usd_tonne",    "Global price of Copper, USD per metric ton (IMF), monthly",
  "CPIAUCSL",   "us_cpi",              "US CPI-U all items, index 1982-84=100, SA, monthly (BLS)",
  "FEDFUNDS",   "us_fed_funds_pct",    "US effective federal funds rate, percent, monthly (Fed)"
)

get_fred <- function(id, name, description) {
  url  <- sprintf("https://fred.stlouisfed.org/graph/fredgraph.csv?id=%s&cosd=%s",
                  id, CONFIG$start_date - years(2))   # 2 extra years for lags / YoY
  file <- file.path(PATHS$raw, sprintf("fred_%s_%s.csv", id, stamp()))
  if (!safe_download(url, file)) {
    add_inventory(name, "FAILED", note = paste("FRED download failed:", id))
    return(NULL)
  }
  df <- tryCatch(read_csv(file, na = c(".", "", "NA"), show_col_types = FALSE),
                 error = function(e) NULL)
  if (is.null(df) || ncol(df) < 2) {
    add_inventory(name, "FAILED", note = "Unreadable FRED file"); return(NULL)
  }
  # FRED's date column is 'observation_date' (older files: 'DATE')
  df <- df %>% rename(date = 1, value = 2) %>%
    mutate(date = as.Date(date), value = as.numeric(value)) %>%
    filter(!is.na(value))
  record_provenance(
    dataset = name, source = paste("FRED, Federal Reserve Bank of St. Louis:", id),
    url = url, file = file, n_obs = nrow(df), first_date = min(df$date),
    last_date = max(df$date), frequency = infer_frequency(df$date), notes = description)
  add_inventory(name, "OK", nrow(df), min(df$date), max(df$date), paste("FRED", id))
  log_msg("FRED ", id, ": ", nrow(df), " obs, ", min(df$date), " to ", max(df$date))
  df
}
fred_data <- pmap(fred_series, get_fred)

# =============================================================================
# SECTION 3. WORLD BANK WDI (annual; context and FX cross-validation)
# =============================================================================
wb_indicators <- tribble(
  ~code,                 ~name,
  "PA.NUS.FCRF",         "Official exchange rate (LCU per US$, period average)",
  "FP.CPI.TOTL.ZG",      "Inflation, consumer prices (annual %)",
  "NY.GDP.MKTP.KD.ZG",   "GDP growth (annual %)",
  "FI.RES.TOTL.CD",      "Total reserves including gold (current US$)",
  "FR.INR.LEND",         "Lending interest rate (%)"
)

get_wb <- function(code, name) {
  url <- sprintf(
    "https://api.worldbank.org/v2/country/ZMB/indicator/%s?format=json&per_page=200&date=%d:%d",
    code, year(CONFIG$start_date) - 3, year(Sys.Date()))
  tmp <- tempfile(fileext = ".json")
  if (!safe_download(url, tmp)) return(NULL)
  js <- tryCatch(fromJSON(tmp, flatten = TRUE), error = function(e) NULL)
  if (is.null(js) || length(js) < 2 || is.null(js[[2]])) return(NULL)
  tibble(indicator_code = code, indicator_name = name,
         year = as.integer(js[[2]]$date), value = as.numeric(js[[2]]$value)) %>%
    arrange(year)
}

log_msg("Downloading World Bank WDI indicators for Zambia ...")
wb <- pmap(wb_indicators, get_wb) %>% compact() %>% bind_rows()

if (nrow(wb) > 0) {
  wb_file <- file.path(PATHS$raw, sprintf("worldbank_zmb_annual_%s.csv", stamp()))
  write_csv(wb, wb_file)
  wb_ok <- wb %>% filter(!is.na(value))
  record_provenance(
    dataset = "worldbank_wdi_zambia", source = "World Bank, World Development Indicators API",
    url = "https://api.worldbank.org/v2/country/ZMB/indicator/{code}?format=json",
    file = wb_file, n_obs = nrow(wb_ok), first_date = min(wb_ok$year),
    last_date = max(wb_ok$year), frequency = "annual",
    notes = paste("Indicators:", paste(unique(wb$indicator_code), collapse = ", "),
                  "- latest years may be missing (publication lag)."))
  add_inventory("World Bank WDI (annual)", "OK", nrow(wb_ok), min(wb_ok$year), max(wb_ok$year),
                paste(length(unique(wb_ok$indicator_code)), "indicators"))
  # Show missing indicator-years explicitly
  wb_missing <- wb %>% filter(is.na(value)) %>% count(indicator_code, name = "missing_years")
  if (nrow(wb_missing) > 0) print(wb_missing)
} else {
  add_inventory("World Bank WDI (annual)", "FAILED", note = "API unavailable")
}

# =============================================================================
# SECTION 4. MANUAL MACRO SERIES (Zambia CPI, BoZ policy rate, reserves)
# =============================================================================
# No reliable free API currently provides these at monthly frequency for
# Zambia, so they are entered by hand from the official publications listed
# in data/raw/manual/README_manual_data.md. Templates are created on first run.

manual_specs <- list(
  zambia_cpi = list(
    file = "zambia_cpi_monthly.csv",
    cols = c("date", "cpi_index", "inflation_yoy_pct", "source_note"),
    date_col = "date",
    source = "Zambia Statistics Agency (ZamStats) Monthly Bulletin",
    url = "https://www.zamstats.gov.zm/"),
  policy_rate = list(
    file = "boz_policy_rate.csv",
    cols = c("effective_date", "policy_rate_pct", "source_note"),
    date_col = "effective_date",
    source = "Bank of Zambia Monetary Policy Committee statements",
    url = "https://www.boz.zm/",
    frequency = "event-based (rate changes only)"),
  reserves = list(
    file = "zambia_reserves_monthly.csv",
    cols = c("date", "gross_reserves_usd_mn", "source_note"),
    date_col = "date",
    source = "Bank of Zambia statistics / IMF International Reserves template",
    url = "https://www.boz.zm/")
)

for (nm in names(manual_specs)) {
  spec <- manual_specs[[nm]]
  path <- file.path(PATHS$manual, spec$file)
  if (!file.exists(path)) {
    write_csv(as_tibble(setNames(rep(list(character()), length(spec$cols)), spec$cols)), path)
    log_msg("Created empty template: ", path)
  }
  df <- tryCatch(read_csv(path, col_types = cols(.default = col_character())),
                 error = function(e) NULL)
  if (is.null(df) || nrow(df) == 0) {
    add_inventory(nm, "MISSING - manual entry needed", note = spec$file)
    log_msg(nm, ": template is empty. Regression in script 08 will run without it.",
            level = "WARN")
    next
  }
  missing_cols <- setdiff(spec$cols[spec$cols != "source_note"], names(df))
  if (length(missing_cols) > 0) {
    add_inventory(nm, "INVALID", note = paste("Missing columns:", paste(missing_cols, collapse = ", ")))
    next
  }
  d <- suppressWarnings(as.Date(df[[spec$date_col]]))
  if (any(is.na(d))) {
    add_inventory(nm, "INVALID", note = paste(sum(is.na(d)), "unparseable dates - use YYYY-MM-DD"))
    next
  }
  record_provenance(dataset = nm, source = spec$source, url = spec$url, file = path,
                    n_obs = nrow(df), first_date = min(d), last_date = max(d),
                    frequency = if (!is.null(spec$frequency)) spec$frequency else infer_frequency(d),
                    notes = "Manually entered by author")
  add_inventory(nm, "OK", nrow(df), min(d), max(d), spec$source)
}

# =============================================================================
# SECTION 5. INVENTORY
# =============================================================================
inventory_tbl <- bind_rows(inventory)
write_csv(inventory_tbl, file.path(PATHS$tables, "01_data_inventory.csv"))

cat("\n================ DATA INVENTORY ================\n")
print(inventory_tbl, n = Inf, width = Inf)
cat("\nProvenance log: ", PATHS$provenance, "\n")
log_msg("=== 01 DATA COLLECTION COMPLETE ===")
