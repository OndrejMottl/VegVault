#----------------------------------------------------------#
#
#
#                       VegVault
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
    path_to_vegvault
  )

DBI::dbListTables(con)


#----------------------------------------------------------#
# 2. Load data -----
#----------------------------------------------------------#

url_gh_fossilpol <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-FOSSILPOL/",
    "v1.0.0/"
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

dplyr::glimpse(data_uncertainty_raw)


#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

fossilpol_dataset_raw <-
  data_fossilpol %>%
  dplyr::mutate(
    dataset_type = "fossil_pollen_archive",
    dataset_source_type = "FOSSILPOL",
    data_source_type_reference = "https://doi.org/10.1111/geb.13693",
    data_source_desc = source_of_data,
    data_source_reference = paste(
      "Grimm, E.C., 2008. Neotoma: an ecosystem database for the Pliocene,",
      "Pleistocene, and Holocene. Illinois State Museum",
      "Scientific Papers E Series, 1."
    ),
    dataset_name = paste0(
      "fossilpol_",
      dataset_id
    ),
    dataset_reference = doi,
    coord_long = long,
    coord_lat = lat,
    sampling_method_details = depositionalenvironment,
    sampling_reference = NA_character_
  ) %>%
  dplyr::select(-dataset_id)

# - 3.1 dataset type -----
data_fossilpol_dataset_type_id_db <-
  add_dataset_type(
    data_source = fossilpol_dataset_raw,
    con = con
  )

# - 3.2 dataset source type -----
data_fossilpol_dataset_source_type_db <-
  add_dataset_source_type(
    data_source = fossilpol_dataset_raw,
    con = con
  )

# - 3.3 dataset source -----
data_fossilpol_data_source_id_db <-
  add_data_source(
    data_source = fossilpol_dataset_raw,
    con = con
  )

# - 3.5 datasets sampling ------
data_fossilpol_sampling_method_db <-
  add_sampling_method(
    data_source = fossilpol_dataset_raw,
    con = con
  )

# - 3.7 datasets -----
fossilpol_dataset_id <-
  add_datasets(
    data_source = fossilpol_dataset_raw,
    con = con,
    data_type = data_fossilpol_dataset_type_id_db,
    data_source_type = data_fossilpol_dataset_source_type_db,
    dataset_source = data_fossilpol_data_source_id_db,
    sampling_method = data_fossilpol_sampling_method_db
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
    sample_size = NA_real_,
    description = NA_character_,
    sample_reference = NA_character_
  ) %>%
  dplyr::select(-c(dataset_id, sample_id))

fossilpol_samples_id <-
  add_samples(
    data_source = fossilpol_samples_raw,
    con = con
  )



#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

data_fossilpol_dataset_sample <-
  fossilpol_samples_raw %>%
  dplyr::select(dataset_name, sample_name)

add_dataset_sample(
  data_source = data_fossilpol_dataset_sample,
  dataset_id = fossilpol_dataset_id,
  sample_id = fossilpol_samples_id,
  con = con
)


#----------------------------------------------------------#
# 6. Sample Uncertainty -----
#----------------------------------------------------------#

data_fossilpol_uncertainty_raw <-
  data_uncertainty_raw %>%
  dplyr::mutate(
    dataset_name = paste0(
      "fossilpol_",
      dataset_id
    )
  ) %>%
  dplyr::select(-dataset_id) %>%
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
  tidyr::unnest(age_uncertainty_nested)

add_sample_age_uncertainty(
  data_source = data_fossilpol_uncertainty_raw,
  dataset_id = fossilpol_dataset_id,
  samples_id = fossilpol_samples_id,
  con = con,
  sel_name = "fossilpol_"
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
  tidyr::drop_na()  %>% 
  dplyr::mutate(
    taxon_reference = NA_character_
  )

data_fossilpol_taxa_id <-
  add_taxa(
    data_source = data_fossilpol_taxa_raw,
    con = con
  )

# 7.2 Sample - taxa -----
data_fossilpol_sample_taxa_raw <-
  fossilpol_samples_raw %>%
  dplyr::select(
    -c(dataset_name, age, description, sample_reference)
  ) %>%
  tidyr::pivot_longer(
    cols = -sample_name,
    names_to = "taxon_name",
    values_to = "value"
  ) %>%
  dplyr::filter(
    value > 0
  ) %>%
  dplyr::select(
    sample_name, taxon_name, value
  )

add_sample_taxa(
  data_source = data_fossilpol_sample_taxa_raw,
  taxa_id = data_fossilpol_taxa_id,
  samples_id = fossilpol_samples_id,
  con = con
)


#----------------------------------------------------------#
# 5. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
