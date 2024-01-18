#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                Import palaeoclimatic data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import palaeoclimate data

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
    "main/"
  )

data_palaeoclimate_raw <-
  c(
    "bio01_batch_1_2024-01-02__05b0b43b6640a26c729b0403e711993f__.qs",
    "bio01_batch_2_2024-01-02__f728c578e64054e96e1671829a1971f2__.qs",
    "bio01_batch_3_2024-01-02__636dae96f45c34f2f63a579f7bba9ec6__.qs",
    "bio01_batch_4_2024-01-02__c432f3ecedeae729f35914f02a6f65dc__.qs",
    "bio01_batch_5_2024-01-02__3d4236481e4131ed665474d6dc7a9b41__.qs"
  ) %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_abiotic,
      "Outputs/Data/Palaoclimate/",
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows() %>%
  dplyr::mutate(
    var_name = "bio1"
  )

data_palaeoclimate_nested <-
  data_palaeoclimate_raw %>%
  tidyr::pivot_wider(
    names_from = var_name,
    values_from = value
  ) %>%
  tidyr::nest(
    data_climate = c(
      time_id, bio1
    )
  )

dplyr::glimpse(data_palaeoclimate_nested)


#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#
palaeoclimate_dataset_raw <-
  data_palaeoclimate_nested %>%
  dplyr::mutate(
    dataset_type = "abiotic",
    coord_long = as.numeric(long),
    coord_lat = as.numeric(lat),
    data_source_desc = "gridpoints",
    dataset_name = paste(
      "geo", round(coord_long, digits = 2), round(coord_lat, digits = 2),
      sep = "_"
    )
  )

palaeoclimate_dataset_raw_unique <-
  palaeoclimate_dataset_raw %>%
  dplyr::distinct(
    dataset_type, data_source_desc,
    coord_long, coord_lat,
    dataset_name
  )

# 3.1 dataset source -----

data_palaeoclimate_data_source_id <-
  palaeoclimate_dataset_raw_unique %>%
  dplyr::distinct(data_source_desc) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(data_source_desc) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_palaeoclimate_data_source_id,
  table_name = "DatasetSourcesID"
)

data_palaeoclimate_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    palaeoclimate_dataset_raw %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 3.2 dataset type -----

data_palaeoclimate_dataset_type_id <-
  palaeoclimate_dataset_raw %>%
  dplyr::distinct(dataset_type) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::select(-dataset_type_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data = data_palaeoclimate_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_palaeoclimate_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    palaeoclimate_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# 3.3 datasets -----
palaeoclimate_dataset <-
  palaeoclimate_dataset_raw_unique %>%
  dplyr::left_join(
    data_palaeoclimate_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_palaeoclimate_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::select(
    dataset_name, data_source_id, dataset_type_id,
    coord_long, coord_lat
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

add_to_db(
  conn = con,
  data = palaeoclimate_dataset,
  table_name = "Datasets"
)

palaeoclimate_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    palaeoclimate_dataset_raw_unique %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )


#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

palaeoclimate_samples_raw <-
  palaeoclimate_dataset_raw %>%
  tidyr::unnest(data_climate) %>%
  dplyr::mutate(
    sample_reference = "https://doi.org/10.5194/cp-2021-30",
    age = (-as.numeric(time_id) * 100) + 2000,
    sample_name = paste0(
      dataset_name, "_", age
    )
  )

# 4.1 samples references -----

palaeoclimate_samples_reference <-
  palaeoclimate_samples_raw %>%
  dplyr::distinct(sample_reference) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = sample_reference
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::select(reference_detail) %>%
      dplyr::collect(),
    by = dplyr::join_by(reference_detail)
  )

add_to_db(
  conn = con,
  data = palaeoclimate_samples_reference,
  table_name = "References"
)

palaeoclimate_samples_reference_id <-
  dplyr::tbl(con, "References") %>%
  dplyr::select(reference_id, reference_detail) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    palaeoclimate_samples_raw %>%
      dplyr::distinct(sample_reference),
    by = dplyr::join_by(reference_detail == sample_reference)
  )


# 4.1 samples -----

palaeoclimate_samples <-
  palaeoclimate_samples_raw %>%
  dplyr::distinct(sample_name, sample_reference) %>%
  dplyr::left_join(
    palaeoclimate_samples_reference_id,
    by = dplyr::join_by(sample_reference == reference_detail)
  ) %>%
  dplyr::select(-sample_reference) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::select(sample_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::rename(
    sample_referecne = reference_id
  )

add_to_db(
  conn = con,
  data = palaeoclimate_samples,
  table_name = "Samples"
)

palaeoclimate_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    palaeoclimate_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

data_palaeoclimate_dataset_sample <-
  palaeoclimate_samples_raw %>%
  dplyr::distinct(
    dataset_name, sample_name
  ) %>%
  dplyr::left_join(
    palaeoclimate_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    palaeoclimate_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_palaeoclimate_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)

#----------------------------------------------------------#
# 5. Climate -----
#----------------------------------------------------------#


#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
