# =============================================================================
# 00_master.R
# Runs the whole project in order. Open USD_ZMW_Exchange_Rate_Forecasting.Rproj
# in RStudio first, then run: source("scripts/00_master.R")
#
# Scripts not yet written are skipped with a message, so this file works at
# every stage of the project.
# =============================================================================

source(here::here("scripts", "00_setup_packages.R"))

pipeline <- c(
  "01_data_collection.R",
  "02_data_cleaning.R",
  "03_exploratory_analysis.R",
  "04_stationarity_testing.R",
  "05_arima_forecasting.R",
  "06_garch_volatility.R",
  "07_monte_carlo_simulation.R",
  "08_macroeconomic_regression.R",
  "09_model_evaluation.R",
  "10_visualisation.R"
)

run_log <- data.frame(script = pipeline, status = NA_character_, seconds = NA_real_)

for (i in seq_along(pipeline)) {
  path <- here::here("scripts", pipeline[i])
  if (!file.exists(path)) {
    message(">> Skipping ", pipeline[i], " (not yet created)")
    run_log$status[i] <- "not present"
    next
  }
  message("\n>> Running ", pipeline[i])
  t0 <- Sys.time()
  # Each script runs in its own environment so objects cannot leak between steps;
  # scripts communicate only through files in data/processed and outputs/.
  res <- tryCatch({
    sys.source(path, envir = new.env(parent = globalenv()))
    "ok"
  }, error = function(e) {
    message("!! ERROR in ", pipeline[i], ": ", conditionMessage(e))
    "error"
  })
  run_log$status[i]  <- res
  run_log$seconds[i] <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  if (res == "error") {
    message("Pipeline stopped. Fix the error above and re-run.")
    break
  }
}

print(run_log)
