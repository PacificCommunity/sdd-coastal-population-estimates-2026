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

# # List of countries in pacific region
# iso3_list <-c ("ASM","COK","FSM","GUM","MHL","MNP","NCL","NIU","NRU","PLW",
# "PNG","PYF","SLB","TON","TUV","VUT","WLF","WSM") # countries not touched by dateline
# iso3_dline_countries <- c("FJI","KIR")

# TEST for NEW CALEDONIA
# 2. IMPORT LAYER INPUT =======================================================
# At some point we will be cropping the raw coastlines with country extent given 
# by the population grids. No need as there is a country code for every line
# for the moment we import directly from # https://data.digitalearthpacific.org/#dep_ls_coastlines/

# Load layer
cline <- vect(paste0(layers,"ncl_dep_ls_coastlines_0-7-0-55.gpkg"))

# Process coastline raw input to streamline process
# Dissolve by year all the pieces to merge each year in one single layer
cline_dissol <- aggregate(cline, by = "year")
# Removing small zig zags that increase unnecesarilly the processing time.
cline_simple <- simplifyGeom(cline_dissol, tolerance = 10)



# 3.1 Maximum Landward Extent (FASTER) =========================================
# Represents the distance from the line that has been land 100% of the cases, 
# the safest scenario, from there we start measuring the distance. This is more
# focused on the Hazard Exposure Zone approach rather than a geographic one which 
# would look for an "averaged" coastline.

# PHASE 1: The Maximum Landward Extent (Vector Union)

# To avoid holes artefacts in small islands, we are converting the lines into
# 10 meters wide ribbons
tic()
cline_10 <- buffer(cline_simple, width = 10)
toc()
# And then generate the 1km buffer extending those ribbons 990 m
tic()
cline_990  <- buffer(cline_10, width = 990)
toc()

# Merge all years into one single baseline network for the MLE

poly_1km_mle <- aggregate(cline_990)

message("Extending vectors to 5km and 10km...")

# Now generate your larger buffers from the properly patched 1km polygon
poly_5km_mle <- buffer(poly_1km_mle, width = 4000)
poly_10km_mle <- buffer(poly_1km_mle, width = 9000)

# Export into layers
message("Saving results...")

writeVector(poly_1km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_1km", overwrite = TRUE)
writeVector(poly_5km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_5km", insert = TRUE)
writeVector(poly_10km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_10km", insert = TRUE)


