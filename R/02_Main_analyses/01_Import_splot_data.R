#----------------------------------------------------------#
#
#
#                       VegVault
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
    "OndrejMottl/VegVault-Vegetation_data/",
    "v1.0.0/Outputs/Data/"
  )

url_splot <-
  paste0(
    url_gh,
    "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs"
  )

data_splot <-
  dowload_and_load(url_splot)

dplyr::glimpse(data_splot)


#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

splot_dataset_raw <-
  data_splot %>%
  dplyr::mutate(
    dataset_type = "vegetation_plot",
    dataset_source_type = "sPlotOpen",
    data_source_type_reference = "https://doi.org/10.1111/geb.13346",
    data_source_desc = givd_id,
    data_source_reference = NA_character_,
    dataset_name = paste0(
      "splot_",
      plot_observation_id
    ),
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    dataset_reference = NA_character_
  )

# - 3.1 dataset type -----
data_splot_dataset_type_db <-
  add_dataset_type(
    data_source = splot_dataset_raw,
    con = con
  )

# - 3.2 dataset source type -----
data_splot_dataset_source_type_db <-
  add_dataset_source_type(
    data_source = splot_dataset_raw,
    con = con
  )

# - 3.3 dataset source -----
data_splot_data_source_id_db <-
  add_data_source(
    data_source = splot_dataset_raw,
    con = con
  )

# - 3.4 datasets -----
splot_dataset_id_db <-
  add_datasets(
    data_source = splot_dataset_raw,
    con = con,
    data_type = data_splot_dataset_type_db,
    data_source_type = data_splot_dataset_source_type_db,
    dataset_source = data_splot_data_source_id_db
  )

#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

splot_samples_raw <-
  splot_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "splot_",
      plot_observation_id
    ),
    age = 0,
    sample_size = releve_area,
    description = "square meters",
    sample_reference = NA_character_
  )

# - 4.2 samples -----
splot_samples_id_db <-
  add_samples(
    data_source = splot_samples_raw,
    con = con
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

add_dataset_sample(
  data_source = splot_samples_raw,
  con = con,
  dataset_id = splot_dataset_id_db,
  sample_id = splot_samples_id_db
)


#----------------------------------------------------------#
# 6. Taxa -----
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
  ) %>%
  dplyr::mutate(
    taxon_reference = NA_character_
  )

# - 6.1 taxa id -----
data_splot_taxa_id_db <-
  add_taxa(
    data_source = data_splot_taxa_raw,
    con = con
  )

# - 6.2 Sample - taxa -----
data_splot_sample_taxa_raw <-
  splot_samples_raw %>%
  dplyr::select(sample_name, taxa) %>%
  tidyr::unnest(taxa) %>%
  dplyr::rename(
    taxon_name = Species,
    value = Original_abundance
  ) %>%
  dplyr::select(sample_name, taxon_name, value)

add_sample_taxa(
  data_source = data_splot_sample_taxa_raw,
  con = con,
  samples_id = splot_samples_id_db,
  taxa_id = data_splot_taxa_id_db
)


#----------------------------------------------------------#
# 7. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
