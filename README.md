# sdd-coastal-population-estimates-2026
Coastal Population 1,5,10km from the coast assessment

Scripts for Spatial Analysis to identify Population living within 1, 5 and 10km Coastal buffers
1.	Main goal
The aim of this analysis is to update the coastal population assessment in the Pacific region indicators taking advantage of the new spatial datasets available since the last time the analysis was carried out. 
-	Population grids have been updated for many countries in the region using latest 2025 and 2026 census data so we have a better idea of the spatial distribution of the population at reasonable resolution levels.
-	New and better population projections will allow us to produce more accurate coastal population counts.
-	Population grids for American and French territories as well as for Papua New Guinea are included from Worldpop so our analysis covers the entire region.
-	We will compare this iteration using DEP shorelines with the previous update that was using **https://gee-community-catalog.org/projects/shoreline/**
An additional objective of this analysis is to streamline and script the entire process with the objective of improving the reproducibility, documentation and future updates when new data inputs were available.


# Pacific Coastal Population Update 2026 — Processing & Analysis Pipeline

This repository documents the end-to-end data processing and spatial analysis pipeline carried out for the **2026 Pacific Coastal Population Update**.
The pipeline integrates remote sensing-derived shorelines, high-resolution population grids, and national statistics to calculate and compare the percentage of populations living within coastal zones (1km, 5km, and 10km buffers) across the Pacific region.

# Pacific Coastal Population Update 2026 — Processing & Analysis Pipeline

This repository documents the end-to-end data processing and spatial analysis pipeline carried out for the **2026 Pacific Coastal Population Update**. The pipeline integrates remote sensing-derived shorelines, high-resolution population grids, and national statistics to calculate and compare the percentage of populations living within coastal zones (1km, 5km, and 10km buffers) across the Pacific region.

The core pipeline has been re-architected to align directly with the file naming convention and chronological sequence of the scripts.

---

## Pipeline Architecture Overview

The processing is executed across the core scripts in the workspace, moving sequentially from buffer generation to global database exporting, local buffer creations, and finally statistical population aggregation. The workflow sequence is as follows:

```
[Step 1: DEP Shoreline Buffers] ────────► [Fiji / Date Line Special Handling]
  │ (01_coastal_buffer_dep_pacific.R)        │
  ▼                                          ▼
[Step 2A: GEE Shoreline Export] ────────► [Step 2B: Global Shoreline Buffers]
  │ (02_GEE Script global shoreline.js)      │ (02_GEE Script global shoreline.js)
  ▼                                          ▼
[Step 3: Zonal Statistics & Comparative Analysis]
  (04_coastal_population_estimate_dep_coastline.R)
```

---

## Core Data Sources

1. **Digital Earth Pacific (DEP) Coastlines:**
   - **Source:** Digital Earth Pacific (`dep_ls_coastlines_0-7-0-55.gpkg`), accessible at [Digital Earth Pacific](https://data.digitalearthpacific.org/#dep_ls_coastlines/).
   - **Characteristics:** Remote sensing-derived shorelines optimized for Pacific Island countries and territories.
2. **Global Shoreline Dataset (GSD):**
   - **Source:** community-provided via the Earth Engine Catalog (`sat-io` community open-datasets).
   - **Components:** Mainland, big islands, and small islands shoreline vector layers.
3. **Population Grids (2026 projections):**
   - **SDD Grids:** Statistics for Development Division (SDD) native Pacific population grids (`t_pop_2026.*.tif`).
   - **WorldPop Grids:** Constrained/unconstrained 100m resolution global population projections for 2026, downloaded automatically as fallback.
4. **Official National Statistics:**
   - **Source:** Pacific Data Hub (PDH) (`pop_stat.csv` containing official 2026 population totals).

---

## Detailed Component Breakdown

### 1. Coastal Buffers Derived from Digital Earth Pacific (DEP) Coastlines
- **File Name:** `01_coastal_buffer_dep_pacific.R`
- **Objective:** Construct high-accuracy, remote sensing-derived coastal buffers using the DEP dataset, utilizing advanced geoprocessing to resolve topology and coordinate system issues.
- **Key Operations:**
  - Imports the master DEP coastlines geopackage (`dep_ls_coastlines_0-7-0-55.gpkg`) and filters out unstable data (`certainty == "good"`).
  - Simplifies geometry once with a 10m tolerance and reprojects to `EPSG:4326` (WGS 84) to optimize downstream processing.
  - Splits countries into **Small Countries** (processed in a single batch loop) and **Big Countries** (PNG, PYF, VUT, SLB, handled individually to manage memory footprint).
  - **Fiji (FJI) Date Line & Topology Failsafe:** Fiji crosses the 180° Meridian, which routinely causes planar geometry calculations to crash. 
    The script isolates Fiji and implements a surgical workflow: 
    1. Converts the vector layer to `sf` format to utilize robust spatial engines.
    2. Slices the Date Line using `st_wrap_dateline(..., options = c("WRAPDATELINE=YES"))` and cleans errors with `st_make_valid()`.
    3. Converts back to `terra` format.
    
  - 1, 5 and 10km buffers generation process for both big and small countries.
    1. Computes UTM zones for individual islands/atolls dynamically based on segment centroids.
    2. For each local UTM zone:
       - Projects lines to the local metric UTM CRS.
       - Dissolves lines by year.
       - Simplifies geometry (10m tolerance) and repairs topology (`makeValid()`).
       - Generates metric buffers: 10m base buffer, then 990m (yielding 1km total), 4,000m (yielding 5km total), and 9,000m (yielding 10km total).
       - Projects back to global `EPSG:4326`.
    3. Combines individual UTM buffer lists, converts to `sf` to engage the **S2 Spherical Geometry engine**, resolves micro-errors with `st_make_valid()`, and executes a global dissolution (`st_union()`).
    4. Re-attaches ISO3 country codes and exports safely to `coastal_buffers_dep/(ISOcode)_mle_buffers.gpkg`

### 2. Global Shoreline Dataset Pipeline
The processing of the Global Shoreline Dataset spans two representation formats within the same core reference index:

#### 2A. Google Earth Engine (GEE) Shoreline Export
- **File Name:** `02A_GEE Script global shoreline.js` (JavaScript Script)
- **Objective:** Extract and clip global shoreline features to individual country extents for the Pacific region.
- **Key Operations:**
  - Imports three shoreline feature collections from the sat-io catalog: `mainlands`, `big_islands`, and `small_islands`.
  - Merges the collections into a single master shoreline dataset.
  - Defines manual geographic bounding boxes (rectangles) for 18 Pacific jurisdictions: American Samoa (ASM), Cook Islands (COK), Federated States of Micronesia (FSM), Guam (GUM), Marshall Islands (MHL), Northern Mariana Islands (MNP), New Caledonia (NCL), Niue (NIU), Nauru (NRU), Palau (PLW), French Polynesia (PYF), Solomon Islands (SLB), Tonga (TON), Tuvalu (TUV), Vanuatu (VUT), Wallis and Futuna (WLF), Samoa (WSM), Fiji (FJI), and Kiribati (KIR). (Note: Papua New Guinea is excluded from this automatic batch and handled separately).
  - Iterates through the extents, clips the merged shoreline to each country bounding box, visualizes it on the GEE Map in green, and exports the resulting vector data to Google Drive as a GeoJSON in the folder `Pacific_Shorelines`.

#### 2B. Coastal Buffers Derived from Global Shoreline Dataset
- **File Name:** `02B_globshore_buffers_processing.R` 
- **Objective:** Convert exported Global Shoreline polygons into lines and construct standard metric buffers (1km, 5km, 10km).
- **Key Operations:**
  - Loads all `.shp` shapefiles from the local folder `coastal buffers globalshore/input/`.
  - Extracts the ISO3 country code and native EPSG coordinate code from each shapefile.
  - Dissolves (unions) polygons by ISO3 to create a single spatial record.
  - Converts the boundary polygons into line layers (`as.lines()`).
  - Generates buffers at standard metric intervals: 1,000m (1km), 5,000m (5km), and 10,000m (10km).
  - Exports the buffers into separate layer Geopackages (`.gpkg`) labeled `[ISO3]_1km.gpkg`, `[ISO3]_5km.gpkg`, and `[ISO3]_10km.gpkg`.
  - **Required Manual Adjustments:** After the batch run, manual cleaning is performed to:
    - Remove river systems and terrestrial country borders from the Papua New Guinea (PNG) layers.
    - Fill internal rings/holes in Nauru's (NRU) 5km and 10km buffers generated by self-intersection topology errors.

### 3. Coastal Population Update 2026 & Comparative Analysis
- **File Name:** `04_coastal_population_estimate_dep_coastline.R`
- **Objective:** Execute zonal statistics to calculate populations residing within buffers, format outputs, and compare the spatial coverage of DEP vs. Global Shoreline datasets.
- **Key Operations:**
  - **Population Grid Assembly:**
    - Scans Sharepoint/local drive for native SDD population grids (`t_pop_2026.*.tif`).
    - Identifies missing countries (via `setdiff`) and automatically downloads 2026 WorldPop 100m constrained population grids via URLs structured as `https://data.worldpop.org/GIS/Population/Global_2015_2030/R2025A/2026/[iso3]/v1/100m/constrained/...`.
    - Merges local SDD grids and WorldPop grids into a sorted, comprehensive master list of Pacific population rasters.
  - **Zonal Statistics Integration:**
    - Loads official 2026 national population totals from the Pacific Data Hub (PDH) via `pop_stat.csv`.
    - Iterates over DEP buffer layers, extracts corresponding population grids, sums the population within the 1km, 5km, and 10km zones, and outputs an Excel spreadsheet (`[Date]_coastal_population_dep_2026.xlsx`) containing headcounts and percentages of national totals.
    - Repeats the identical process for Global Shoreline buffers, outputting results to `[Date]_coastal_population_gs_2026.xlsx`.
  - **Comparative Analysis:**
    - Merges DEP and GSD tables.
    - Computes absolute headcount differences and percentage differences (`diff_1kmb_pop_per`, `diff_5kmb_pop_per`, `diff_10kmb_pop_per`).
    - Uses `ggplot2` to generate a multi-group bar plot showing delta values by country and buffer distance, and renders it to visualize spatial deviations between the two shoreline datasets.

---

## Advanced Geoprocessing Key Concepts

### UTM-Based Local Metric Buffering
In order to guarantee that buffer widths are exactly 1km, 5km, and 10km across the vast, island-scattered Pacific, calculations cannot be performed directly in geographic coordinates (degrees). The pipeline dynamically calculates the centroid of each island group, assigns the correct local UTM zone, projects the lines to meters, runs the buffers, and projects the resulting polygons back to EPSG:4326 for global stitching.

### Date Line & Spherical Math Handling
Standard planar spatial operations fail or create huge artifacts when layers cross or wrap around the 180° meridian (e.g., Fiji and Kiribati). This pipeline bypasses planar limitations by:
1. Slicing vectors at the 180° meridian (`st_wrap_dateline`).
2. Projecting and buffering within localized UTM zones.
3. Conducting the final multi-zone union in the **S2 Spherical Geometry Engine** (provided by R's `sf` package), which operates directly on a sphere rather than a flattened plane, preventing topology corruption.

---

## Directory & Environment Requirements

To execute these scripts locally, establish the following folder structure and configure the paths in `setup.R`:

```
├── SDD GIS - Documents/
│   ├── Pacific PopGrid/
│   │   └── UPDATE_2026/                       <- SDD .tif Grids
│   │       └── WorldPop/                      <- Downloaded WorldPop fallback grids
│   └── Coastal Population/
│       ├── CoastPop_Update2025/
│       │   └── Data/
│       │       └── coastal buffers globalshore/ <- GSD Buffer outputs & inputs
│       └── CoastPop_Update2026/
│           ├── Data/
│           │   ├── pop_stat.csv               <- PDH official totals
│           │   ├── dep_ls_coastlines_0-7-0-55.gpkg
│           │   └── coastal_buffers_dep/       <- DEP Buffer outputs
│           └── Results/                       <- Excel and ggplot outputs
```

*Developed by Statistics for Development Division (SDD) - Secretariat of the Pacific Community (SPC).*
