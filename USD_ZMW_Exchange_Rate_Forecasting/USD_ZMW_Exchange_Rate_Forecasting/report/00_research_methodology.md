# Research Methodology

**Modelling and Forecasting the USD/ZMW Exchange Rate: A Time-Series Econometric and Stochastic Simulation Approach**

This document sets out the research design *before* any data are analysed. Every number that later appears in the report must come from the scripts in `scripts/`; nothing here is a result.

---

## 1. Research design overview

| Stage | Question answered | Technique | Script |
|---|---|---|---|
| Data | What does the kwacha's history look like, and is the data trustworthy? | Multi-source collection, provenance logging, cross-validation | 01, 02 |
| Description | How has USD/ZMW behaved: trend, volatility, tails, breaks? | Descriptive statistics, log returns, Jarque–Bera, structural-break tests | 03 |
| Stationarity | Is the level a random walk? Are returns stationary? | ADF, KPSS, ACF/PACF | 04 |
| Point forecasting | Does past data predict the future better than "no change"? | ARIMA (Box–Jenkins) vs random walk, rolling-origin evaluation, Diebold–Mariano | 05, 09 |
| Volatility | Does risk cluster, and how persistent is it? | GARCH(1,1) with Student-t innovations | 06 |
| Scenarios | What range of rates is plausible over 1–12 months? | Monte Carlo (GARCH-t, bootstrap, GBM baseline), 10,000 paths | 07 |
| Drivers | Which macro variables co-move with the kwacha? | OLS on monthly changes, HAC standard errors, diagnostics | 08 |
| Synthesis | Which model is fit for which purpose? | Forecast-accuracy tables, coverage tests | 09, 10 |

The design is deliberately **benchmark-led**: the exchange-rate literature since Meese & Rogoff (1983) shows that structural and time-series models rarely beat a random walk out of sample at short horizons. The project therefore treats the random walk as the null model that every alternative must beat, and reports honestly if none does.

---

## 2. Data

### 2.1 Sample period and frequency

* **Start: January 2013.** The kwacha was rebased on 1 January 2013 (ZMK 1,000 = ZMW 1). Starting here avoids splicing two currency units and still gives roughly 13+ years (≈ 160+ monthly observations).
* **End:** the last *complete* calendar month before the data are downloaded. A partially observed month is excluded, because its average would be biased.
* **Frequency: monthly**, built from daily Bank of Zambia rates.

### 2.2 Exchange-rate definition

* $S_t$ = kwacha per US dollar (ZMW per USD). A **rise in $S_t$ is a kwacha depreciation.**
* **Primary series:** monthly *average* of daily Bank of Zambia mid/average rates (as specified in the brief).
* **Robustness series:** *end-of-month* rate.

Why both? Averaging a random walk within the month mechanically induces positive first-order autocorrelation (about 0.25) in the differences of the averaged series (Working, 1960). An ARIMA model fitted to monthly averages can therefore appear to "forecast" when it is only exploiting this smoothing artefact. Script 05 fits both series; if the AR/MA terms vanish in the end-of-month data, that is reported as evidence of an averaging effect rather than genuine predictability. For risk work (GARCH, Monte Carlo) the end-of-month rate is closer to what a treasurer actually transacts at, and is preferred.

### 2.3 Returns

Monthly log returns, in percent:

$$ r_t = 100 \times \ln\!\left(\frac{S_t}{S_{t-1}}\right) $$

Log returns are additive over time ($\ln(S_{t+h}/S_t) = \sum_{i=1}^{h} r_{t+i}/100$), approximately equal to percentage changes for small moves, and are the natural input for GARCH and geometric simulation.

### 2.4 Variables and sources

| Variable | Frequency | Source | Retrieval | Use |
|---|---|---|---|---|
| USD/ZMW daily rate | Daily → monthly | Bank of Zambia (direct download, *preferred*) | Manual, template provided | Primary series |
| USD/ZMW daily rate | Daily → monthly | Bank of Zambia rates republished by the Frankfurter API (`providers=boz`) | Automated | Primary series if no manual file is supplied |
| USD/ZMW daily rate | Daily | Yahoo Finance `ZMW=X` via `quantmod` | Automated | Last-resort fallback only (vendor composite, not BoZ) |
| Official exchange rate, annual average | Annual | World Bank WDI `PA.NUS.FCRF` | Automated (API) | Cross-validation of the monthly series |
| Copper price (USD/tonne) | Monthly | IMF Primary Commodity Prices via FRED `PCOPPUSDM` | Automated | Regression (terms of trade) |
| US CPI (all items, SA) | Monthly | US BLS via FRED `CPIAUCSL` | Automated | Inflation differential |
| US effective federal funds rate | Monthly | Federal Reserve via FRED `FEDFUNDS` | Automated | Interest differential |
| Zambia CPI (index or annual inflation) | Monthly | Zambia Statistics Agency (ZamStats) Monthly Bulletin | Manual, template provided | Inflation differential |
| BoZ Monetary Policy Rate | Event-based → monthly | Bank of Zambia MPC statements | Manual, template provided | Interest differential |
| Zambia gross international reserves (USD m) | Monthly | Bank of Zambia statistics / IMF IRFCL | Manual, template provided | Regression |
| Zambia inflation, GDP growth, reserves, lending rate | Annual | World Bank WDI | Automated (API) | Economic context only (not used in monthly regressions) |

Every download is logged automatically to `data/raw/data_provenance.csv` with the URL, retrieval timestamp, number of observations and date range. This file is the evidence that the data are genuine, and the report's "Data Sources" section is generated from it.

### 2.5 Data-quality checks (script 02)

1. Missing business days, duplicated dates and non-positive rates.
2. Daily jumps larger than 10% are flagged for manual review against BoZ publications (not deleted automatically).
3. The annual average of the constructed monthly series is compared with the World Bank's `PA.NUS.FCRF`; differences above 2% are investigated.
4. Macro series are aligned on calendar month. Missing macro values are **not** interpolated for the regression; rows with missing regressors are dropped and the count is reported.

---

## 3. Exploratory data analysis (script 03)

Statistics computed on $S_t$ and $r_t$: mean, median, variance, standard deviation, skewness $\hat\gamma_1 = \frac{1}{n}\sum (r_t-\bar r)^3 / \hat\sigma^3$, kurtosis $\hat\gamma_2 = \frac{1}{n}\sum (r_t-\bar r)^4/\hat\sigma^4$ (normal = 3), and the Jarque–Bera test

$$ JB = \frac{n}{6}\left(\hat\gamma_1^2 + \frac{(\hat\gamma_2-3)^2}{4}\right) \sim \chi^2_2 \text{ under normality.} $$

Outliers are identified with a robust rule ($|r_t - \text{median}| > 3 \times 1.4826\,\text{MAD}$) and kept in the sample (they are real crises, not errors), but listed and dated. Structural change is examined with the Bai–Perron (2003) multiple-break test on the mean of returns and on squared returns (a proxy for variance regimes), using `strucchange`. Candidate events to check against detected breaks — not to impose — include the 2015 commodity-price shock, the 2020 COVID-19 shock and sovereign Eurobond default, the 2021 elections, the 2022 IMF Extended Credit Facility, and the 2024 drought and power crisis.

---

## 4. Stationarity (script 04)

**ADF test.** Regression

$$ \Delta y_t = \alpha + \delta t + \gamma y_{t-1} + \sum_{i=1}^{p}\phi_i \Delta y_{t-i} + \varepsilon_t $$

$H_0: \gamma = 0$ (unit root, non-stationary) vs $H_1: \gamma<0$. Lag length $p$ chosen by AIC. Run on $\ln S_t$ (with trend) and on $r_t$ (drift only).

**KPSS test.** Decomposes $y_t = \xi t + \mu_t + u_t$, $\mu_t = \mu_{t-1} + v_t$. $H_0: \sigma_v^2 = 0$ (stationary around a level/trend) vs $H_1$: unit root.

Using both tests with opposite nulls gives a confirmation matrix: ADF fails to reject + KPSS rejects ⇒ strong evidence of a unit root. Conflicting results are reported as conflicting, not forced. **Limitation:** both tests have low power in ~160 observations and are biased towards non-rejection of a unit root when there are structural breaks; the Zivot–Andrews (1992) test, which allows one endogenous break, is reported as a robustness check.

ACF and PACF of $\ln S_t$ and $r_t$ (with ±1.96/√n bands) guide ARIMA identification.

---

## 5. ARIMA forecasting (scripts 05 and 09)

**Model.** For $y_t = \ln S_t$, ARIMA(p,1,q):

$$ \phi(B)(1-B)y_t = c + \theta(B)\varepsilon_t,\quad \varepsilon_t \sim \text{WN}(0,\sigma^2) $$

Modelling the log level means forecast intervals are multiplicative and always positive. Back-transformed point forecasts are the *median*; the mean forecast uses the bias adjustment $\exp(\hat y + \hat\sigma_h^2/2)$, and the report states which is used.

**Identification.** (i) ACF/PACF inspection; (ii) a grid over $p,q \in \{0,\dots,3\}$ with and without drift, ranked by AICc and BIC; (iii) `forecast::auto.arima` (stepwise off, approximation off) as a cross-check. BIC is favoured when the two disagree, because it penalises over-fitting more heavily in small samples.

**Diagnostics.** Residual ACF; Ljung–Box $Q = n(n+2)\sum_{k=1}^{m}\hat\rho_k^2/(n-k) \sim \chi^2_{m-p-q}$ with $H_0$: no autocorrelation up to lag $m$; Jarque–Bera on residuals; ARCH-LM on residuals (motivating GARCH).

**Out-of-sample design.** Strictly chronological:
* Training: January 2013 to the 24th-last month; test: the final 24 months.
* **Rolling-origin (expanding-window) evaluation**: re-estimate at every origin in the test period and forecast $h = 1, 3, 6, 12$ months ahead. This produces many forecast errors per horizon rather than one, which is essential for comparing models fairly.
* **Benchmarks:** random walk ($\hat S_{t+h} = S_t$) and random walk with drift.

**Metrics.** $\text{MAE} = \frac1N\sum|e|$, $\text{RMSE} = \sqrt{\frac1N\sum e^2}$, $\text{MAPE} = \frac{100}{N}\sum|e/S|$ (appropriate here because $S_t$ is strictly positive and far from zero), and Theil's U (RMSE ratio vs random walk; U < 1 means ARIMA wins). Statistical significance of differences uses the **Diebold–Mariano test** with the Harvey–Leybourne–Newbold small-sample correction. Interval quality is checked by empirical coverage of 80% and 95% intervals.

---

## 6. GARCH volatility modelling (script 06)

**Model.** On monthly returns $r_t$:

$$ r_t = \mu + a_1 r_{t-1} + \varepsilon_t,\qquad \varepsilon_t = \sigma_t z_t,\qquad z_t \sim \text{i.i.d. } t_\nu \text{ (standardised)} $$
$$ \sigma_t^2 = \omega + \alpha\,\varepsilon_{t-1}^2 + \beta\,\sigma_{t-1}^2,\qquad \omega>0,\ \alpha,\beta\ge0,\ \alpha+\beta<1 $$

Estimated by maximum likelihood with `rugarch`. Student-t innovations are used because exchange-rate returns are typically fat-tailed; Normal and skewed-t are fitted for comparison by AIC/BIC.

**Interpretation.** $\alpha$ = reaction of volatility to news; $\beta$ = memory of past volatility; $\alpha+\beta$ = persistence; half-life of a volatility shock $= \ln 0.5/\ln(\alpha+\beta)$ months; unconditional variance $\omega/(1-\alpha-\beta)$.

**Pre- and post-tests.** ARCH-LM (Engle, 1982) on mean-equation residuals before fitting (is GARCH needed?); Ljung–Box on standardised and squared standardised residuals after fitting; sign-bias test (asymmetry); Nyblom parameter-stability test. A GJR-GARCH(1,1) is fitted as a check on whether depreciation shocks raise volatility more than appreciations.

**Small-sample caveat.** ~160 monthly observations is short for GARCH; parameters will be imprecise. As a robustness check the GARCH model is also estimated on *daily* BoZ returns, where volatility clustering is far easier to identify, and the daily volatility is scaled to monthly for comparison.

**Why it matters actuarially.** Volatility is the input to capital requirements (VaR/Expected Shortfall), hedging cost (option premia scale with σ), asset–liability management for insurers holding USD liabilities, and stress testing. A model that captures clustering gives time-varying risk measures instead of a single historical average that is too low in crises and too high in calm periods.

---

## 7. Monte Carlo simulation (script 07)

**Objective:** produce a *distribution* of possible USD/ZMW rates 1, 3, 6 and 12 months ahead. These are probabilistic scenarios conditional on model assumptions, **not forecasts of what will happen**.

Three generators, reported side by side:

1. **GARCH(1,1)-t (primary).** Simulate $\sigma_{t+1}^2, z_{t+1}, r_{t+1}, \dots$ forward from the last fitted state with `ugarchpath`/`ugarchsim`. Captures fat tails and volatility clustering and starts from *current* volatility.
2. **Filtered historical simulation / bootstrap.** Resample standardised residuals and re-scale with simulated GARCH variance; makes no parametric assumption about $z_t$.
3. **Geometric Brownian motion (baseline).** $S_{t+h} = S_t\exp\big((\mu-\tfrac12\sigma^2)h + \sigma\sqrt{h}\,Z\big)$ with constant historical $\mu,\sigma$. Included because it is the textbook model; its thin tails and constant volatility are exactly the weaknesses the other two address.

**Settings:** 10,000 paths, monthly steps to 12 months, fixed seed (`set.seed(20131)`) for reproducibility.

**Outputs per horizon:** mean, median, 5th/25th/75th/95th percentiles, probability of depreciation beyond thresholds (e.g. +10%, +20%), and for a hypothetical USD 1 million liability: 95% and 99% VaR and Expected Shortfall in ZMW.

**Assumptions and limitations:** parameter uncertainty is ignored unless explicitly added; no regime switching, central-bank intervention or policy announcements are modelled; the drift $\mu$ is estimated imprecisely and has a large effect on 12-month medians, so a zero-drift sensitivity is also reported.

---

## 8. Macroeconomic regression (script 08)

**Specification** (monthly, all in changes to avoid spurious regression between I(1) levels):

$$ r_t = \beta_0 + \beta_1\,\Delta\ln \text{Cu}_t + \beta_2\,(\pi^{ZM}_t - \pi^{US}_t) + \beta_3\,(i^{ZM}_t - i^{US}_t) + \beta_4\,\Delta\ln \text{Res}_t + \varepsilon_t $$

with a lagged-regressor version ($t-1$) to reduce simultaneity. Variables enter only if a reliable monthly series has been obtained; the script reports which were available.

**Estimation and tests:** OLS; variance inflation factors (`car::vif`, concern above ~5); Breusch–Godfrey (autocorrelation); Breusch–Pagan (heteroskedasticity); inference with Newey–West HAC standard errors (`sandwich`), which remain valid under both problems. Optional: Engle–Granger/Johansen cointegration in levels if the variables are all I(1).

**Interpretation discipline:** coefficients are *conditional associations*. Copper prices, reserves and the exchange rate are jointly determined (reserves fall when BoZ sells dollars to defend the kwacha), so no coefficient is interpreted causally. Phrasing in the report will be "is associated with", never "causes".

---

## 9. Reproducibility and integrity rules

1. Raw downloads are saved untouched with a date stamp; all transformations happen in later scripts.
2. `data/raw/data_provenance.csv` records source, URL and retrieval time for every file.
3. Random seeds are fixed.
4. The report is written in R Markdown and pulls every number from `outputs/tables/`, so no figure can be typed in by hand.
5. If a model fails or a source is unavailable, the report says so.

---

## 10. Core references

* Bai, J. & Perron, P. (2003). Computation and analysis of multiple structural change models. *Journal of Applied Econometrics*, 18(1), 1–22.
* Bollerslev, T. (1986). Generalized autoregressive conditional heteroskedasticity. *Journal of Econometrics*, 31(3), 307–327.
* Box, G.E.P., Jenkins, G.M., Reinsel, G.C. & Ljung, G.M. (2015). *Time Series Analysis: Forecasting and Control* (5th ed.). Wiley.
* Chen, Y.-C. & Rogoff, K. (2003). Commodity currencies. *Journal of International Economics*, 60(1), 133–160.
* Dickey, D.A. & Fuller, W.A. (1979). Distribution of the estimators for autoregressive time series with a unit root. *JASA*, 74(366), 427–431.
* Diebold, F.X. & Mariano, R.S. (1995). Comparing predictive accuracy. *Journal of Business & Economic Statistics*, 13(3), 253–263.
* Engle, R.F. (1982). Autoregressive conditional heteroscedasticity with estimates of the variance of United Kingdom inflation. *Econometrica*, 50(4), 987–1007.
* Ghalanos, A. (2024). *rugarch: Univariate GARCH Models*. R package, CRAN.
* Glasserman, P. (2003). *Monte Carlo Methods in Financial Engineering*. Springer.
* Hansen, P.R. & Lunde, A. (2005). A forecast comparison of volatility models: does anything beat a GARCH(1,1)? *Journal of Applied Econometrics*, 20(7), 873–889.
* Harvey, D., Leybourne, S. & Newbold, P. (1997). Testing the equality of prediction mean squared errors. *International Journal of Forecasting*, 13(2), 281–291.
* Hyndman, R.J. & Athanasopoulos, G. (2021). *Forecasting: Principles and Practice* (3rd ed.). OTexts.
* Kwiatkowski, D., Phillips, P.C.B., Schmidt, P. & Shin, Y. (1992). Testing the null hypothesis of stationarity against the alternative of a unit root. *Journal of Econometrics*, 54(1–3), 159–178.
* Ljung, G.M. & Box, G.E.P. (1978). On a measure of lack of fit in time series models. *Biometrika*, 65(2), 297–303.
* Meese, R.A. & Rogoff, K. (1983). Empirical exchange rate models of the seventies: do they fit out of sample? *Journal of International Economics*, 14(1–2), 3–24.
* Newey, W.K. & West, K.D. (1987). A simple, positive semi-definite, heteroskedasticity and autocorrelation consistent covariance matrix. *Econometrica*, 55(3), 703–708.
* Working, H. (1960). Note on the correlation of first differences of averages in a random chain. *Econometrica*, 28(4), 916–918.
* Zivot, E. & Andrews, D.W.K. (1992). Further evidence on the Great Crash, the oil-price shock, and the unit-root hypothesis. *Journal of Business & Economic Statistics*, 10(3), 251–270.

Institutional sources (Bank of Zambia Monetary Policy Statements, IMF Article IV and ECF staff reports for Zambia, World Bank Zambia Economic Briefs) will be added in the literature-review stage, each with its retrieval date.
