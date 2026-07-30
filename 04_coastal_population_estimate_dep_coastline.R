## COASTAL POPULATION UPDATE 2026 ##
## Luis de la Rua - luisr@spc.int - July 2026 ##
## Statistics for Development Division - SDD ##

# 1. SETTINGS =================================================================

# Clean workspace
rm(list = ls())
gc()

source("setup.R")
library(writexl)
# current date
date <- format(Sys.Date(), "%Y%m%d")

# Set data paths
layers <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Data/")
output <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Results/")

# List of countries in pacific region
iso3_list <- c ("ASM","COK","FSM","GUM","MHL","MNP","NCL","NIU","NRU","PLW","PNG","PTC","PYF","SLB", "TON","TUV","VUT","WLF","WSM") # countries not touched by dateline
iso3_dline_countries <- c("FJI","KIR")

all_pacific_iso3 <- c(iso3_list, iso3_dline_countries)

# 2 POPULATION GRIDS ===========================================================

## 2.1 Load Population Grids from Sharepoint (or folder in local machine shortcut) ----
grid_dir <- "C:/Users/luisr/SPC/SDD GIS - Documents/Pacific PopGrid/UPDATE_2026/"

# Find all files containing the target pattern

grid_files <- list.files(
  path = grid_dir, 
  pattern = "t_pop_2026.*\\.tif$", 
  full.names = TRUE,
  recursive = T,
  ignore.case = TRUE
)

# File names without the full directory path
file_names <- basename(grid_files)

# Extract the ISO3 codes (the first 3 characters)
iso3_codes <- substr(file_names, 1, 3)

# Identify "unique countries SDD's Population grids 
sdd_grids<- unique(iso3_codes)
print(paste0("SDD grids:", sdd_grids))
print(sdd_grids)

# Load rasters into a named list
pop_rasters <- lapply(grid_files, rast)
names(pop_rasters) <- iso3_codes


## 2.2 Download the remaining rasters from WorldPop ----

missing_iso3 <- setdiff(all_pacific_iso3, sdd_grids)

print("Missing countries to download from WorldPop:")
print(missing_iso3)

# Define donwload destination for files
wp_dir <- file.path(grid_dir, "WorldPop")
if(!dir.exists(wp_dir)) dir.create(wp_dir, recursive = TRUE)

# Donwload directly from WorldPop site
# Base URL structure for WorldPop 2015-2030 projections (100m resolution)
# Note: This points to the unconstrained global projections (R2025A version)
base_wp_url <- "https://data.worldpop.org/GIS/Population/Global_2015_2030/R2025A/2026"

for (iso3 in missing_iso3) {
  iso3_lower <- tolower(iso3)
  
  # Define file name and exact local destination path
  file_name <- paste0(iso3_lower, "_pop_2026_CN_100m_R2025A_v1.tif")
  dest_file <- file.path(wp_dir, file_name)
  
  # Check if the file already exists on your hard disk
  if (file.exists(dest_file)) {
    print(paste("File already exists, skipping download:", file_name))
    next  # This skips the rest of the current loop iteration and moves to the next ISO3
  }
  
  # If the file does NOT exist, proceed with URL construction and download
  wp_url <- paste(base_wp_url, iso3, "v1", "100m", "constrained", file_name, sep = "/")
  
  print(paste("Attempting to download:", iso3))
  print(paste("URL:", wp_url)) 
  
  tryCatch({
    download.file(
      url = wp_url, 
      destfile = dest_file, 
      mode = "wb",          
      method = "libcurl",
      quiet = TRUE 
    )
    print(paste("Successfully downloaded:", file_name))}, 
    error = function(e) {
    message(paste("Failed to download data for", iso3, "-", e$message))
  })
}

## 2.3 Load Wpop and combine with SDD rasters ----
wp_files <- list.files(
  path = wp_dir, 
  pattern = ".*_pop_2026_CN_100m_R2025A_v1\\.tif$", 
  full.names = TRUE,
  ignore.case = TRUE
)

# Extract the ISO3 codes from the filenames
# Since the downloaded filenames start with lowercase (e.g., "asm"), 
# we use toupper() to match your existing uppercase ISO3 list
wp_iso3_codes <- toupper(substr(basename(wp_files), 1, 3))

wp_rasters <- lapply(wp_files, rast)
names(wp_rasters) <- wp_iso3_codes

print(paste("Loaded", length(wp_rasters), "WorldPop grids."))

# This creates a single list containing all Pacific countries
all_pac_rasters <- c(pop_rasters, wp_rasters)
# Sort by ISO code
all_pac_rasters <- all_pac_rasters[order(names(all_pac_rasters))]

print("Master list created containing:")
print(names(all_pac_rasters))

## 2.4 Total Population fo 2026 official from PDH -----
totpop_df <- read_csv(paste0(layers,"pop_stat.csv")) |> 
  filter(obsTime == "2026") |>  # Filter for 2026
  rename(country_code = ISO3) |> 
  select(country_code, Country, obsValue)

# 3. ZONAL STATISTICS TO CALCULATE COASTAL POPULATION USING DIGITAL EARTH PACIFIC DERIVED DATASET ========

# List buffer files 
buffer_files <- list.files(paste0(layers, "coastal_buffers_dep/"), pattern = "\\.gpkg$", full.names = TRUE)

# Initialize results list
results_dep <- list()

# Loop through each GeoPackage file
for (buffer_file in buffer_files) {
  
  # Extract ISO3 from the file name to find the right population grid
  file_basename <- basename(buffer_file)
  buffer_iso3 <- toupper(sub("_.*", "", file_basename)) 
  
  # Pull the corresponding raster from the master list
  pop_grid <- all_pac_rasters[[buffer_iso3]]
  
  # Skip if no matching grid is found
  if (is.null(pop_grid)) {
    warning(paste("No matching grid found for:", file_basename))
    next
  }
  
  # Get the actual filename of the raster for metadata
  grid_filename <- basename(sources(pop_grid))
  
  # Get all layer names inside this specific GeoPackage
    gpkg_layers <- vector_layers(buffer_file)
  
  # Loop through each layer inside the GeoPackage
  for (lyr_name in gpkg_layers) {
    
    # Load the specific layer
    buffer <- vect(buffer_file, layer = lyr_name)
    
    # Extract the distance from the layer name (e.g., "1km" from "WSM_buffer_1km")
    buffer_distance <- gsub(".*_([0-9]+km).*", "\\1", lyr_name)
    
    # Check that CRS matches; if not, reproject buffer to raster CRS
    if (crs(buffer) != crs(pop_grid)) {
      buffer <- project(buffer, crs(pop_grid))
    }
    
    # Calculate zonal statistics
    stats <- exact_extract(pop_grid, st_as_sf(buffer), fun = "sum", progress = FALSE)
    
    # Add metadata
    stats_df <- data.frame(sum_pop = stats) %>%
      mutate(
        grid_file = grid_filename,
        iso3_code = buffer_iso3,
        buffer_dist = buffer_distance,
        layer_name = lyr_name
      ) %>%
      bind_cols(as.data.frame(buffer)) # Binds buffer attributes (if any exist)
    
    # Append to results using a unique key for the list
    list_key <- paste0(buffer_iso3, "_", buffer_distance)
    results_dep[[list_key]] <- stats_df
    
    # Print confirmation
    print(paste("Processed -> ISO3:", buffer_iso3, 
                "| Layer:", lyr_name, 
                "| Grid:", grid_filename))
  }
}

# Combine all results into a single data frame
final_results_df <- bind_rows(results_dep)
# Combine results into a single data frame
prov_results_dep <- do.call(rbind, results_dep)

# Transpose to a single row per country
transposed_data_dep <- prov_results_dep %>%
  select(country_code, buffer_dist, sum_pop, grid_file) %>% 
  pivot_wider(
    names_from = buffer_dist,
    values_from = sum_pop,
    names_prefix = "pop_dep_") %>% 
  select(country_code ,pop_dep_1km , pop_dep_5km,pop_dep_10km, grid_file)

# Merge with total population results
final_results_dep <- transposed_data_dep %>% 
  merge(., totpop_df, by="country_code") %>% 
  rename(totpop = obsValue,
         country_name = Country) |> 
  mutate(pop_dep_b1km_per = pop_dep_1km /totpop,
         pop_dep_b5km_per = pop_dep_5km /totpop,
         pop_dep_b10km_per = pop_dep_10km  /totpop) %>% 
  relocate(grid_file, .after = pop_dep_b10km_per) |> 
  relocate(country_name, .after = country_code)

# Add some more metadata
final_results_dep <- final_results_dep |> 
  mutate(population_source = ifelse(grepl("t_pop_2026", grid_file), "SDD", "WorldPop"),
         coastal_buffer_source = "Digital Earth - Pacific Coastlines Change")

print(final_results_dep)

write_xlsx(final_results_dep,paste0(output,date,"_coastal_population_dep_2026.xlsx"))


# 4. ZONAL STATISTICS TO CALCULATE COASTAL POPULATION USING BUFFERS DERIVED FROM GLOBAL SHORELINE DATASET ----
# Run the analysis using global shoreline dataset https://gee-community-catalog.org/projects/shoreline/
# We want to compare if we have inportant differences between the two datasets.

# List buffer files from Golbal Shoreline dataset
gs_buffer_list <- list.files("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2025/Data/coastal buffers globalshore",
                             pattern = "\\.gpkg$", full.names = TRUE)

# Check that buffers are all dissolved and have 1 single feature per layer
for (buffer in gs_buffer_list){
  buffer_layer <- vect(buffer)
  nrow <- length(buffer_layer)
  print(c( basename(buffer), nrow))
}
# Initialize results list
results_gs <- list()

# Loop through each GeoPackage file
for (buffer_file in gs_buffer_list) {
  
  # Extract ISO3 from the file name to find the right population grid
  file_basename <- basename(buffer_file)
  buffer_iso3 <- toupper(sub("_.*", "", file_basename)) 
  
  # Pull the corresponding raster from the master list
  pop_grid <- all_pac_rasters[[buffer_iso3]]
  
  # Skip if no matching grid is found
  if (is.null(pop_grid)) {
    warning(paste("No matching grid found for:", file_basename))
    next
  }
  
  # Get the actual filename of the raster for metadata
  grid_filename <- basename(sources(pop_grid))
  
  # Get all layer names inside this specific GeoPackage
  gpkg_layers <- vector_layers(buffer_file)
  
  # Loop through each layer inside the GeoPackage
  for (lyr_name in gpkg_layers) {
    
    # Load the specific layer
    buffer <- vect(buffer_file, layer = lyr_name)
    
    # Extract the distance from the layer name (e.g., "1km" from "WSM_buffer_1km")
    buffer_distance <- gsub(".*_([0-9]+km).*", "\\1", lyr_name)
    
    # Check that CRS matches; if not, reproject buffer to raster CRS
    if (crs(buffer) != crs(pop_grid)) {
      buffer <- project(buffer, crs(pop_grid))
    }
    
    # Calculate zonal statistics
    stats <- exact_extract(pop_grid, st_as_sf(buffer), fun = "sum", progress = FALSE)
    
    # Add metadata
    stats_df <- data.frame(sum_pop = stats) %>%
      mutate(
        grid_file = grid_filename,
        iso3_code = buffer_iso3,
        buffer_dist = buffer_distance,
        layer_name = lyr_name
      ) %>%
      bind_cols(as.data.frame(buffer)) # Binds buffer attributes (if any exist)
    
    # Append to results using a unique key for the list
    list_key <- paste0(buffer_iso3, "_", buffer_distance)
    results_gs[[list_key]] <- stats_df
    
    # Print confirmation
    print(paste("Processed -> ISO3:", buffer_iso3, 
                "| Layer:", lyr_name, 
                "| Grid:", grid_filename))
  }
}


# Combine results into a single data frame
prov_results_gs <- do.call(rbind, results_gs)

# Transpose to a single row per country
transposed_data_gs <- prov_results_gs %>%
  rename(country_code = iso3_code) |> 
  select(country_code, buffer_dist, sum_pop, grid_file) %>% 
  pivot_wider(
    names_from = buffer_dist,
    values_from = sum_pop,
    names_prefix = "pop_gs_") %>% 
  select(country_code, pop_gs_1km , pop_gs_5km, pop_gs_10km, grid_file)



# Merge with total population results
final_results_gs <- transposed_data_gs %>% 
  merge(., totpop_df, by="country_code") %>% 
  rename(totpop = obsValue,
         country_name = Country) |> 
  mutate(pop_gs_b1km_per = pop_gs_1km /totpop,
         pop_gs_b5km_per = pop_gs_5km /totpop,
         pop_gs_b10km_per = pop_gs_10km  /totpop) %>% 
  relocate(grid_file, .after = pop_gs_b10km_per) |> 
  relocate(country_name, .after = country_code)


# Add some more metadata
final_results_gs <- final_results_gs |> 
  mutate(population_source = ifelse(grepl("t_pop_2026", grid_file), "SDD", "WorldPop"),
         coastal_buffer_source = "Global Shoreline Dataset")

print(final_results_gs)

write_xlsx(final_results_gs,paste0(output,date,"_coastal_population_gs_2026.xlsx"))

# 5. DATA COMPARISON AND CONCLUSIONS ===========================================
## 5.1 Compare Coastal Populations between DEP and GSD ----
dep_vs_gsd <- merge(final_results_dep, final_results_gs, by = "country_code") %>%
  select(-totpop.x) %>%
  rename(totpop = totpop.y) %>%
  mutate(diff_1kmb_pop_per = pop_dep_b1km_per  - pop_gs_b1km_per,
         diff_5kmb_pop_per = pop_dep_b5km_per  - pop_gs_b5km_per,
         diff_10kmb_pop_per = pop_dep_b10km_per - pop_gs_b10km_per) %>%
  mutate(diff_1km_pop = pop_dep_1km - pop_gs_1km,
         diff_5km_pop = pop_dep_5km - pop_gs_5km,
         diff_10km_pop = pop_dep_10km  - pop_gs_10km)

# Plot comparison
# Plot bar graph putting both percentages together
plot_compare <- dep_vs_gsd %>%
  select(country_code, diff_1kmb_pop_per, diff_5kmb_pop_per, diff_10kmb_pop_per) %>%
  pivot_longer(cols = -"country_code", names_to = "buffer", values_to = "diff_pop_per") %>%
  mutate(buffer = factor(buffer, levels = c("diff_1kmb_pop_per", "diff_5kmb_pop_per", "diff_10kmb_pop_per"))) %>%
  ggplot(aes(x = country_code, y = diff_pop_per, fill = buffer)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Differences in population percentages between buffer datasets / National Buffers - GS Buffers",
       x = "ISO3", y = "Population percentage difference") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
plot_compare