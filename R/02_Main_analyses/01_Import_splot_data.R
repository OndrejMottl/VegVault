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

url_splot <-
  paste0(
    url_gh,
    "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs"
  )

data_splot <-
  dowload_and_load(url_splot)

dplyr::glimpse(data_splot)


#----------------------------------------------------------#
# 2. Datasets -----
#----------------------------------------------------------#

splot_dataset_raw <-
  data_splot %>%
  dplyr::mutate(
    dataset_name = paste0(
      "splot_",
      plot_observation_id
    ),
    coord_long = longitude,
    coord_lat = latitude,
    data_source_desc = givd_id,
    dataset_type = "splot",
    sampling_method_details = givd_id
  )

# 2.1 dataset source

data_splot_data_source_id <-
  splot_dataset_raw %>%
  dplyr::distinct(data_source_desc) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data_splot_data_source_id,
  table_name = "DatasetSourcesID"
)

data_splot_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    splot_dataset_raw %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 2.2 dataset type

data_splot_dataset_type_id <-
  splot_dataset_raw %>%
  dplyr::distinct(dataset_type) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data_splot_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_splot_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    splot_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# 2.3 datasets

splot_dataset <-
  splot_dataset_raw %>%
  dplyr::left_join(
    data_splot_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_splot_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::select(
    dataset_name, data_source_id, dataset_type_id,
    coord_long, coord_lat
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

add_to_db(
  conn = con,
  splot_dataset,
  table_name = "Datasets"
)

splot_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    splot_dataset_raw %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )


#----------------------------------------------------------#
# 3. Samples -----
#----------------------------------------------------------#

splot_samples_raw <-
  splot_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "splot_",
      plot_observation_id
    ),
    age = 0,
    sample_size = releve_area
  )

# 3.1 sample size

data_splot_sample_size <-
  splot_samples_raw %>%
  dplyr::distinct(sample_size) %>%
  dplyr::mutate(
    description = "square meters"
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "SampleSizeID") %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_size)
  ) %>%
  dplyr::arrange(sample_size)

add_to_db(
  conn = con,
  data_splot_sample_size,
  table_name = "SampleSizeID"
)

data_splot_sample_size_id <-
  dplyr::tbl(con, "SampleSizeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    splot_samples_raw %>%
      dplyr::distinct(sample_size),
    by = dplyr::join_by(sample_size)
  )

# 3.2 samples

splot_samples <-
  splot_samples_raw %>%
  dplyr::left_join(
    data_splot_sample_size_id,
    by = dplyr::join_by(sample_size)
  ) %>%
  dplyr::select(
    sample_name, age, sample_size_id
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  )

add_to_db(
  conn = con,
  splot_samples,
  table_name = "Samples"
)

splot_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    splot_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )


#----------------------------------------------------------#
# 4. Dataset - Sample -----
#----------------------------------------------------------#

data_splot_dataset_sample <-
  splot_samples_raw %>%
  dplyr::left_join(
    splot_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    splot_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_splot_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)


#----------------------------------------------------------#
# 4. Taxa -----
#----------------------------------------------------------#

data_splot_taxa_raw <-
  splot_samples_raw %>%
  dplyr::select(taxa) %>%
  dplyr::mutate(
    taxa_list = purrr::map(
      .x = taxa,
      .f = ~ purrr::chuck(.x, 1)
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
  )

# 4.1 taxa id

data_splot_taxa <-
  data_splot_taxa_raw %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

add_to_db(
  conn = con,
  data_splot_taxa,
  table_name = "Taxa"
)

data_splot_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect()  %>% 
  dplyr::inner_join(
    data_splot_taxa_raw %>%
      dplyr::distinct(taxon_name),
    by = dplyr::join_by(taxon_name)
  )

# 4.3 Sample - taxa

data_splot_sample_taxa <-
  splot_samples_raw %>%
  dplyr::left_join(
    splot_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    sample_id, taxa
  ) %>%
  tidyr::unnest(taxa) %>%
  dplyr::left_join(
    data_splot_taxa_id,
    by = dplyr::join_by(Species == taxon_name)
  ) %>%
  dplyr::rename(
    value = Original_abundance
  ) %>%
  dplyr::select(
    sample_id, taxon_id, value
  )

dplyr::copy_to(
  con,
  data_splot_sample_taxa,
  name = "SampleTaxa",
  append = TRUE
)


#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
