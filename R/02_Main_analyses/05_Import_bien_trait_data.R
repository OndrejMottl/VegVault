#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#              Import BIEN trait data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import trait data from BIEN

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

url_gh_veg_data <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/"
  )

data_bien_traits <-
  c(
    "data_traits_bien_0_2023-12-26__778e51e059ae1955d893ff8d306ded42__.qs",
    "data_traits_bien_1_2023-12-26__11c73cf35307053de0fff8900915623f__.qs",
    "data_traits_bien_2_2023-12-26__ab13a3f2bcaa4caac48c301f2bb4a03e__.qs",
    "data_traits_bien_3_2023-12-26__e87885ac564d6f387d3a031575411da2__.qs"
  ) %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_veg_data,
      "Outputs/Data/",
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows()

#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

dplyr::glimpse(data_bien_traits)

bien_traits_dataset_raw <-
  data_bien_traits %>%
  dplyr::mutate(
    dataset_type = "bien_traits",
    data_source_desc = project_pi,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    sampling_reference = source_citation
  )

bien_traits_dataset_raw_unique <-
  bien_traits_dataset_raw %>%
  dplyr::distinct(
    dataset_type, data_source_desc,
    coord_long, coord_lat,
    sampling_reference
  ) %>%
  dplyr::mutate(
    dataset_name = paste0(
      "bien_traits_",
      dplyr::row_number()
    )
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

# 3.1 dataset source -----

data_bien_traits_data_source_id <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(data_source_desc) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(data_source_desc) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_bien_traits_data_source_id,
  table_name = "DatasetSourcesID"
)

data_bien_traits_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 3.2 dataset type -----

data_bien_traits_dataset_type_id <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(dataset_type) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::select(dataset_type) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data = data_bien_traits_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_bien_traits_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# 3.3 dataset reference -----

data_bien_traits_reference <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(sampling_reference) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = sampling_reference
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::select(reference_detail) %>%
      dplyr::collect(),
    by = dplyr::join_by(reference_detail)
  )

add_to_db(
  conn = con,
  data = data_bien_traits_reference,
  table_name = "References"
)

data_bien_traits_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(sampling_reference),
    by = dplyr::join_by(reference_detail == sampling_reference)
  )

# 3.4 datasets -----

bien_traits_dataset <-
  bien_traits_dataset_raw_unique %>%
  dplyr::left_join(
    data_bien_traits_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_bien_traits_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::left_join(
    data_bien_traits_reference_db,
    by = dplyr::join_by(sampling_reference == reference_detail)
  ) %>%
  dplyr::select(
    dataset_name, data_source_id, dataset_type_id,
    coord_long, coord_lat,
    dataset_reference = reference_id
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

add_to_db(
  conn = con,
  data = bien_traits_dataset,
  table_name = "Datasets"
)

bien_traits_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )
