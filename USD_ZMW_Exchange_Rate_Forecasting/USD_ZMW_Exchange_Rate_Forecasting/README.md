# Modelling and Forecasting the USD/ZMW Exchange Rate

### A Time-Series Econometric and Stochastic Simulation Approach

An end-to-end quantitative research project in R that studies the Zambian kwacha against the US dollar from January 2013 (post-rebasing) to the latest complete month. It covers exploratory analysis, stationarity testing, ARIMA forecasting against a random-walk benchmark, GARCH volatility modelling, Monte Carlo scenario generation and macroeconomic regression.

> **Status:** in progress. Built stage by stage; see the checklist below.

## Research objectives

1. Describe the historical behaviour of USD/ZMW.
2. Characterise its statistical properties and volatility.
3. Test whether past observations help forecast future movements.
4. Assess ARIMA models against a random-walk benchmark.
5. Assess whether GARCH captures kwacha volatility clustering.
6. Generate probabilistic 1–12-month scenarios by Monte Carlo simulation.
7. Draw implications for businesses, investors and financial institutions in Zambia.

Full design: [`report/00_research_methodology.md`](report/00_research_methodology.md)

## Project structure

```
USD_ZMW_Exchange_Rate_Forecasting/
├── USD_ZMW_Exchange_Rate_Forecasting.Rproj   # open this in RStudio
├── README.md
├── data/
│   ├── raw/                     # untouched downloads + data_provenance.csv
│   │   └── manual/              # hand-entered official series (templates)
│   └── processed/               # cleaned monthly analysis dataset
├── scripts/
│   ├── 00_setup_packages.R      # installs/loads packages
│   ├── 00_master.R              # runs the full pipeline in order
│   ├── utils.R                  # settings, paths, helpers
│   ├── 01_data_collection.R
│   ├── 02_data_cleaning.R
│   ├── 03_exploratory_analysis.R
│   ├── 04_stationarity_testing.R
│   ├── 05_arima_forecasting.R
│   ├── 06_garch_volatility.R
│   ├── 07_monte_carlo_simulation.R
│   ├── 08_macroeconomic_regression.R
│   ├── 09_model_evaluation.R
│   └── 10_visualisation.R
├── outputs/
│   ├── figures/
│   └── tables/
├── report/
└── docs/                        # per-script guides
```

## How to reproduce

1. Install R (≥ 4.2) and RStudio.
2. Open `USD_ZMW_Exchange_Rate_Forecasting.Rproj`. This sets the working directory to the project root.
3. (Recommended) Download Bank of Zambia daily rates and paste them into `data/raw/manual/boz_usdzmw_daily.csv`. See `data/raw/manual/README_manual_data.md`.
4. Run, in the console:
   ```r
   source("scripts/00_master.R")
   ```

## Data sources

| Series | Source | Access |
|---|---|---|
| USD/ZMW daily rate | Bank of Zambia | Manual download (preferred) or Frankfurter API (`providers=boz`) |
| USD/ZMW fallback | Yahoo Finance `ZMW=X` | `quantmod` |
| Copper price | IMF via FRED `PCOPPUSDM` | Automated |
| US CPI | BLS via FRED `CPIAUCSL` | Automated |
| US Fed funds rate | Federal Reserve via FRED `FEDFUNDS` | Automated |
| Zambia annual macro, official FX | World Bank WDI | Automated |
| Zambia CPI | Zambia Statistics Agency | Manual |
| BoZ Policy Rate | Bank of Zambia MPC statements | Manual |
| Gross international reserves | Bank of Zambia / IMF | Manual |

Exact URLs, retrieval timestamps and coverage for every file are logged in `data/raw/data_provenance.csv`. No observation in this repository is simulated or estimated except where explicitly labelled as Monte Carlo output.

## Progress

- [x] Research methodology
- [x] 01 Data collection
- [ ] 02 Data cleaning
- [ ] 03 Exploratory analysis
- [ ] 04 Stationarity testing
- [ ] 05 ARIMA forecasting
- [ ] 06 GARCH volatility
- [ ] 07 Monte Carlo simulation
- [ ] 08 Macroeconomic regression
- [ ] 09 Model evaluation
- [ ] 10 Visualisation
- [ ] Research report

## Author

Stacey Banda
