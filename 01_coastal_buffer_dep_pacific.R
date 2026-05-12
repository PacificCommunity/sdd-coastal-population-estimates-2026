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
# for the moment we import directly from # https://data.digitalearthpacific.org/#dep_ls_coastlines/

# Load layer covers whole pacific
cline <- vect(paste0(layers,"dep_ls_coastlines_0-7-0-55.gpkg"))


# Extract country names
iso3 <- unique(cline$eez_territory)

# Heavy processes
big_iso3 <- c("PNG", "PYF", "VUT", "FJI", "SBL")
# Rest of the countries that will go into single loop
small_iso3 <- setdiff(iso3, big_iso3)

# Remove insufficient or unstable data
cline <- cline|> 
  filter(certainty == "good")

# Simplify once so we do not repeat same process 22 times
tic()
cline_simple <- simplifyGeom(cline, tolerance = 10)
toc()

# 3. BATCH COMPUTING BUFFER CREATION for SMALL countries =======================
target <- small_iso3

## 3.1 Set up log file ----
log_file <- "buffer_processing_log.txt"
cat(paste("--- Batch Started:", Sys.time(), "---\n"), file = log_file, append = TRUE)

## 3.2 Looping buffer creation ----

for (iso in target) {
  message(paste("Processing: ", iso))
  
  # Try catch, if the code it crashes, it catch the error, save it and then jumps
  # to the next country
  loop_status <<- tryCatch({
    country_lines <- cline_simple |> 
      filter(eez_territory == iso)
  # If the country has zero rows, stop immediately and log it.
    if (nrow(country_lines) == 0) {
      stop("Zero shoreline features found for this country.")
    }
    
    # --- YOUR WORKING GEOMETRY CODE ---

    
    cline_dissol <- aggregate(country_lines, by = "year")
    
    cline_10 <- buffer(cline_dissol, width = 10)
    cline_990 <- buffer(cline_10, width = 990)
    poly_1km_mle <- aggregate(cline_990)
    
    # Extend the buffers to 5 and 10km
    poly_5km_mle <- buffer(poly_1km_mle, width = 4000)
    poly_10km_mle <- buffer(poly_1km_mle, width = 9000)
    
    # NAME variables, layers and files
    poly_1km_mle$country_code <- iso
    poly_5km_mle$country_code <- iso
    poly_10km_mle$country_code <- iso
    
    # Export directly to disk (insert = TRUE appends to the same file)
    output_file <- paste0(layers, "coastal_buffers_dep/", iso3,"_mle_buffers.gpkg")
    
    writeVector(poly_1km_mle, output_file, layer = paste0(iso,"_buffer_1km"), insert = TRUE, overwrite = T)
    writeVector(poly_5km_mle, output_file, layer = paste0(iso,"_buffer_5km"), insert = TRUE)
    writeVector(poly_10km_mle, output_file, layer = paste0(iso,"_buffer_10km"), insert = TRUE)
    
    # If it gets to this line, it succeeded! This message is sent to loop_status.
    paste(iso," SUCCESS")
    
  }, error = function(e) {
    # If ANYTHING fails above, it immediately jumps down here.
    # We capture the exact error message R threw.
    paste("FAILED - Error:", e$message)
  })
  
  # 5. Write the result to the log file immediately
  log_message <- paste(Sys.time(), "| Country:", iso, "| Status:", loop_status, "\n")
  cat(log_message, file = log_file, append = TRUE)
  
  # Print status to the console so you can watch it run
  message(log_message)
  
  # 6. Deep Clean RAM
  # This deletes all temporary objects created in the loop. 
  # suppressWarnings prevents annoying text if an object didn't get created due to a crash.
  suppressWarnings(rm(country_lines, cline_dissol, cline_10, cline_990, 
                      poly_1km_mle, poly_5km_mle, poly_10km_mle))
  
  gc() # Force R to empty the garbage
}

message("Batch processing complete! Check buffer_processing_log.txt for any failures.")


  