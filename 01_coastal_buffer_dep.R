## COASTAL BUFFERS DERIVED FROM DIGITAL EARTH PACIFIC COASTLINES DATASET ##
# https://data.digitalearthpacific.org/#dep_ls_coastlines/
# THIS SCRIPT USES SHORELINE DERIVED FROM REMOTE SENSING TO GENERATE THE 
# COASTAL BUFFERS IMPROVING.

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
# iso3_list <-c ("ASM","COK","FSM","GUM","MHL","MNP","NCL","NIU","NRU","PLW","PNG","PYF","SLB","TON","TUV","VUT","WLF","WSM") # countries not touched by dateline
# iso3_dline_countries <- c("FJI","KIR")

# TEST for NEW CALEDONIA
# 2. IMPORT LAYER INPUT =======================================================
# At some point we will be croping the raw coastlines with country extent given 
# by the population grids. No need as there is a country code for every line
# for the moment we import directly

cline <- vect(paste0(layers,"ncl_dep_ls_coastlines_0-7-0-55.gpkg"))

# Prcess coastline raw input to streamline process
# Dissolve by year all the pieces to merge each year in one single layer
cline_dissol <- aggregate(cline, by = "year")
# Removing small zig zags that increase unnecesarilly the processing time.
cline_simple <- simplifyGeom(cline_dissol, tolerance = 10)



## 3.1 Maximum Landward Extent (FASTER) ---------------------------------------
# Represents the distance from the line that has been land 100% of the cases, 
# the safest scenario, from there we start measuring the distance. This is more
# focused on the Risk Exposure Zone


# PHASE 1: The Maximum Landward Extent (Vector Union)
tic()
message("Calculating 1km Maximum Landward Extent...")

# Merging 22 years into a single coastline network
single_network <- aggregate(cline_simple)

# To avoid holes artefacts in small islands, we are converting the lines into
# 10 meters wide ribbons

cline_10 <- buffer(single_network, width = 10)

# And then generate the 1km buffer extending those ribbons 990 m

poly_1km_mle <- buffer(cline_10, width = 990)

message("Extending vectors to 5km and 10km...")

# Now generate your larger buffers from the properly patched 1km polygon
poly_5km_mle <- buffer(poly_1km_mle, width = 4000)
poly_10km_mle <- buffer(poly_1km_mle, width = 9000)

# Save your final results...

message("Saving results...")

writeVector(poly_1km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_1km", overwrite = TRUE)
writeVector(poly_5km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_5km", insert = TRUE)
writeVector(poly_10km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_10km", insert = TRUE)

toc()





















message("Calculating 1km Maximum Landward Extent buffer...")

# Step A: Buffer EVERY year's line by 1km simultaneously.
# This creates 22 overlapping 1km ribbon polygons.
all_years_1km <- buffer(cline_simple, width = 1000)

# Step B: Aggregate (Union/Dissolve) all 22 overlapping ribbons into ONE single shape.
# terra's aggregate() tool without a 'by' argument just melts everything together.
# The inland edge of this mega-polygon is exactly 1km from the furthest 
# inland reach of the water over the 22-year period.
poly_1km_mle <- aggregate(all_years_1km)
# THE FIX: Fill all interior rings/holes in the polygons
poly_1km_mle <- fillHoles(poly_1km_mle)

# fill holes as these artifacts appear on small islands where coastlines are not
# clossing

# The Fast Vector Extensions (5km and 10km)

message("Extending vectors to 5km and 10km...")

# Just like your brilliant optimization before, we just add distance 
# to the outside of the new clean 1km polygon.
poly_5km_mle <- buffer(poly_1km_mle, width = 4000)
poly_10km_mle <- buffer(poly_1km_mle, width = 9000)

# --------------------------------------------------------- #
# PHASE 3: Export
# --------------------------------------------------------- #
message("Saving results...")

writeVector(poly_1km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_1km", overwrite = TRUE)
writeVector(poly_5km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_5km", insert = TRUE)
writeVector(poly_10km_mle, paste0(layers,"mle_coastal_buffers.gpkg"), layer = "mle_buffer_10km", insert = TRUE)

message("Maximum Landward Extent buffers generated successfully!")
