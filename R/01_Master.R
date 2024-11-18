#----------------------------------------------------------#
#
#
#                       VegVault
#
#                  Import Vegetation data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Import all data by running other scripts

#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here(
    "R/00_Config_file.R"
  )
)

#----------------------------------------------------------#
#  1. Run scripts -----
#----------------------------------------------------------#

# Make database
source(
  here::here(
    "R/01_Data_processing/00_make_database.R"
  )
)

# Import splot data
source(
  here::here(
    "R/02_Main_analyses/01_Import_splot_data.R"
  )
)

# Import BIEN data
source(
  here::here(
    "R/02_Main_analyses/02_Import_BIEN_data.R"
  )
)

# Import FOSSILPOL data
source(
  here::here(
    "R/02_Main_analyses/03_Import_fossilpol_data.R"
  )
)

# Import TRY data
source(
  here::here(
    "R/02_Main_analyses/04_Import_try_data.R"
  )
)

# Import BIEN trait data
source(
  here::here(
    "R/02_Main_analyses//05_Import_bien_trait_data.R"
  )
)

# Make gridpoints
source(
  here::here(
    "R/02_Main_analyses/06_Create_gridpoints.R"
  )
)

# Import CHELSA climate data
source(
  here::here(
    "R/02_Main_analyses/07_Import_chelsa_neo_climate_data.R"
  )
)

# Import CHELSA-TRACE21K climate data
source(
  here::here(
    "R/02_Main_analyses/08_Import_chelsa_trace21k_climate_data.R"
  )
)

# Import WOSIS soil data
source(
  here::here(
    "R/02_Main_analyses/09_Import_wosis_soil_data.R"
  )
)

# Classify all taxa in DB
source(
  here::here(
    "R/02_Main_analyses/10_Classify_taxa.R"
  )
)


# Classify all taxa in DB
source(
  here::here(
    "R/02_Main_analyses/11_Check_database.R"
  )
)
