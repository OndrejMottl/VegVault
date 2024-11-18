#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Import BIEN trait data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import trait data from BIEN

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

url_gh_veg_data <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-Vegetation_data/",
    "v1.0.0/"
  )

data_bien_traits <-
  c(
    "data_traits_bien_0_2023-12-26__778e51e059ae1955d893ff8d306ded42__.qs",
    "data_traits_bien_1_2023-12-26__11c73cf35307053de0fff8900915623f__.qs",
    "data_traits_bien_2_2023-12-26__ab13a3f2bcaa4caac48c301f2bb4a03e__.qs",
    "data_traits_bien_3_2023-12-26__e87885ac564d6f387d3a031575411da2__.qs"
  ) %>%
  purrr::map(
    .f = ~ paste0(
      url_gh_veg_data,
      "Outputs/Data/",
      .x
    ) %>%
      dowload_and_load()
  ) %>%
  dplyr::bind_rows()

dplyr::glimpse(data_bien_traits)


#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

bien_traits_dataset_raw <-
  data_bien_traits %>%
  dplyr::mutate(
    dataset_type = "traits",
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
    data_source_desc = project_pi,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    data_source_reference = source_citation,
    dataset_reference = NA_character_
  )

bien_traits_dataset_raw_distinct <-
  bien_traits_dataset_raw %>%
  dplyr::distinct(
    dataset_type,
    dataset_source_type, data_source_type_reference,
    data_source_desc,
    coord_long, coord_lat,
    data_source_reference,
    dataset_reference
  ) %>%
  dplyr::mutate(
    dataset_name = paste0(
      "bien_traits_",
      dplyr::row_number()
    )
  )

# - 3.1 dataset type -----
data_bien_traits_dataset_type_id_db <-
  add_dataset_type(
    data_source = bien_traits_dataset_raw_distinct,
    con = con
  )

# - 3.2 dataset source type -----
data_bien_traits_dataset_source_type_db <-
  add_dataset_source_type(
    data_source = bien_traits_dataset_raw_distinct,
    con = con
  )

# - 3.3 dataset source -----
data_bien_traits_data_source_id_db <-
  add_data_source(
    data_source = bien_traits_dataset_raw_distinct,
    con = con
  )

# 3.4 datasets -----
bien_traits_dataset_id <-
  add_datasets(
    data_source = bien_traits_dataset_raw_distinct,
    con = con,
    data_type = data_bien_traits_dataset_type_id_db,
    data_source_type = data_bien_traits_dataset_source_type_db,
    dataset_source = data_bien_traits_data_source_id_db
  )


#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

bien_traits_samples_raw_id <-
  bien_traits_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "bien_traits_",
      id
    )
  )

bien_traits_samples_raw <-
  bien_traits_samples_raw_id %>%
  dplyr::left_join(
    bien_traits_dataset_raw_distinct,
    by = dplyr::join_by(
      dataset_type, data_source_desc,
      coord_long, coord_lat,
      dataset_source_type,
      data_source_type_reference,
      data_source_reference
    )
  ) %>%
  dplyr::mutate(
    age = 0,
    sample_size = NA_real_,
    description = NA_character_,
    sample_reference = NA_character_
  )

# 4.1 samples -----
bien_traits_samples_id <-
  add_samples(
    data_source = bien_traits_samples_raw,
    con = con
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

add_dataset_sample(
  data_source = bien_traits_samples_raw,
  dataset_id = bien_traits_dataset_id,
  sample_id = bien_traits_samples_id,
  con = con
)


#----------------------------------------------------------#
# 6. taxa -----
#----------------------------------------------------------#

bien_traits_taxa_raw <-
  bien_traits_samples_raw %>%
  dplyr::rename(taxon_name = scrubbed_species_binomial) %>%
  dplyr::mutate(
    taxon_reference = "BIEN"
  )

bien_traits_taxa_id <-
  add_taxa(
    data_source = bien_traits_taxa_raw,
    con = con
  )


#----------------------------------------------------------#
# 7. Traits -----
#----------------------------------------------------------#

bien_traits_traits_raw <-
  bien_traits_taxa_raw %>%
  dplyr::mutate(
    trait_domain_name = dplyr::case_when(
      trait_name == "stem wood density" ~ "Stem specific density",
      trait_name == "leaf nitrogen content per leaf dry mass" ~ "Leaf nitrogen content per unit mass",
      trait_name == "seed mass" ~ "Diaspore mass",
      trait_name == "whole plant height" ~ "Plant heigh",
      trait_name == "leaf area" ~ "Leaf Area",
      trait_name == "leaf area per leaf dry mass" ~ "Leaf mass per area"
    ),
    # need to flip the leaf area per leaf dry mass
    trait_value = ifelse(trait_name == "leaf area per leaf dry mass",
      1 / trait_value,
      trait_value
    ),
    trait_name = ifelse(trait_name == "leaf area per leaf dry mass",
      "leaf mass per area",
      trait_name
    )
  ) %>%
  dplyr::rename(
    trait_full_name = trait_name
  ) %>%
  dplyr::mutate(
    trait_reference = "BIEN"
  )

# 7.1 Traits -----
bien_traits_traits_id <-
  add_traits(
    data_source = bien_traits_traits_raw,
    con = con
  )

# 7.3 Trait value -----

bien_traits_traits_raw %>%
  dplyr::select(
    dataset_name, sample_name,
    trait_name = trait_full_name,
    taxon_name,
    trait_value
  ) %>%
  tidyr::drop_na() %>%
  add_trait_value(
    data_source = .,
    con = con,
    dataset_id = bien_traits_dataset_id,
    samples_id = bien_traits_samples_id,
    traits_id = bien_traits_traits_id,
    taxa_id = bien_traits_taxa_id
  )


#----------------------------------------------------------#
# 8. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
