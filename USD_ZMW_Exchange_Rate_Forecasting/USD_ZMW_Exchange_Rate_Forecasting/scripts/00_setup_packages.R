# =============================================================================
# 00_setup_packages.R
# Installs (if missing) and loads every package used in the project.
# Run once on a new machine; the master script also calls it.
# =============================================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

required_packages <- c(
  # Core data handling
  "tidyverse",   # dplyr, tidyr, readr, ggplot2, purrr, stringr, tibble
  "lubridate",   # dates
  "here",        # project-relative file paths
  "jsonlite",    # World Bank API (JSON)
  "zoo", "xts",  # time-series containers
  # Data retrieval
  "quantmod",    # Yahoo Finance fallback for USD/ZMW
  # Statistics and econometrics
  "moments",     # skewness, kurtosis, Jarque-Bera
  "tseries",     # ADF, KPSS
  "urca",        # ADF with trend/drift options, Zivot-Andrews
  "strucchange", # Bai-Perron structural breaks
  "forecast",    # ARIMA, accuracy, Diebold-Mariano
  "rugarch",     # GARCH
  "FinTS",       # ARCH-LM test
  "PerformanceAnalytics",
  "lmtest",      # Breusch-Godfrey, Breusch-Pagan, coeftest
  "sandwich",    # Newey-West HAC standard errors
  "car",         # VIF
  # Presentation
  "scales", "patchwork", "knitr", "rmarkdown"
)

install_if_missing <- function(pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing, dependencies = TRUE)
  }
  still_missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still_missing) > 0) {
    stop("These packages could not be installed: ",
         paste(still_missing, collapse = ", "),
         "\nInstall them manually with install.packages() and read the error message.",
         call. = FALSE)
  }
  invisible(TRUE)
}

install_if_missing(required_packages)
message("All ", length(required_packages), " required packages are installed.")
