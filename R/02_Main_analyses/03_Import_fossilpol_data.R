#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#              Import fossil pollen data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import paleo-ecological vegetation data

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

url_gh <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-FOSSILPOL/",
    "main/"
  )

url_fossilpol <-
  paste0(
    url_gh,
    "Outputs/Data/",
    "data_assembly_light_2023-12-12__305b96031416d8b0c6b5762daacd41dd__.qs"
  )

download.file(
  url = url_fossilpol,
  destfile = paste0(
    tempdir(),
    "/",
    "data_fossilpol.qs"
  ),
  method = "curl"
)

data_fossilpol <-
  qs::qread(
    file = paste0(
      tempdir(),
      "/",
      "data_fossilpol.qs"
    )
  )

dplyr::glimpse(data_fossilpol)


#----------------------------------------------------------#
# 2. Datasets -----
#----------------------------------------------------------#

fossilpol_dataset_raw <-
  data_fossilpol %>%
  dplyr::mutate(
    dataset_name = paste0(
      "fossilpol_",
      dataset_id
    ),
    coord_long = long,
    coord_lat = lat,
    data_source_desc = source_of_data,
    dataset_type = "fossilpol",
    sampling_reference = doi,
    sampling_method_details = depositionalenvironment,
  ) %>%
  dplyr::select(-dataset_id)

# 2.1 dataset source

data_fossilpol_data_source_id <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(data_source_desc)

dplyr::copy_to(
  con,
  data_fossilpol_data_source_id,
  name = "DatasetSourcesID",
  append = TRUE
)

data_fossilpol_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect()

test_unique_row_in_table(data_fossilpol_data_source_id_db)

# 2.2 dataset type

data_fossilpol_dataset_type_id <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(dataset_type)

dplyr::copy_to(
  con,
  data_fossilpol_dataset_type_id,
  name = "DatasetTypeID",
  append = TRUE
)

data_fossilpol_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect()

test_unique_row_in_table(data_fossilpol_dataset_type_id_db)

# 2.3 datasets sampling

data_fossilpol_sampling_method <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(sampling_method_details) %>%
  tidyr::drop_na()

dplyr::copy_to(
  con,
  data_fossilpol_sampling_method,
  name = "SamplingMethodID",
  append = TRUE
)

data_fossilpol_sampling_method_db <-
  dplyr::tbl(con, "SamplingMethodID") %>%
  dplyr::collect()

test_unique_row_in_table(data_fossilpol_sampling_method_db)

# 2.4 dataset reference

data_fossilpol_reference <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(sampling_reference) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = sampling_reference
  )

dplyr::copy_to(
  con,
  data_fossilpol_reference,
  name = "References",
  append = TRUE
)

data_fossilpol_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect()

test_unique_row_in_table(data_fossilpol_reference)

# 2.3 datasets

fossilpol_dataset <-
  fossilpol_dataset_raw %>%
  dplyr::left_join(
    data_fossilpol_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_fossilpol_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::left_join(
    data_fossilpol_sampling_method_db,
    by = dplyr::join_by(sampling_method_details)
  ) %>%
  dplyr::left_join(
    data_fossilpol_reference_db,
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
  fossilpol_dataset,
  name = "Datasets",
  append = TRUE
)

fossilpol_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect()

test_unique_row_in_table(fossilpol_dataset_id)


#----------------------------------------------------------#
# 3. Samples -----
#----------------------------------------------------------#

fossilpol_samples_raw <-
  fossilpol_dataset_raw %>%
  dplyr::left_join(
    fossilpol_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::mutate(
    samples = purrr::map2(
      .progress = TRUE,
      .x = levels,
      .y = counts_harmonised,
      .f = ~ .x %>%
        dplyr::select(
          sample_id, age
        ) %>%
        dplyr::inner_join(
          .y,
          by = dplyr::join_by(sample_id)
        )
    )
  ) %>%
  dplyr::select(
    dataset_name, dataset_id, samples,
  ) %>%
  tidyr::unnest(samples) %>%
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      .fns = ~ tidyr::replace_na(.x, 0)
    )
  ) %>%
  dplyr::mutate(
    sample_name = paste0(
      "fossilpol_",
      dataset_id,
      "_",
      sample_id
    ),
    sample_size = NA_real_
  ) %>%
  dplyr::select(-c(dataset_id, sample_id))

# 3.2 samples

fossilpol_samples <-
  fossilpol_samples_raw %>%
  dplyr::select(
    sample_name, age
  )

dplyr::copy_to(
  con,
  fossilpol_samples,
  name = "Samples",
  append = TRUE
)

fossilpol_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect()

test_unique_row_in_table(fossilpol_samples_id)


#----------------------------------------------------------#
# 4. Dataset - Sample -----
#----------------------------------------------------------#

data_fossilpol_dataset_sample <-
  fossilpol_samples_raw %>%
  dplyr::select(dataset_name, sample_name) %>%
  dplyr::left_join(
    fossilpol_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    fossilpol_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_fossilpol_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)

#----------------------------------------------------------#
# 4. Taxa -----
#----------------------------------------------------------#

# 4.1 taxa id

data_fossilpol_taxa <-
  fossilpol_samples_raw %>%
  dplyr::select(-c(dataset_name, age)) %>%
  names() %>%
  unique() %>%
  sort() %>%
  tibble::enframe(
    name = NULL,
    value = "taxon_name"
  ) %>%
  dplyr::filter(
    taxon_name != "sample_id"
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

dplyr::copy_to(
  con,
  data_fossilpol_taxa,
  name = "Taxa",
  append = TRUE
)

data_fossilpol_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect()

test_unique_row_in_table(data_fossilpol_taxa_id)

# 4.3 Sample - taxa

data_fossilpol_sample_taxa <-
  fossilpol_samples_raw %>%
  dplyr::select(-dataset_name, -age) %>%
  dplyr::left_join(
    fossilpol_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(-sample_name) %>%
  tidyr::pivot_longer(
    cols = -sample_id,
    names_to = "taxon_name",
    values_to = "value"
  ) %>%
  dplyr::filter(
    value > 0
  ) %>%
  dplyr::left_join(
    data_fossilpol_taxa_id,
    by = dplyr::join_by(taxon_name)
  ) %>%
  dplyr::select(
    sample_id, taxon_id, value
  )

dplyr::copy_to(
  con,
  data_fossilpol_sample_taxa,
  name = "SampleTaxa",
  append = TRUE
)


#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
