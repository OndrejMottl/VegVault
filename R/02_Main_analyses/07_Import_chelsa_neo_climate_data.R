#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#              Import CHELSA climate data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import neo climate data from CHELSA

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
# 1. Connect to db -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )


#----------------------------------------------------------#
# 2. Get the GH url -----
#----------------------------------------------------------#

url_gh_abiotic <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-abiotic_data/",
    "main/",
    "Outputs/Data/Neoclimate/"
  )


#----------------------------------------------------------#
# bio 1 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_01_2024-01-03__811f09c0d86581eae1d3458e6d795cf2__.qs"
  ),
  sel_var_name = "bio1",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 4 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_04_2024-01-03__894c6d295414ecd53b9d9890d98e3f64__.qs"
  ),
  sel_var_name = "bio4",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 6 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_06_2024-01-03__fdf92f7e1ee51114f76c7282e3271fa9__.qs"
  ),
  sel_var_name = "bio6",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 12 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_12_2024-01-03__c0ea80d954d234afcf0a847bf353dcfe__.qs"
  ),
  sel_var_name = "bio12",
  sel_var_unit = "kg m-2 year-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 15 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_15_2024-01-03__ebe80c5d46f45e0953a5f8efcdcf27f1__.qs"
  ),
  sel_var_name = "bio15",
  sel_var_unit = "Unitless",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 18 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_18_2024-01-03__038a79f5cec5e82d34ae4da98a687795__.qs"
  ),
  sel_var_name = "bio18",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)


#----------------------------------------------------------#
# bio 19 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_19_2024-01-03__9dae291cd952506b5dd4112c16762c97__.qs"
  ),
  sel_var_name = "bio19",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA_V2.1"
)
