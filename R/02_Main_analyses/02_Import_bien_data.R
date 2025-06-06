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
    path_to_vegvault
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
    data_source_type_reference = list(
      c(
        paste(
          "Enquist, B J, B Sandel, B Boyle, J-C Svenning, B J McGill,",
          "J C Donoghue, C E Hinchliff, et al. ‘Botanical Big Data Shows That",
          "Plant Diversity in the New World Is Driven by Climatic-Linked",
          "Differences in Evolutionary Rates and Biotic Exclusion’, n.d."
        ),
        paste(
          "S, Maitner Brian, Boyle Brad, Casler Nathan, Condit Rick,",
          "Donoghue John, Duran Sandra M, Guaderrama Daniel, et al.",
          "‘The Bien r Package: A Tool to Access the Botanical Information and",
          "Ecology Network (BIEN) Database’. Methods in Ecology and",
          "Evolution 9, no. 2 (n.d.): 373–79.",
          "https://doi.org/10.1111/2041-210X.12861."
        )
      )
    ),
    data_source_desc = datasource,
    data_source_reference = NA_character_,
    dataset_name = paste0(
      "bien_",
      dplyr::row_number()
    ),
    coord_long = longitude,
    coord_lat = latitude,
    sampling_reference = purrr::map(
      .x = methodology_reference,
      .f = ~ c(
        "BIEN",
        .x
      )
    ),
    sampling_method_details = methodology_description,
    dataset_reference = NA_character_
  )

# - 3.1 dataset type -----
data_bien_dataset_type_db <-
  add_dataset_type(
    data_source = bien_dataset_raw,
    con = con
  )

# - 3.2 dataset source type -----
data_bien_dataset_source_type_db <-
  add_dataset_source_type(
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
  add_sampling_method(
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
    description = "square meters",
    sample_reference = NA_character_
  )

bien_samples_id_db <-
  add_samples(
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
  tidyr::drop_na() %>%
  dplyr::mutate(
    taxon_reference = "BIEN",
  )

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
