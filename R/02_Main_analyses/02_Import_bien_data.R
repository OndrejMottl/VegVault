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
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/Outputs/Data/"
  )

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
    dataset_type = "vegetation_plot",
    dataset_source_type = "BIEN",
    data_source_type_reference = "https://doi.org/10.7287/peerj.preprints.2615v2",
    data_source_desc = datasource,
    dataset_name = paste0(
      "bien_",
      dplyr::row_number()
    ),
    coord_long = longitude,
    coord_lat = latitude,
    sampling_reference = methodology_reference,
    sampling_method_details = methodology_description,
  )

# - 3.1 dataset type -----
data_bien_dataset_type_db <-
  add_dataset_type(
    data_source = bien_dataset_raw,
    con = con
  )

# - 3.2 dataset source type -----
data_bien_dataset_source_type_db <-
  add_dataset_source_type_with_reference(
    data_source = bien_dataset_raw,
    con = con
  )

# - 3.3 dataset source -----
data_bien_data_source_id_db <-
  add_data_source(
    data_source = bien_dataset_raw,
    con = con
  )

# - 3.4 datasets sampling -----
data_bien_sampling_method_db <-
  add_sampling_method_with_reference(
    data_source = bien_dataset_raw,
    con = con
  )

# - 3.5 datasets -----
bien_dataset_id_db <-
  add_datasets(
    data_source = bien_dataset_raw,
    con = con,
    data_type = data_bien_dataset_type_db,
    data_source_type = data_bien_dataset_source_type_db,
    dataset_source = data_bien_data_source_id_db,
    sampling_method = data_bien_sampling_method_db
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
    sample_size = plot_area_ha * 10000,
    description = "square meters"
  )

bien_samples_id_db <-
  add_samples_with_size(
    data_source = bien_samples_raw,
    con = con
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

add_dataset_sample(
  data_source = bien_samples_raw,
  con = con,
  dataset_id = bien_dataset_id_db,
  sample_id = bien_samples_id_db
)


#----------------------------------------------------------#
# 6. Taxa -----
#----------------------------------------------------------#

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

# 6.1 taxa id -----
data_bien_taxa_id_db <-
  add_taxa(
    data_source = data_bien_taxa_raw,
    con = con
  )

# 6.2 Sample - taxa -----

data_bien_sample_taxa_raw <-
  bien_samples_raw %>%
  dplyr::select(sample_name, plot_data) %>%
  tidyr::unnest(plot_data) %>%
  dplyr::rename(
    taxon_name = name_matched,
    value = individual_count
  ) %>%
  dplyr::select(sample_name, taxon_name, value)

add_sample_taxa(
  data_source = data_bien_sample_taxa_raw,
  con = con,
  samples_id = bien_samples_id_db,
  taxa_id = data_bien_taxa_id_db
)


#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
