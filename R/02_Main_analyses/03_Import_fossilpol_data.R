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

url_gh_fossilpol <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-FOSSILPOL/",
    "main/"
  )

url_fossilpol_data <-
  paste0(
    url_gh_fossilpol,
    "Outputs/Data/",
    "data_assembly_light_2023-12-12__305b96031416d8b0c6b5762daacd41dd__.qs"
  )

data_fossilpol <-
  dowload_and_load(url_fossilpol_data)

dplyr::glimpse(data_fossilpol)


#----------------------------------------------------------#
# 3. Datasets -----
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

# 3.1 dataset source -----

data_fossilpol_data_source_id <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(data_source_desc) %>%
  tidyr::drop_na() %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(data_source_desc) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_fossilpol_data_source_id,
  table_name = "DatasetSourcesID"
)

data_fossilpol_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_dataset_raw %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 3.2 dataset type -----

data_fossilpol_dataset_type_id <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(dataset_type) %>%
  tidyr::drop_na() %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::select(dataset_type) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data = data_fossilpol_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_fossilpol_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )


# 3.3 datasets sampling ------

data_fossilpol_sampling_method <-
  fossilpol_dataset_raw %>%
  dplyr::distinct(sampling_method_details) %>%
  tidyr::drop_na() %>%
  dplyr::anti_join(
    dplyr::tbl(con, "SamplingMethodID") %>%
      dplyr::select(sampling_method_details) %>%
      dplyr::collect(),
    by = dplyr::join_by(sampling_method_details)
  )

add_to_db(
  conn = con,
  data = data_fossilpol_sampling_method,
  table_name = "SamplingMethodID"
)

data_fossilpol_sampling_method_db <-
  dplyr::tbl(con, "SamplingMethodID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_dataset_raw %>%
      dplyr::distinct(sampling_method_details),
    by = dplyr::join_by(sampling_method_details)
  )

# 3.4 dataset reference -----

data_fossilpol_reference <-
  fossilpol_dataset_raw %>%
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
  data = data_fossilpol_reference,
  table_name = "References"
)

data_fossilpol_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_dataset_raw %>%
      dplyr::distinct(sampling_reference),
    by = dplyr::join_by(reference_detail == sampling_reference)
  )

# 3.5 datasets -----

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
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

add_to_db(
  conn = con,
  data = fossilpol_dataset,
  table_name = "Datasets"
)

fossilpol_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_dataset_raw %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )


#----------------------------------------------------------#
# 4. Samples -----
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

fossilpol_samples <-
  fossilpol_samples_raw %>%
  dplyr::select(
    sample_name, age
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::select(sample_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  )

add_to_db(
  conn = con,
  data = fossilpol_samples,
  table_name = "Samples"
)

fossilpol_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    fossilpol_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
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
# 6. Sample Uncertainty -----
#----------------------------------------------------------#

data_uncertainty_raw <-
  c(
    "data_age_uncertainty_A_2023-12-12__3aa5658488292372af2b521ca6e48c14__.qs",
    "data_age_uncertainty_B_2023-12-12__7781fda623c5da21cd6d4766e550985d__.qs"
  ) %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_fossilpol,
      "Outputs/Data/",
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows()

data_uncertainty <-
  data_uncertainty_raw %>%
  dplyr::mutate(
    dataset_name = paste0(
      "fossilpol_",
      dataset_id
    )
  ) %>%
  dplyr::select(-dataset_id) %>%
  dplyr::left_join(
    fossilpol_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::mutate(
    age_uncertainty_nested = purrr::map(
      .progress = TRUE,
      .x = age_uncertainty,
      .f = ~ as.data.frame(.x) %>%
        tibble::rowid_to_column("iteration") %>%
        tidyr::pivot_longer(
          cols = -iteration,
          names_to = "sample_id",
          values_to = "age"
        )
    )
  ) %>%
  dplyr::select(-age_uncertainty) %>%
  tidyr::unnest(age_uncertainty_nested) %>%
  dplyr::mutate(
    sample_name = paste0(
      "fossilpol_",
      dataset_id,
      "_",
      sample_id
    )
  ) %>%
  dplyr::select(sample_name, iteration, age) %>%
  dplyr::left_join(
    fossilpol_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(-sample_name)

dplyr::copy_to(
  con,
  data_uncertainty,
  name = "SampleUncertainty",
  append = TRUE
)


#----------------------------------------------------------#
# 7. Taxa -----
#----------------------------------------------------------#

# 7.1 taxa id -----

data_fossilpol_taxa_raw <-
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
  tidyr::drop_na()

data_fossilpol_taxa <-
  data_fossilpol_taxa_raw %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

add_to_db(
  conn = con,
  data = data_fossilpol_taxa,
  table_name = "Taxa"
)

data_fossilpol_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    data_fossilpol_taxa_raw,
    by = dplyr::join_by(taxon_name)
  )


# 7.2 Sample - taxa -----

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
