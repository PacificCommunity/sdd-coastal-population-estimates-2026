# Clean workspace
rm(list = ls())
gc()

source("setup.R")

date <- format(Sys.Date(), "%Y%m%d")

# Set data paths
layers <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Data/")
output <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Results/")

# ============================================================
# i. DEFINE CONSTANTS
# ============================================================
date <- format(Sys.Date(), "%Y%m%d")
output <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Results/")
dataflow <- "SPC:DF_POP_COAST(2.0)"
freq <- "A"
time_period <- 2026
obs_status <- "E"

# ============================================================
# ii. CREATE COASTAL POPULATION PERCENTAGE DATA
# ============================================================
#
# Source percentage columns:
#
#   pop_dep_b1km_per
#   pop_dep_b5km_per
#   pop_dep_b10km_per
#
# They contain proportions, e.g.
#
#   0.600215011
#
# which are converted to:
#
#   60.0215011
#
# for UNIT_MEASURE = PERCENT.
#
# ============================================================

# Load final results dep ----
files <- list.files(
  path = output,
  pattern = "coastal_population_dep_2026\\.xlsx$",
  full.names = TRUE
)

# Sort to get the latest file
latest_file <- tail(sort(files), 1)

# Load the results table
final_results_dep <- read_xlsx(latest_file)

coastal_percentage <- final_results_dep |>
  select(country_code, country_name, pop_dep_b1km_per, pop_dep_b5km_per, pop_dep_b10km_per, population_source, coastal_buffer_source) |>
  pivot_longer(
    cols = c(
      pop_dep_b1km_per,
      pop_dep_b5km_per,
      pop_dep_b10km_per
    ),
    names_to = "RANGE",
    values_to = "OBS_VALUE"
  ) |>
  mutate(
    
    # --------------------------------------------------------
    # Convert source column names to SDMX RANGE codes
    # --------------------------------------------------------
    RANGE = case_when(
      RANGE == "pop_dep_b1km_per"  ~ "1KM",
      RANGE == "pop_dep_b5km_per"  ~ "5KM",
      RANGE == "pop_dep_b10km_per" ~ "10KM",
      TRUE ~ RANGE
    ),
    
    # --------------------------------------------------------
    # Convert proportion to percentage
    # --------------------------------------------------------
    
    OBS_VALUE = round(as.numeric(OBS_VALUE) * 100, 1),
    
    # --------------------------------------------------------
    # SDMX dimensions
    # --------------------------------------------------------
    
    DATAFLOW = dataflow,
    FREQ = freq,
    TIME_PERIOD = time_period,
    ref_area = country_code,
    INDICATOR = "COASTALPOPRF",
    UNIT_MEASURE = "PERCENT",
    UNIT_MULT = "",
    OBS_STATUS = obs_status,
    DATA_SOURCE = population_source,
    
    # --------------------------------------------------------
    # Comment
    # --------------------------------------------------------
    
    OBS_COMMENT = paste0(
      "Percentage of coastal population based on 2026 ",
      "population estimates. Population source: ",
      population_source,
      ". Coastal buffer source: ",
      coastal_buffer_source,
      "."
    )
  ) |>
  
  select(DATAFLOW, FREQ, TIME_PERIOD, ref_area, INDICATOR, RANGE, OBS_VALUE, UNIT_MEASURE, UNIT_MULT, OBS_STATUS, DATA_SOURCE, OBS_COMMENT)

# ============================================================
# iii. CREATE COASTAL POPULATION ABSOLUTE DATA
# ============================================================
#
# Source:
#
#   totpop
#
# Output:
#
#   INDICATOR = COASTALPOPAF
#   RANGE     = _T
#   UNIT_MEASURE = N
#
# ============================================================

coastal_absolute <- final_results_dep |>
  select(country_code, country_name, totpop, population_source, coastal_buffer_source) |>
  mutate(
    # --------------------------------------------------------
    # Convert population to numeric
    # --------------------------------------------------------
    totpop = as.numeric(totpop),
    # --------------------------------------------------------
    # SDMX dimensions
    # --------------------------------------------------------
    DATAFLOW = dataflow,
    FREQ = freq,
    TIME_PERIOD = time_period,
    ref_area = country_code,
    INDICATOR = "COASTALPOPAF",
    RANGE = "_T",
    OBS_VALUE = totpop,
    UNIT_MEASURE = "N",
    UNIT_MULT = "",
    OBS_STATUS = obs_status,
    DATA_SOURCE = population_source,
    # --------------------------------------------------------
    # Comment
    # --------------------------------------------------------
    OBS_COMMENT = paste0("Estimated total population for year 2026. ", "Population source: ", population_source, ". Coastal buffer source: ", coastal_buffer_source, ".")) |>
  select(DATAFLOW, FREQ, TIME_PERIOD, ref_area, INDICATOR, RANGE, OBS_VALUE, UNIT_MEASURE, UNIT_MULT, OBS_STATUS, DATA_SOURCE, OBS_COMMENT)  

# ============================================================
# iv. COMBINE BOTH INDICATORS
# ============================================================

final_data <- bind_rows(coastal_percentage, coastal_absolute)

# ============================================================
# v. GET TWO CHARCATER COUNTRY CODES
# ============================================================

countries <- data.frame(
  ref_area = c("ASM","COK","FSM","FJI","GUM","KIR","MHL","NRU","NIU","MNP","NCL","PLW","PNG","PCN",
               "PYF","WSM","SLB","TKL","TON","TUV","VUT","WLF"),
  GEO_PICT = c("AS","CK","FM","FJ","GU","KI","MH","NR","NU","MP","NC","PW","PG","PN","PF","WS",
               "SB","TK","TO","TV","VU","WF")
)

final_sdmx_data <- merge(final_data, countries, by = "ref_area") |>
  select(DATAFLOW, FREQ, TIME_PERIOD, GEO_PICT, INDICATOR, RANGE, OBS_VALUE, UNIT_MEASURE, UNIT_MULT, OBS_STATUS, DATA_SOURCE, OBS_COMMENT)

# ==================================================================
# vi. OUTPUT FINAL SDMX CSV FILE
# ==================================================================

write.csv(final_sdmx_data,paste0(output,date,"_sdmx_coastal_population_dep_2026.csv"), row.names = FALSE)
