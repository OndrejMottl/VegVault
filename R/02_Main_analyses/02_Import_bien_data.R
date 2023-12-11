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

download.file(
  url = url_bien,
  destfile = paste0(
    tempdir(),
    "/",
    "data_bien.qs"
  ),
  method = "curl"
)

data_bien <-
  qs::qread(
    file = paste0(
      tempdir(),
      "/",
      "data_bien.qs"
    )
  )

dplyr::glimpse(data_bien)

#----------------------------------------------------------#
# 2. Datasets -----
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

# 2.1 dataset source

data_bien_data_source_id <-
  bien_dataset_raw %>%
  dplyr::distinct(data_source_desc)

dplyr::copy_to(
  con,
  data_bien_data_source_id,
  name = "DatasetSourcesID",
  append = TRUE
)

data_bien_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_data_source_id_db)

# 2.2 dataset type

data_bien_dataset_type_id <-
  bien_dataset_raw %>%
  dplyr::distinct(dataset_type)

dplyr::copy_to(
  con,
  data_bien_dataset_type_id,
  name = "DatasetTypeID",
  append = TRUE
)

data_bien_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_dataset_type_id_db)

# 2.3 datasets sampling

data_bien_sampling_method <-
  bien_dataset_raw %>%
  dplyr::distinct(sampling_protocol) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    sampling_method_details = sampling_protocol
  )

dplyr::copy_to(
  con,
  data_bien_sampling_method,
  name = "SamplingMethodID",
  append = TRUE
)

data_bien_sampling_method_db <-
  dplyr::tbl(con, "SamplingMethodID") %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_sampling_method_db)

# 2.4 dataset reference

data_bien_reference <-
  bien_dataset_raw %>%
  dplyr::distinct(sampling_reference) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = sampling_reference
  )

dplyr::copy_to(
  con,
  data_bien_reference,
  name = "References",
  append = TRUE
)

data_bien_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_reference)

# 2.3 datasets

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
  )

dplyr::copy_to(
  con,
  bien_dataset,
  name = "Datasets",
  append = TRUE
)

bien_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect()

test_unique_row_in_table(bien_dataset_id)


#----------------------------------------------------------#
# 3. Samples -----
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

# 3.1 sample size

data_bien_sample_size <-
  bien_samples_raw %>%
  dplyr::distinct(sample_size) %>%
  dplyr::mutate(
    description = "square meters"
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "SampleSizeID") %>%
      dplyr::select(-sample_size_id) %>%
      dplyr::collect(),
    by = join_by(sample_size, description)
  )

dplyr::copy_to(
  con,
  data_bien_sample_size,
  name = "SampleSizeID",
  append = TRUE
)

data_bien_sample_size_id <-
  dplyr::tbl(con, "SampleSizeID") %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_sample_size_id)

# 3.2 samples

bien_samples <-
  bien_samples_raw %>%
  dplyr::left_join(
    data_bien_sample_size_id,
    by = dplyr::join_by(sample_size)
  ) %>%
  dplyr::select(
    sample_name, age, sample_size_id
  )

dplyr::copy_to(
  con,
  bien_samples,
  name = "Samples",
  append = TRUE
)

bien_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect()

test_unique_row_in_table(bien_samples_id)


#----------------------------------------------------------#
# 4. Dataset - Sample -----
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
# 4. Taxa -----
#----------------------------------------------------------#

# 4.1 taxa id

data_bien_taxa <-
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
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

dplyr::copy_to(
  con,
  data_bien_taxa,
  name = "Taxa",
  append = TRUE
)

data_bien_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect()

test_unique_row_in_table(data_bien_taxa_id)

# 4.3 Sample - taxa

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
