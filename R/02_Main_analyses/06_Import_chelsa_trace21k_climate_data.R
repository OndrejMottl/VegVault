#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#              Import CHELSA-TRACE21K climate data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import climate data from CHELSA-TRACE21K

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

DBI::dbListTables(con)


#----------------------------------------------------------#
# 2. Load data -----
#----------------------------------------------------------#

url_gh_abiotic <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-abiotic_data/",
    "main/",
    "Outputs/Data/Palaoclimate/"
  )

#----------------------------------------------------------#
# 2. bio 1 -----
#----------------------------------------------------------#

bio1_hash <-
  c(
    "bio01_batch_1_2024-01-02__05b0b43b6640a26c729b0403e711993f__.qs",
    "bio01_batch_2_2024-01-02__f728c578e64054e96e1671829a1971f2__.qs",
    "bio01_batch_3_2024-01-02__636dae96f45c34f2f63a579f7bba9ec6__.qs",
    "bio01_batch_4_2024-01-02__c432f3ecedeae729f35914f02a6f65dc__.qs",
    "bio01_batch_5_2024-01-02__3d4236481e4131ed665474d6dc7a9b41__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio1_hash,
  sel_var_name = "bio1",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K",
)
