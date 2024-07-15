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

# limit gridpoints
sel_grid_size_degree <- 2
sel_distance_km <- 50
sel_distance_years <- 5e3


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

# 3.1 Datasets -----

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

# 3.2 Samples -----

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

data_bd_vegetation <-
  vaultkeepr::open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  vaultkeepr::get_datasets() %>%
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits")
  ) %>%
  vaultkeepr::select_dataset_by_geo(
    sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits"),
    long_lim = c(-180, 180),
    lat_lim = c(-90, 90)
  ) %>%
  vaultkeepr::get_samples() %>%
  vaultkeepr::select_samples_by_age(
    sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits"),
    # just very large number to get rid of NAs
    age_lim = c(-1e10, 1e10)
  ) %>%
  vaultkeepr::extract_data() %>%
  dplyr::distinct(dataset_id, sample_name, coord_long, coord_lat, age)


data_wosis_samples_to_limit <-
  data_wosis_samples_raw %>%
  dplyr::distinct(dataset_id, sample_name, coord_long, coord_lat, age)

data_sample_link <-
  data_bd_vegetation %>%
  dplyr::mutate(
    batch = 1 + (dplyr::row_number() - 1) %/% 5000
  ) %>%
  dplyr::group_by(batch) %>%
  tidyr::nest(data = -batch) %>%
  dplyr::ungroup() %>%
  purrr::chuck("data") %>%
  rlang::set_names(paste0("batch_", 1:length(.))) %>%
  purrr::imap(
    .progress = "filtering gripoints samples",
    .f = ~ {
      message(.y)
      get_gridpoints_link(
        data_source = .x,
        data_source_gridpoints = data_wosis_samples_to_limit,
        sel_grid_size_degree = sel_grid_size_degree,
        sel_distance_km = sel_distance_km,
        sel_distance_years = sel_distance_years
      ) %>%
        return()
    }
  ) %>%
  dplyr::bind_rows()

vec_sample_name_to_keep <-
  data_sample_link %>%
  dplyr::distinct(sample_name_gridpoints) %>%
  dplyr::arrange(sample_name_gridpoints) %>%
  dplyr::pull(sample_name_gridpoints)

data_wosis_samples_filter <-
  data_wosis_samples_raw %>%
  dplyr::filter(sample_name %in% vec_sample_name_to_keep)

wosis_samples_id_db <-
  add_samples(
    data_source = data_wosis_samples_filter,
    con = con
  )

# Dataset - Sample -----
add_dataset_sample(
  data_source = data_wosis_samples_filter,
  con = con,
  dataset_id = wosis_dataset_id_db,
  sample_id = wosis_samples_id_db
)

# Abiotic sample reference
add_abiotic_data_ref(
  data_source = data_sample_link,
  con = con
)

# Abiotic varibale
abiotic_variabe_id <-
  add_abiotic_variable(
    data_source = data_wosis_samples_filter,
    con = con
  )

add_sample_abiotic_value(
  data_source = data_wosis_samples_filter,
  con = con,
  sample_id = wosis_samples_id_db,
  abiotic_variable_id = abiotic_variabe_id
)

#----------------------------------------------------------#
# 4. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
