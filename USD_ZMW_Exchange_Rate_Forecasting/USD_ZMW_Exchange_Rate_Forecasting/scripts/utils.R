# =============================================================================
# utils.R
# Shared settings and helper functions, sourced by every numbered script.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(lubridate)
})

# ---- Project settings -------------------------------------------------------
# Sample starts after the 1 January 2013 kwacha rebasing (ZMK 1000 = ZMW 1).
CONFIG <- list(
  start_date   = as.Date("2013-01-01"),
  # End = last day of the last COMPLETE month before today.
  end_date     = floor_date(Sys.Date(), "month") - days(1),
  test_months  = 24,                 # length of chronological test set
  horizons     = c(1, 3, 6, 12),     # forecast / simulation horizons (months)
  n_sims       = 10000,              # Monte Carlo paths
  seed         = 20131
)

# ---- Paths (relative to the project root, located via the .Rproj file) ------
PATHS <- list(
  raw        = here("data", "raw"),
  manual     = here("data", "raw", "manual"),
  processed  = here("data", "processed"),
  figures    = here("outputs", "figures"),
  tables     = here("outputs", "tables"),
  report     = here("report"),
  provenance = here("data", "raw", "data_provenance.csv")
)
invisible(lapply(PATHS[c("raw", "manual", "processed", "figures", "tables", "report")],
                 dir.create, recursive = TRUE, showWarnings = FALSE))

# ---- Logging ----------------------------------------------------------------
log_msg <- function(..., level = "INFO") {
  message(sprintf("[%s] %s: %s", format(Sys.time(), "%H:%M:%S"), level, paste0(...)))
}

# ---- Robust download with retries -------------------------------------------
# Returns TRUE on success, FALSE on failure (never stops the script).
safe_download <- function(url, destfile, tries = 3, wait = 3) {
  for (i in seq_len(tries)) {
    ok <- tryCatch({
      utils::download.file(url, destfile, mode = "wb", quiet = TRUE, method = "libcurl")
      file.exists(destfile) && file.info(destfile)$size > 0
    }, error = function(e) {
      log_msg("Attempt ", i, " failed for ", url, " -> ", conditionMessage(e), level = "WARN")
      FALSE
    }, warning = function(w) {
      log_msg("Attempt ", i, " warning for ", url, " -> ", conditionMessage(w), level = "WARN")
      FALSE
    })
    if (isTRUE(ok)) return(TRUE)
    Sys.sleep(wait)
  }
  FALSE
}

# ---- Provenance log ---------------------------------------------------------
# Appends one row per dataset retrieved. This file documents where every
# number in the project came from and when it was downloaded.
record_provenance <- function(dataset, source, url, file, n_obs,
                              first_date, last_date, frequency, notes = "") {
  row <- tibble(
    dataset       = dataset,
    source        = source,
    url           = url,
    local_file    = basename(file),
    retrieved_at  = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    frequency     = frequency,
    n_obs         = n_obs,
    first_date    = as.character(first_date),
    last_date     = as.character(last_date),
    notes         = notes
  )
  if (file.exists(PATHS$provenance)) {
    old <- read_csv(PATHS$provenance, col_types = cols(.default = col_character()))
    # Keep only the latest record for each dataset
    old <- filter(old, .data$dataset != !!dataset)
    row <- bind_rows(old, mutate(row, across(everything(), as.character)))
  }
  write_csv(row, PATHS$provenance)
  invisible(row)
}

# Date stamp for raw file names, e.g. "20261111"
stamp <- function() format(Sys.Date(), "%Y%m%d")
