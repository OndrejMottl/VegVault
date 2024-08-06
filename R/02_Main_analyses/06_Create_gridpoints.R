#----------------------------------------------------------#
#
#
#                       VegVault
#
#             Create gridpoints for abiotic data
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Make a set of gridpoints for the abiotic data

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
# 2. Load data -----
#----------------------------------------------------------#

# Use paleoclimate data as template for creating the gridpoints

url_gh_abiotic <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-abiotic_data/",
    "v1.0.0/",
    "Outputs/Data/Palaoclimate/"
  )

bio1_hash <-
  c(
    "bio01_batch_1_2024-01-02__05b0b43b6640a26c729b0403e711993f__.qs",
    "bio01_batch_2_2024-01-02__f728c578e64054e96e1671829a1971f2__.qs",
    "bio01_batch_3_2024-01-02__636dae96f45c34f2f63a579f7bba9ec6__.qs",
    "bio01_batch_4_2024-01-02__c432f3ecedeae729f35914f02a6f65dc__.qs",
    "bio01_batch_5_2024-01-02__3d4236481e4131ed665474d6dc7a9b41__.qs"
  )

data_paleo_climate <-
  bio1_hash %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_abiotic,
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows() %>%
  dplyr::select(-"value")

data_coord <-
  data_paleo_climate %>%
  dplyr::distinct(.data$long, .data$lat) %>%
  tidyr::drop_na()

vec_age <-
  data_paleo_climate %>%
  dplyr::distinct(.data$time_id) %>%
  tidyr::drop_na("time_id") %>%
  dplyr::mutate(
    age = (-as.numeric(.data$time_id) * 100) + 1950
  ) %>%
  dplyr::arrange(.data$age) %>%
  purrr::chuck("age") %>%
  c(0, .)

# Datasets -----
data_raw <-
  tidyr::expand_grid(
    data_coord,
    vec_age
  ) %>%
  dplyr::mutate(
    dataset_type = "gridpoints",
    dataset_source_type = "gridpoints",
    data_source_type_reference = "artificially created by O. Mottl",
    data_source_desc = "gridpoints",
    data_source_reference = "artificially created by O. Mottl",
    dataset_reference = "artificially created by O. Mottl",
    coord_long = as.numeric(.data$long),
    coord_lat = as.numeric(.data$lat),
    age = as.numeric(.data$vec_age)
  ) %>%
  dplyr::select(-c("vec_age", "long", "lat")) %>%
  tidyr::nest(
    data_samples = c(
      "age"
    )
  ) %>%
  dplyr::mutate(
    dataset_name = paste(
      "geo",
      round(.data$coord_long, digits = 2),
      round(.data$coord_lat, digits = 2),
      sep = "_"
    )
  ) %>%
  tidyr::unnest("data_samples") %>%
  dplyr::mutate(
    sample_name = paste0(
      .data$dataset_name,
      "_",
      .data$age
    ),
    sample_size = NA_real_,
    description = "gridpoint",
    sample_reference = "artificially created by O. Mottl"
  )

# dataset type -----
data_dataset_type_db <-
  add_dataset_type(
    data_source = data_raw,
    con = con
  )

# dataset source type -----
data_dataset_source_type_db <-
  add_dataset_source_type(
    data_source = data_raw,
    con = con
  )

# dataset source -----
data_data_source_id_db <-
  add_data_source(
    data_source = data_raw,
    con = con
  )

# Add gridpoints -----
add_gridpoints_with_links(
  data_source = data_raw,
  sel_con = con,
  dataset_type_db = data_dataset_type_db,
  dataset_source_type_db = data_dataset_source_type_db,
  data_source_id_db = data_data_source_id_db,
  sel_grid_size_degree = 2,
  sel_distance_km = 50,
  sel_distance_years = 5e3
)
