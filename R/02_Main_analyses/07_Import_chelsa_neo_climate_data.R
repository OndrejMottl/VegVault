#----------------------------------------------------------#
#
#
#                       VegVault
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
    "OndrejMottl/VegVault-abiotic_data/",
    "v1.1.0/",
    "Outputs/Data/Neoclimate/"
  )


#----------------------------------------------------------#
# bio 1 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_01_2024-08-06__ff1659d322855ca35555ac7b96d58720__.qs"
  ),
  sel_var_name = "bio1",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 4 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_04_2024-08-06__1604d03e5861ab5c68ec199aa62149b7__.qs"
  ),
  sel_var_name = "bio4",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 6 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_06_2024-08-06__8655ad5eb3ceb3994277951094153411__.qs"
  ),
  sel_var_name = "bio6",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 12 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_12_2024-08-06__3e022b521abfc6d64a90fb20de924335__.qs"
  ),
  sel_var_name = "bio12",
  sel_var_unit = "kg m-2 year-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 15 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_15_2024-08-06__2e55d4f662c36b33b567bbf185d215d7__.qs"
  ),
  sel_var_name = "bio15",
  sel_var_unit = "Unitless",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 18 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_18_2024-08-06__c557a3c886862a522c9679326a61484f__.qs"
  ),
  sel_var_name = "bio18",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)


#----------------------------------------------------------#
# bio 19 -----
#----------------------------------------------------------#

add_chelsa_neo_data(
  sel_con = con,
  sel_url = paste0(
    url_gh_abiotic,
    "CHELSA_bio_19_2024-08-06__e1772a85924f59dd209b3f0aa09e60cf__.qs"
  ),
  sel_var_name = "bio19",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.1038/sdata.2017.122",
  sel_var_detail = "CHELSA"
)
