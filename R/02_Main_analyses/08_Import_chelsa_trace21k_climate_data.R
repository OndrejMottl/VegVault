#----------------------------------------------------------#
#
#
#                       VegVault
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
    "OndrejMottl/VegVault-abiotic_data/",
    "v1.1.0/",
    "Outputs/Data/Palaoclimate/"
  )


#----------------------------------------------------------#
# bio 1 -----
#----------------------------------------------------------#

bio1_hash <-
  c(
    "bio01_batch_1_2024-08-06__f674adeb38401a05236e0b5e0ad7cc53__.qs",
    "bio01_batch_2_2024-08-06__b32dfb2e39d295750dc67f1dc145c176__.qs",
    "bio01_batch_3_2024-08-06__e6997e401e83f216ecf697e2ce3aefe0__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio1_hash,
  sel_var_name = "bio1",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 4 -----
#----------------------------------------------------------#

bio4_hash <-
  c(
    "bio04_batch_1_2024-08-06__7d41bdef6e12869aab0de7b47e130785__.qs",
    "bio04_batch_2_2024-08-06__ad97d74cf36c6c94f865c26487435c13__.qs",
    "bio04_batch_3_2024-08-06__c1ec1e4a50f1f5bf870cf89a3cc8e9b6__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio4_hash,
  sel_var_name = "bio4",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 6 -----
#----------------------------------------------------------#

bio6_hash <-
  c(
    "bio06_batch_1_2024-08-06__0827ee8641b8d71c1a16d6ed85448aaf__.qs",
    "bio06_batch_2_2024-08-06__719d895a789331fbc95820b24a04259e__.qs",
    "bio06_batch_3_2024-08-06__3bcc0894f7a5c69aca9b6cd5493f9206__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio6_hash,
  sel_var_name = "bio6",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 12 -----
#----------------------------------------------------------#

bio12_hash <-
  c(
    "bio12_batch_1_2024-08-06__ba82b2c5dc1ab5a7b97c3527ce46265e__.qs",
    "bio12_batch_2_2024-08-06__f2a76cda2a9c7ea2c491502d1adfade6__.qs",
    "bio12_batch_3_2024-08-06__ceb6c89f684320e1ec10eb82ba0216bf__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio12_hash,
  sel_var_name = "bio12",
  sel_var_unit = "kg m-2 year-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 15 -----
#----------------------------------------------------------#

bio15_hash <-
  c(
    "bio15_batch_1_2024-08-06__edba0614ca701873093d577b70cc4a6c__.qs",
    "bio15_batch_2_2024-08-06__638f5743410ce55e18e6ad24cd010921__.qs",
    "bio15_batch_3_2024-08-06__1ed1fa8354631ac7cff01e358b7b4b19__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio15_hash,
  sel_var_name = "bio15",
  sel_var_unit = "Unitless",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 18 -----
#----------------------------------------------------------#

bio18_hash <-
  c(
    "bio18_batch_1_2024-08-06__a35109a22de915b80036bdf5b2b132cb__.qs",
    "bio18_batch_2_2024-08-06__e22b69aaeaf67c8a43a261930b3e9ef1__.qs",
    "bio18_batch_3_2024-08-06__7e89dae901e03f2a6f25fead30d31c7f__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio18_hash,
  sel_var_name = "bio18",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)

#----------------------------------------------------------#
# bio 19 -----
#----------------------------------------------------------#

bio19_hash <-
  c(
    "bio19_batch_1_2024-08-06__744a39246a6da0617cbad452e8388148__.qs",
    "bio19_batch_2_2024-08-06__a710a5bfd1db6435baa6d6a269c8a4d4__.qs",
    "bio19_batch_3_2024-08-06__9444836f269f8eb06032d0540391c662__.qs"
  )

add_chelsa_trace_data(
  sel_con = con,
  sel_url = url_gh_abiotic,
  sel_hash = bio19_hash,
  sel_var_name = "bio19",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA"
)
