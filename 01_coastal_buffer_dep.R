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


# 3. GENERATE BUFFERS ==========================================================

# Two Approaches
## 3.1 Averaged Coastal Line -----
# Represents the median line between all the registries, is where the ground is land 
# 50% of the cases and water the other 50%
# We are not filtering by certainty as we are keeping all registries. Discuss with DEP to do this eventually



## 3.2 Maximum Landward Extent ------
# Represents the distance from the line that has been land 100% of the cases, 
# the safest scenario, from there we start measuring the distance. This is more
# focused on the Risk Exposure Zone

