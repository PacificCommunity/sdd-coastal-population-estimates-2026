## COASTAL BUFFERS DERIVED FROM DIGITAL EARTH PACIFIC COASTLINES DATASET ##
# https://data.digitalearthpacific.org/#dep_ls_coastlines/
# THIS SCRIPT USES SHORELINE DERIVED FROM REMOTE SENSING TO GENERATE THE 
# COASTAL BUFFERS IMPROVEMENT.

# ## Luis de la Rua - luisr@spc.int - May 2026 ##
## Statistics for Development Division - SDD ##

# 1. SETTINGS =================================================================
# Clean workspace
rm(list = ls())
gc()

source("setup.R")

# Set data paths
layers <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/Data/")
output <- ("C:/Users/luisr/SPC/SDD GIS - Documents/Coastal Population/CoastPop_Update2026/results/")


# 2. IMPORT LAYER INPUT =======================================================
# There is a country code for every line so we can split the process by country extent
# for the moment we import directly from local drive but dataset is downloaded from here
# https://data.digitalearthpacific.org/#dep_ls_coastlines/

# Load layer covers whole pacific
cline <- vect(paste0(layers,"dep_ls_coastlines_0-7-0-55.gpkg"))

# Extract country names
iso3 <- unique(cline$eez_territory)

# Heavy processes for big countries
big_iso3 <- c("PNG", "PYF", "VUT", "FJI", "SLB")

# Rest of the countries that will go into single loop
small_iso3 <- setdiff(iso3, big_iso3)

# We separate countries that are not giving error as Fiji struggles with topology
big_iso3_runs <- c("PNG", "PYF", "VUT", "SLB")

# Remove insufficient or unstable data
cline <- cline|> 
  filter(certainty == "good")

# Simplify the layers once so we do not repeat same process 22 times and reproject to 4326
tic()
cline_simple <- simplifyGeom(cline, tolerance = 10) |> 
  project("EPSG:4326")
toc()


# 3. BATCH COMPUTING BUFFER CREATION for SMALL countries =======================
target <- small_iso3

## 3.1 Set up log file ----
log_file <- "buffer_processing_log.txt"
cat(paste("--- Batch Started:", Sys.time(), "---\n"), file = log_file, append = TRUE)

## 3.2 Looping buffer creation ----
# Instead of finding one UTM zone for the whole country, we need to ask to 
# find the UTM zone for every individual island/atoll, group them by UTM zone, 
# and process them in mini-batches to merge them afterwards

for (iso in target) {
  message(paste("Processing: ", iso))
  
  # Try catch, if the code crashes, it catches the error, saves it and then jumps
  # to the next country
  loop_status <<- tryCatch({
    country_lines <- cline_simple |> 
      filter(eez_territory == iso)
    
    # If the country has zero rows, stop immediately and log it.
    if (nrow(country_lines) == 0) {
      stop("Zero shoreline features found for this country.")
    }
    
    # A. Get the centroid of EVERY individual line/island in the country
    cents <- crds(centroids(country_lines))
    
    # B. Calculate the UTM zone for every individual line
    lons <- cents[, 1]
    country_lines$utm_zone <- floor((lons + 180) / 6) + 1
    
    # C. Find the unique zones this country spans
    unique_zones <- unique(country_lines$utm_zone)
    
    # Prepare empty lists to hold the finished, EPSG:4326 shapes
    list_1km <- list()
    list_5km <- list()
    list_10km <- list()
    
    # D. THE INNER LOOP: Process the country one UTM zone at a time
    for (zone in unique_zones) {
      
      # Isolate only the islands in this specific UTM zone
      zone_lines <- country_lines[country_lines$utm_zone == zone, ]
      
      # Determine hemisphere based on the first feature in this zone
      lat <- crds(centroids(zone_lines[1, ]))[2]
      hemisphere <- ifelse(lat >= 0, "+datum=WGS84", "+south +datum=WGS84")
      
      # Build the local CRS for this specific zone
      local_crs <- paste0("+proj=utm +zone=", zone, " ", hemisphere, " +units=m +no_defs")
      
      # Project JUST these islands to their perfect local metric system
      zone_projected <- project(zone_lines, local_crs)
      
      # --- RUN YOUR WORKING GEOMETRY CODE ---
      zone_dissol <- aggregate(zone_projected, by = "year")
      
      zone_10m <- buffer(zone_dissol, width = 10)
      zone_990 <- buffer(zone_10m, width = 990)
      zone_1km_mle <- aggregate(zone_990)
      
      # Extend the buffers to 5 and 10km
      zone_5km_mle <- buffer(zone_1km_mle, width = 4000)
      zone_10km_mle <- buffer(zone_1km_mle, width = 9000)
      
      # --- PROJECT BACK TO GLOBAL (EPSG:4326) ---
      # Once the geometry is mathematically perfect, push it back to the global grid
      list_1km[[as.character(zone)]]  <- project(zone_1km_mle, "EPSG:4326")
      list_5km[[as.character(zone)]]  <- project(zone_5km_mle, "EPSG:4326")
      list_10km[[as.character(zone)]] <- project(zone_10km_mle, "EPSG:4326")
    }

    # Merge the perfectly buffered zones back into single country-wide layers
    poly_1km_mle  <- aggregate(vect(list_1km))
    poly_5km_mle  <- aggregate(vect(list_5km))
    poly_10km_mle <- aggregate(vect(list_10km))
    
    # NAME variables, layers and files
    poly_1km_mle$country_code <- iso
    poly_5km_mle$country_code <- iso
    poly_10km_mle$country_code <- iso
    
    # Export directly to disk 
    # (Note: Using 'iso' instead of 'iso3' here to match the loop variable, adjust if iso3 is defined globally)
    output_file <- paste0(layers, "coastal_buffers_dep/", iso, "_mle_buffers.gpkg")
    
    # First write MUST be overwrite = TRUE (no insert) to initialize the GPKG cleanly
    writeVector(poly_1km_mle, output_file, layer = paste0(iso, "_buffer_1km"), overwrite = TRUE)
    writeVector(poly_5km_mle, output_file, layer = paste0(iso, "_buffer_5km"), insert = TRUE)
    writeVector(poly_10km_mle, output_file, layer = paste0(iso, "_buffer_10km"), insert = TRUE)
    
    # If it gets to this line, it succeeded! This message is sent to loop_status.
    paste(iso, "SUCCESS")
    
  }, error = function(e) {
    # If ANYTHING fails above, it immediately jumps down here.
    paste("FAILED - Error:", e$message)
  })
  
  # 5. Write the result to the log file immediately
  log_message <- paste(Sys.time(), "| Country:", iso, "| Status:", loop_status, "\n")
  cat(log_message, file = log_file, append = TRUE)
  
  # Print status to the console so you can watch it run
  message(log_message)
  
  # 6. Deep Clean RAM
  # Added the new zone variables and lists to the cleanup to keep RAM perfectly clear
  suppressWarnings(rm(country_lines, zone_lines, zone_projected, zone_dissol, 
                      zone_10m, zone_990, zone_1km_mle, zone_5km_mle, zone_10km_mle,
                      list_1km, list_5km, list_10km,
                      poly_1km_mle, poly_5km_mle, poly_10km_mle))
  
  gc() # Force R to empty the garbage
}

message("Batch processing complete! Check buffer_processing_log.txt for any failures.")

## 3.3 And For the big countries, not the most elegant but...----

target <- big_iso3_runs

for (iso in target) {
  message(paste("Processing: ", iso))
  
  # Try catch, if the code crashes, it catches the error, saves it and then jumps
  # to the next country
  loop_status <<- tryCatch({
    country_lines <- cline_simple |> 
      filter(eez_territory == iso)
    
    # If the country has zero rows, stop immediately and log it.
    if (nrow(country_lines) == 0) {
      stop("Zero shoreline features found for this country.")
    }
    
    # A. Get the centroid of EVERY individual line/island in the country
    cents <- crds(centroids(country_lines))
    
    # B. Calculate the UTM zone for every individual line
    lons <- cents[, 1]
    country_lines$utm_zone <- floor((lons + 180) / 6) + 1
    
    # C. Find the unique zones this country spans
    unique_zones <- unique(country_lines$utm_zone)
    
    # Prepare empty lists to hold the finished, EPSG:4326 shapes
    list_1km <- list()
    list_5km <- list()
    list_10km <- list()
    
    # D. THE INNER LOOP: Process the country one UTM zone at a time
    for (zone in unique_zones) {
      
      # Isolate only the islands in this specific UTM zone
      zone_lines <- country_lines[country_lines$utm_zone == zone, ]
      
      # Determine hemisphere based on the first feature in this zone
      lat <- crds(centroids(zone_lines[1, ]))[2]
      hemisphere <- ifelse(lat >= 0, "+datum=WGS84", "+south +datum=WGS84")
      
      # Build the local CRS for this specific zone
      local_crs <- paste0("+proj=utm +zone=", zone, " ", hemisphere, " +units=m +no_defs")
      
      # Project JUST these islands to their perfect local metric system
      zone_projected <- project(zone_lines, local_crs)
      
      # --- RUN YOUR WORKING GEOMETRY CODE ---
      zone_dissol <- aggregate(zone_projected, by = "year")
      
      zone_10m <- buffer(zone_dissol, width = 10)
      zone_990 <- buffer(zone_10m, width = 990)
      zone_1km_mle <- aggregate(zone_990)
      
      # Extend the buffers to 5 and 10km
      zone_5km_mle <- buffer(zone_1km_mle, width = 4000)
      zone_10km_mle <- buffer(zone_1km_mle, width = 9000)
      
      # --- PROJECT BACK TO GLOBAL (EPSG:4326) ---
      # Once the geometry is mathematically perfect, push it back to the global grid
      list_1km[[as.character(zone)]]  <- project(zone_1km_mle, "EPSG:4326")
      list_5km[[as.character(zone)]]  <- project(zone_5km_mle, "EPSG:4326")
      list_10km[[as.character(zone)]] <- project(zone_10km_mle, "EPSG:4326")
    }
    
    # Merge the perfectly buffered zones back into single country-wide layers
    poly_1km_mle  <- aggregate(vect(list_1km))
    poly_5km_mle  <- aggregate(vect(list_5km))
    poly_10km_mle <- aggregate(vect(list_10km))
    
    # NAME variables, layers and files
    poly_1km_mle$country_code <- iso
    poly_5km_mle$country_code <- iso
    poly_10km_mle$country_code <- iso
    
    # Export directly to disk 
    # (Note: Using 'iso' instead of 'iso3' here to match the loop variable, adjust if iso3 is defined globally)
    output_file <- paste0(layers, "coastal_buffers_dep/", iso, "_mle_buffers.gpkg")
    
    # First write MUST be overwrite = TRUE (no insert) to initialize the GPKG cleanly
    writeVector(poly_1km_mle, output_file, layer = paste0(iso, "_buffer_1km"), overwrite = TRUE)
    writeVector(poly_5km_mle, output_file, layer = paste0(iso, "_buffer_5km"), insert = TRUE)
    writeVector(poly_10km_mle, output_file, layer = paste0(iso, "_buffer_10km"), insert = TRUE)
    
    # If it gets to this line, it succeeded! This message is sent to loop_status.
    paste(iso, "SUCCESS")
    
  }, error = function(e) {
    # If ANYTHING fails above, it immediately jumps down here.
    paste("FAILED - Error:", e$message)
  })
  
  # 5. Write the result to the log file immediately
  log_message <- paste(Sys.time(), "| Country:", iso, "| Status:", loop_status, "\n")
  cat(log_message, file = log_file, append = TRUE)
  
  # Print status to the console so you can watch it run
  message(log_message)
  
  # 6. Deep Clean RAM
  # Added the new zone variables and lists to the cleanup to keep RAM perfectly clear
  suppressWarnings(rm(country_lines, zone_lines, zone_projected, zone_dissol, 
                      zone_10m, zone_990, zone_1km_mle, zone_5km_mle, zone_10km_mle,
                      list_1km, list_5km, list_10km,
                      poly_1km_mle, poly_5km_mle, poly_10km_mle))
  
  gc() # Force R to empty the garbage
}

message("Batch processing complete! Check buffer_processing_log.txt for any failures.")

## 3.5 And for the countries that were making errors FJI. ----
iso <- "FJI"
message(paste("--- Isolating and Processing:", iso, "---"))

# 1. Extract Fiji from your original dataset
fiji_lines <- cline |> filter(eez_territory == iso)

# 2. Convert to 'sf' for hardcore topology fixing
sf_fiji <- st_as_sf(fiji_lines)

# 3. FORCE TO EPSG:4326 (WGS84)
# If it is currently in 3832, this projects it. If it's already 4326, it does nothing.
sf_fiji <- st_transform(sf_fiji, 4326)

# 4. THE SURGICAL CUT: Wrap the dateline immediately after entering 4326
message("Slicing the Date Line...")
sf_fiji <- st_wrap_dateline(sf_fiji, options = c("WRAPDATELINE=YES"))
sf_fiji <- st_make_valid(sf_fiji)

# 5. Bring it back to terra
fiji_lines <- vect(sf_fiji)

# --- UTM Zone Calculation ---
cents <- crds(centroids(fiji_lines))
lons <- cents[, 1]
fiji_lines$utm_zone <- floor((lons + 180) / 6) + 1
unique_zones <- unique(fiji_lines$utm_zone)

list_1km <- list()
list_5km <- list()
list_10km <- list()

for (zone in unique_zones) {
  
  message(paste("Processing Fiji UTM Zone:", zone))
  zone_lines <- fiji_lines[fiji_lines$utm_zone == zone, ]
  
  lat <- crds(centroids(zone_lines[1, ]))[2]
  hemisphere <- ifelse(lat >= 0, "+datum=WGS84", "+south +datum=WGS84")
  local_crs <- paste0("+proj=utm +zone=", zone, " ", hemisphere, " +units=m +no_defs")
  
  # Project to the safe, local metric zone
  zone_projected <- project(zone_lines, local_crs)
  zone_projected <- makeValid(zone_projected)
  
  # Aggregate by year
  zone_dissol <- aggregate(zone_projected, by = "year")
  
  # SIMPLIFY IN METERS
  zone_simple <- simplifyGeom(zone_dissol, tolerance = 10)
  
  # THE ULTIMATE FAILSAFE: Iron the geometry one more time!
  # Sometimes simplifyGeom accidentally pinches a curve. This instantly fixes it.
  zone_simple <- makeValid(zone_simple)
  
  # --- THE BUFFERS ---
  message("Generating buffers...")
  zone_10m <- buffer(zone_simple, width = 10)
  zone_990 <- buffer(zone_10m, width = 990)
  zone_1km_mle <- aggregate(zone_990)
  
  zone_5km_mle <- buffer(zone_1km_mle, width = 4000)
  zone_10km_mle <- buffer(zone_1km_mle, width = 9000)
  
  # --- PUSH BACK TO GLOBAL ---
  list_1km[[as.character(zone)]]  <- project(zone_1km_mle, "EPSG:4326")
  list_5km[[as.character(zone)]]  <- project(zone_5km_mle, "EPSG:4326")
  list_10km[[as.character(zone)]] <- project(zone_10km_mle, "EPSG:4326")
}

message("Stitching UTM zones back together using Spherical Math...")

# 1. Combine the lists into terra vectors (Do NOT dissolve yet!)
combined_1km <- vect(list_1km)
combined_5km <- vect(list_5km)
combined_10km <- vect(list_10km)

# 2. Convert to 'sf' to unlock the S2 spherical engine
sf_1km <- st_as_sf(combined_1km)
sf_5km <- st_as_sf(combined_5km)
sf_10km <- st_as_sf(combined_10km)

# 3. Clean any micro-errors and Dissolve (Union) across the globe
message("Dissolving 1km...")
sf_1km <- st_make_valid(sf_1km)
sf_1km <- st_union(sf_1km)

message("Dissolving 5km...")
sf_5km <- st_make_valid(sf_5km)
sf_5km <- st_union(sf_5km)

message("Dissolving 10km...")
sf_10km <- st_make_valid(sf_10km)
sf_10km <- st_union(sf_10km)

# 4. Bring the clean, merged polygons back to 'terra'
poly_1km_mle <- vect(sf_1km)
poly_5km_mle <- vect(sf_5km)
poly_10km_mle <- vect(sf_10km)

# 5. Re-attach the country codes
poly_1km_mle$country_code <- iso
poly_5km_mle$country_code <- iso
poly_10km_mle$country_code <- iso

# 6. Export safely to Geopackage
output_file <- paste0(layers, "coastal_buffers_dep/", iso, "_mle_buffers.gpkg")

message("Saving Fiji to disk...")
writeVector(poly_1km_mle, output_file, layer = paste0(iso, "_buffer_1km"), overwrite = TRUE)
writeVector(poly_5km_mle, output_file, layer = paste0(iso, "_buffer_5km"), insert = TRUE)
writeVector(poly_10km_mle, output_file, layer = paste0(iso, "_buffer_10km"), insert = TRUE)

message("Fiji processing complete!") 