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
# bio 1 -----
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
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 4 -----
#----------------------------------------------------------#

bio4_hash <-
  c(
    "bio04_batch_1_2024-01-02__36c3bf7eaf751dd87c88572616223b9c__.qs",
    "bio04_batch_2_2024-01-02__74c600653097d990fec92d40beb6a557__.qs",
    "bio04_batch_3_2024-01-02__92dfb070c075499d2d9b77f901d0f739__.qs",
    "bio04_batch_4_2024-01-02__5d51cb18bd5c8101eb6e3705fea54ab7__.qs",
    "bio04_batch_5_2024-01-02__72224b81f4602b6ef6d8229bddb68e55__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio4_hash,
  sel_var_name = "bio4",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 6 -----
#----------------------------------------------------------#

bio6_hash <-
  c(
    "bio06_batch_1_2024-01-02__211593e840d69410dbb3fda2e044ca0f__.qs",
    "bio06_batch_2_2024-01-02__77b394961d94acb5401545fa828a02ca__.qs",
    "bio06_batch_3_2024-01-02__4817bc0ebf905493c47cdd6032de533c__.qs",
    "bio06_batch_4_2024-01-02__1d574ea247a0be371242b322dd65fa30__.qs",
    "bio06_batch_5_2024-01-02__02c03be82d30e91d7cff18612f99ce93__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio6_hash,
  sel_var_name = "bio6",
  sel_var_unit = "°C",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 12 -----
#----------------------------------------------------------#

bio12_hash <-
  c(
    "bio12_batch_1_2024-01-02__879c70c6b0c5734d9158203e0b78234d__.qs",
    "bio12_batch_2_2024-01-02__3e93995da7101616071866415471080b__.qs",
    "bio12_batch_3_2024-01-02__66df86e3fe749bd5edf391bb91a14c0d__.qs",
    "bio12_batch_4_2024-01-02__4ab5a7aab2eff0b639ce9df85210eb96__.qs",
    "bio12_batch_5_2024-01-02__cb482577798841955c9a77c4c65c4b8c__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio12_hash,
  sel_var_name = "bio12",
  sel_var_unit = "kg m-2 year-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 15 -----
#----------------------------------------------------------#

bio15_hash <-
  c(
    "bio15_batch_1_2024-01-02__485c339599c32a77b2cb4cd549dff2d7__.qs",
    "bio15_batch_2_2024-01-02__43c464ceada9e1ed2c94275e6fb1f32b__.qs",
    "bio15_batch_3_2024-01-02__4a5a703d16ca4c52980bf14353a3bb3f__.qs",
    "bio15_batch_4_2024-01-02__de127f43a6cf2d51a970c9529d0b61fe__.qs",
    "bio15_batch_5_2024-01-02__b698ef571dd8f934332e2355d8186bf7__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio15_hash,
  sel_var_name = "bio15",
  sel_var_unit = "Unitless",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 18 -----
#----------------------------------------------------------#

bio18_hash <-
  c(
    "bio18_batch_1_2024-01-02__2863e2d24f19ff79e4666dc0ca351699__.qs",
    "bio18_batch_2_2024-01-02__47db5ae8ffa972af3b0196237f6c9282__.qs",
    "bio18_batch_3_2024-01-02__cc9c13c22f18993480587e7899eb3fb0__.qs",
    "bio18_batch_4_2024-01-02__7cc2eef1bf68c100a6399cea7aac2f78__.qs",
    "bio18_batch_5_2024-01-02__82d8f449cbf802b1f40202ba316b111c__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio18_hash,
  sel_var_name = "bio18",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)

#----------------------------------------------------------#
# bio 19 -----
#----------------------------------------------------------#

bio19_hash <-
  c(
    "bio19_batch_1_2024-01-02__2ea92fbda0b6218030fbb787c394c2e2__.qs",
    "bio19_batch_2_2024-01-02__19dc681d8b6b2ab021b1595ed0102cf7__.qs",
    "bio19_batch_3_2024-01-02__fbe8c00dcc0255265f117eeaa7ceb409__.qs",
    "bio19_batch_4_2024-01-02__8efb9458536960e5a579b84b1248ba59__.qs",
    "bio19_batch_5_2024-01-02__e8a5ac69dbeb6dbc06dfcc1c87909d2f__.qs"
  )

add_chelsa_trace_data(
  sel_url = url_gh_abiotic,
  sel_hash = bio19_hash,
  sel_var_name = "bio19",
  sel_var_unit = "kg m-2 quarter-1",
  sel_var_reference = "https://doi.org/10.5194/cp-2021-30",
  sel_var_detail = "CHELSA-TRACE21K"
)
