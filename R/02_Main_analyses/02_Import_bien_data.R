#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                  Import Vegetation data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import neo-ecological vegetation data

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

url_gh <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/Outputs/Data/"
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

url_bien <-
  paste0(
    url_gh,
    "data_bien_2023-12-06__7893b8a80ceb1550103667f95b695e6b__.qs"
  )

data_bien <-
  dowload_and_load(url_bien)

dplyr::glimpse(data_bien)

#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

bien_dataset_raw <-
  data_bien %>%
  dplyr::mutate(
    dataset_name = paste0(
      "bien_",
      dplyr::row_number()
    ),
    coord_long = longitude,
    coord_lat = latitude,
    data_source_desc = datasource,
    dataset_type = "bien",
    sampling_reference = methodology_reference,
    sampling_method_details = methodology_description,
  )

# 3.1 dataset source -----

data_bien_data_source_id <-
  bien_dataset_raw %>%
  dplyr::distinct(data_source_desc) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(-data_source_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_bien_data_source_id,
  table_name = "DatasetSourcesID"
)

data_bien_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    data_bien_data_source_id,
    by = dplyr::join_by(data_source_desc)
  )

# 3.2 dataset type -----

data_bien_dataset_type_id <-
  bien_dataset_raw %>%
  dplyr::distinct(dataset_type) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::select(-dataset_type_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data = data_bien_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_bien_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# 3.3 datasets sampling -----

data_bien_sampling_method <-
  bien_dataset_raw %>%
  dplyr::distinct(sampling_protocol) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    sampling_method_details = sampling_protocol
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "SamplingMethodID") %>%
      dplyr::select(-sampling_method_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(sampling_method_details)
  )

add_to_db(
  conn = con,
  data = data_bien_sampling_method,
  table_name = "SamplingMethodID"
)

data_bien_sampling_method_db <-
  dplyr::tbl(con, "SamplingMethodID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    data_bien_sampling_method,
    by = dplyr::join_by(sampling_method_details)
  )

# 3.4 dataset reference -----

data_bien_reference <-
  bien_dataset_raw %>%
  dplyr::distinct(sampling_reference) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = sampling_reference
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::select(-reference_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(reference_detail)
  )

add_to_db(
  conn = con,
  data = data_bien_reference,
  table_name = "References"
)

data_bien_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_dataset_raw %>%
      dplyr::distinct(sampling_reference),
    by = dplyr::join_by(reference_detail == sampling_reference)
  )

# 3.5 datasets -----

bien_dataset <-
  bien_dataset_raw %>%
  dplyr::left_join(
    data_bien_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_bien_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::left_join(
    data_bien_sampling_method_db,
    by = dplyr::join_by(sampling_method_details)
  ) %>%
  dplyr::left_join(
    data_bien_reference_db,
    by = dplyr::join_by(sampling_reference == reference_detail)
  ) %>%
  dplyr::select(
    dataset_name, data_source_id, dataset_type_id,
    coord_long, coord_lat,
    sampling_method_id,
    dataset_reference = reference_id
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(-dataset_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

add_to_db(
  conn = con,
  data = bien_dataset,
  table_name = "Datasets"
)

bien_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_dataset_raw %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )


#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

bien_samples_raw <-
  bien_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "bien_",
      dplyr::row_number()
    ),
    age = 0,
    sample_size = plot_area_ha * 10000
  )

# 4.1 sample size -----

data_bien_sample_size <-
  bien_samples_raw %>%
  dplyr::distinct(sample_size) %>%
  tidyr::drop_na() %>%
  dplyr::mutate(
    description = "square meters"
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "SampleSizeID") %>%
      dplyr::select(-sample_size_id) %>%
      dplyr::collect(),
    by = join_by(sample_size, description)
  ) %>%
  dplyr::arrange(sample_size)

add_to_db(
  conn = con,
  data = data_bien_sample_size,
  table_name = "SampleSizeID"
)

data_bien_sample_size_id <-
  dplyr::tbl(con, "SampleSizeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_samples_raw %>%
      dplyr::distinct(sample_size),
    by = dplyr::join_by(sample_size)
  )

# 4.2 samples -----

bien_samples <-
  bien_samples_raw %>%
  dplyr::left_join(
    data_bien_sample_size_id,
    by = dplyr::join_by(sample_size)
  ) %>%
  dplyr::select(
    sample_name, age, sample_size_id
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::select(-sample_id) %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  )

add_to_db(
  conn = con,
  data = bien_samples,
  table_name = "Samples"
)

bien_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

data_bien_dataset_sample <-
  bien_samples_raw %>%
  dplyr::left_join(
    bien_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    bien_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_bien_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)

#----------------------------------------------------------#
# 6. Taxa -----
#----------------------------------------------------------#

# 4.1 taxa id -----

data_bien_taxa_raw <-
  bien_samples_raw %>%
  dplyr::select(plot_data) %>%
  dplyr::mutate(
    taxa_list = purrr::map(
      .x = plot_data,
      .f = ~ purrr::chuck(.x, "name_matched")
    )
  ) %>%
  purrr::chuck("taxa_list") %>%
  unlist() %>%
  unique() %>%
  sort() %>%
  tibble::enframe(
    name = NULL,
    value = "taxon_name"
  ) %>%
  dplyr::filter(
    taxon_name != ""
  ) %>%
  tidyr::drop_na()

data_bien_taxa <-
  data_bien_taxa_raw %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

add_to_db(
  conn = con,
  data = data_bien_taxa,
  table_name = "Taxa"
)

data_bien_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    data_bien_taxa_raw,
    by = dplyr::join_by(taxon_name)
  )


# 4.3 Sample - taxa -----

data_bien_sample_taxa <-
  bien_samples_raw %>%
  dplyr::left_join(
    bien_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    sample_id, plot_data
  ) %>%
  tidyr::unnest(plot_data) %>%
  dplyr::left_join(
    data_bien_taxa_id,
    by = dplyr::join_by(name_matched == taxon_name)
  ) %>%
  dplyr::rename(
    value = individual_count
  ) %>%
  dplyr::select(
    sample_id, taxon_id, value
  )

dplyr::copy_to(
  con,
  data_bien_sample_taxa,
  name = "SampleTaxa",
  append = TRUE
)

#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
