#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Import WOSIS soil data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import soil data from WOSIS

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
# 2. Download data -----
#----------------------------------------------------------#

url_gh_wosis <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-abiotic_data/",
    "v1.0.0/",
    "Outputs/Data/WoSIS/",
    "wosis_data_2024-01-03__3552eb2fc1af7f991c10e4fc6c2decb7__.qs"
  )

data_wosis <-
  dowload_and_load(url_gh_wosis)


#----------------------------------------------------------#
# 3. Add data -----
#----------------------------------------------------------#

data_wosis_dataset_raw <-
  data_wosis %>%
  dplyr::mutate(
    dataset_type = "gridpoints",
    dataset_source_type = "gridpoints",
    data_source_type_reference = "artificially created by O. Mottl",
    data_source_desc = "gridpoints",
    data_source_reference = "artificially created by O. Mottl",
    dataset_reference = "artificially created by O. Mottl",
    coord_long = as.numeric(long),
    coord_lat = as.numeric(lat),
    age = 0
  ) %>%
  dplyr::mutate(
    dataset_name = paste(
      "geo", round(coord_long, digits = 2), round(coord_lat, digits = 2),
      sep = "_"
    )
  )

# dataset type -----
data_wosis_dataset_type_db <-
  add_dataset_type(
    data_source = data_wosis_dataset_raw,
    con = con
  )

# dataset source type -----
data_wosis_dataset_source_type_db <-
  add_dataset_source_type(
    data_source = data_wosis_dataset_raw,
    con = con
  )

# dataset source -----
data_wosis_data_source_id_db <-
  add_data_source(
    data_source = data_wosis_dataset_raw,
    con = con
  )

# datasets -----
wosis_dataset_id_db <-
  add_datasets(
    data_source = data_wosis_dataset_raw,
    con = con,
    data_type = data_wosis_dataset_type_db,
    data_source_type = data_wosis_dataset_source_type_db,
    dataset_source = data_wosis_data_source_id_db
  )


# samples -----
data_wosis_samples_raw <-
  data_wosis_dataset_raw %>%
  dplyr::left_join(
    wosis_dataset_id_db,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::mutate(
    sample_name = paste0(
      "geo_",
      dataset_id,
      "_",
      age
    ),
    sample_size = NA_real_,
    description = "gridpoint",
    sample_reference = "artificially created by O. Mottl",
    abiotic_variable_name = var_name,
    var_unit = "Unitless",
    var_reference = "https://doi.org/10.5194/soil-7-217-2021",
    var_detail = "WoSIS-SoilGrids"
  )

wosis_samples_id_db <-
  add_samples(
    data_source = data_wosis_samples_raw,
    con = con
  )

# Dataset - Sample -----
add_dataset_sample(
  data_source = data_wosis_samples_raw,
  con = con,
  dataset_id = wosis_dataset_id_db,
  sample_id = wosis_samples_id_db
)

# Abiotic varibale
abiotic_variabe_id <-
  add_abiotic_variable(
    data_source = data_wosis_samples_raw,
    con = con
  )

add_sample_abiotic_value(
  data_source = data_wosis_samples_raw,
  con = con,
  sample_id = wosis_samples_id_db,
  abiotic_variable_id = abiotic_variabe_id
)

#----------------------------------------------------------#
# 4. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
