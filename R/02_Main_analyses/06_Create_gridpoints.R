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
    path_to_vegvault
  )


#----------------------------------------------------------#
# 2. Load data -----
#----------------------------------------------------------#

# Use paleoclimate data as template for creating the gridpoints

url_gh_abiotic <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-abiotic_data/"
  )

paleo_bio1_hash <-
  c(
    "bio01_batch_1_2024-08-06__f674adeb38401a05236e0b5e0ad7cc53__.qs",
    "bio01_batch_2_2024-08-06__b32dfb2e39d295750dc67f1dc145c176__.qs",
    "bio01_batch_3_2024-08-06__e6997e401e83f216ecf697e2ce3aefe0__.qs"
  )

data_paleo_climate <-
  paleo_bio1_hash %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_abiotic,
      "v1.1.0/",
      "Outputs/Data/Palaoclimate/",
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows() %>%
  dplyr::select(-"value")

vec_age <-
  data_paleo_climate %>%
  dplyr::distinct(.data$time_id) %>%
  tidyr::drop_na("time_id") %>%
  dplyr::mutate(
    age = (-as.numeric(.data$time_id) * 100) + 2000
  ) %>%
  dplyr::arrange(.data$age) %>%
  purrr::chuck("age")

data_paleo_coord <-
  data_paleo_climate %>%
  dplyr::select(-"time_id") %>%
  round(digits = 2) %>%
  dplyr::distinct(.data$long, .data$lat) %>%
  tidyr::drop_na()

data_neo_coords <-
  paste0(
    url_gh_abiotic,
    "v1.1.0/",
    "Outputs/Data/Neoclimate/",
    "CHELSA_bio_01_2024-08-06__ff1659d322855ca35555ac7b96d58720__.qs"
  ) %>%
  dowload_and_load() %>%
  dplyr::select(-c("value", "var_name")) %>%
  round(digits = 2) %>%
  dplyr::distinct(.data$long, .data$lat) %>%
  tidyr::drop_na()

data_soil_coords <-
  paste0(
    url_gh_abiotic,
    "v1.1.0/",
    "Outputs/Data/WoSIS/",
    "wosis_data_2024-08-06__e8fb256f5b70deb9576ea69806c59eb1__.qs"
  ) %>%
  dowload_and_load() %>%
  dplyr::select(-c("value", "var_name")) %>%
  round(digits = 2) %>%
  dplyr::distinct(.data$long, .data$lat) %>%
  tidyr::drop_na()

data_coord <-
  data_paleo_coord %>%
  dplyr::bind_rows(data_neo_coords) %>%
  # dplyr::bind_rows(data_soil_coords) %>%
  dplyr::distinct(.data$long, .data$lat) %>%
  tidyr::drop_na()

# Datasets -----
data_raw <-
  tidyr::expand_grid(
    data_coord,
    vec_age
  ) %>%
  dplyr::mutate(
    dataset_type = "gridpoints",
    dataset_source_type = "gridpoints",
    data_source_type_reference = "gridpoints - artificially created by O. Mottl",
    data_source_desc = "gridpoints",
    data_source_reference = "gridpoints - artificially created by O. Mottl",
    dataset_reference = "gridpoints - artificially created by O. Mottl",
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
    sample_reference = "gridpoints - artificially created by O. Mottl"
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
