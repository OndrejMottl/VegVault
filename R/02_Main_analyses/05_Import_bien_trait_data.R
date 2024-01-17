#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
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
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )

DBI::dbListTables(con)


#----------------------------------------------------------#
# 2. Load data -----
#----------------------------------------------------------#

url_gh_veg_data <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/"
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
    data_source_type_reference = "https://doi.org/10.7287/peerj.preprints.2615v2",
    data_source_desc = project_pi,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    data_source_reference = source_citation
  )

bien_traits_dataset_raw_unique <-
  bien_traits_dataset_raw %>%
  dplyr::distinct(
    dataset_type,
    dataset_source_type, data_source_type_reference,
    data_source_desc,
    coord_long, coord_lat,
    data_source_reference
  ) %>%
  dplyr::mutate(
    dataset_name = paste0(
      "bien_traits_",
      dplyr::row_number()
    )
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

# - 3.1 dataset type -----

data_bien_traits_dataset_type_id <-
  bien_traits_dataset_raw_unique %>%
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
  data = data_bien_traits_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_bien_traits_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# - 3.2 dataset source type -----
data_bien_traits_dataset_source_type_referecne <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(data_source_type_reference) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_type_reference == reference_detail)
  ) %>%
  dplyr::rename(reference_detail = data_source_type_reference)

add_to_db(
  conn = con,
  data = data_bien_traits_dataset_source_type_referecne,
  table_name = "References"
)

data_bien_traits_dataset_source_type_referecne_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(data_source_type_reference),
    by = dplyr::join_by(reference_detail == data_source_type_reference)
  )

data_bien_traits_dataset_source_type <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(dataset_source_type, data_source_type_reference) %>%
  dplyr::inner_join(
    data_bien_traits_dataset_source_type_referecne_db,
    by = dplyr::join_by(data_source_type_reference == reference_detail)
  ) %>%
  dplyr::select(
    dataset_source_type,
    reference_id
  ) %>%
  dplyr::rename(data_source_type_reference = reference_id)

data_bien_traits_dataset_source_type_unique <-
  data_bien_traits_dataset_source_type %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourceTypeID") %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_source_type, data_source_type_reference)
  )

add_to_db(
  conn = con,
  data = data_bien_traits_dataset_source_type_unique,
  table_name = "DatasetSourceTypeID"
)

data_bien_traits_dataset_source_type_db <-
  dplyr::tbl(con, "DatasetSourceTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(dataset_source_type),
    by = dplyr::join_by(dataset_source_type)
  )


# - 3.3 dataset source -----

data_bien_traits_data_source_reference <-
  bien_traits_dataset_raw_unique %>%
  dplyr::distinct(data_source_reference) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_reference == reference_detail)
  ) %>%
  dplyr::rename(reference_detail = data_source_reference)

add_to_db(
  conn = con,
  data = data_bien_traits_data_source_reference,
  table_name = "References"
)

data_bien_traits_data_source_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(data_source_reference),
    by = dplyr::join_by(reference_detail == data_source_reference)
  )

data_bien_traits_data_source_id <-
  bien_traits_dataset_raw_unique %>%
  dplyr::select(data_source_desc, data_source_reference) %>%
  dplyr::distinct(data_source_desc, .keep_all = TRUE) %>%
  tidyr::drop_na(data_source_desc) %>%
  dplyr::left_join(
    data_bien_traits_data_source_reference_db,
    by = dplyr::join_by(data_source_reference == reference_detail)
  ) %>%
  dplyr::select(
    data_source_desc, reference_id
  ) %>%
  dplyr::rename(data_source_reference = reference_id)

data_bien_traits_data_source_id_unique <-
  data_bien_traits_data_source_id %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(data_source_desc) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_bien_traits_data_source_id_unique,
  table_name = "DatasetSourcesID"
)

data_bien_traits_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 3.4 datasets -----

bien_traits_dataset <-
  bien_traits_dataset_raw_unique %>%
  dplyr::left_join(
    data_bien_traits_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_bien_traits_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::left_join(
    data_bien_traits_reference_db,
    by = dplyr::join_by(sampling_reference == reference_detail)
  ) %>%
  dplyr::select(
    dataset_name, data_source_id, dataset_type_id,
    coord_long, coord_lat,
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
  data = bien_traits_dataset,
  table_name = "Datasets"
)

bien_traits_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_dataset_raw_unique %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )

#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

bien_traits_samples_raw <-
  bien_traits_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "bien_traits_",
      id
    )
  ) %>%
  dplyr::left_join(
    bien_traits_dataset_raw_unique,
    by = dplyr::join_by(
      dataset_type, data_source_desc,
      coord_long, coord_lat,
      sampling_reference
    )
  )

# 4.1 samples -----

bien_traits_samples <-
  bien_traits_samples_raw %>%
  dplyr::distinct(sample_name) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::select(sample_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  )

add_to_db(
  conn = con,
  data = bien_traits_samples,
  table_name = "Samples"
)

bien_traits_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )


#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

data_bien_traits_dataset_sample <-
  bien_traits_samples_raw %>%
  dplyr::distinct(
    dataset_name, sample_name
  ) %>%
  dplyr::left_join(
    bien_traits_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    bien_traits_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_bien_traits_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)

#----------------------------------------------------------#
# 6. taxa -----
#----------------------------------------------------------#

bien_traits_taxa_raw <-
  bien_traits_samples_raw %>%
  dplyr::rename(taxon_name = scrubbed_species_binomial)

bien_traits_taxa <-
  bien_traits_taxa_raw %>%
  dplyr::distinct(taxon_name) %>%
  tidyr::drop_na() %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

add_to_db(
  conn = con,
  data = bien_traits_taxa,
  table_name = "Taxa"
)

bien_traits_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_taxa_raw %>%
      dplyr::distinct(taxon_name),
    by = dplyr::join_by(taxon_name)
  )

#----------------------------------------------------------#
# 7. Traits -----
#----------------------------------------------------------#
bien_traits_traits_raw <-
  bien_traits_samples_raw %>%
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
  )


# 7.1 Trait domains -----

bien_traits_trait_domain <-
  bien_traits_traits_raw %>%
  dplyr::distinct(trait_domain_name) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "TraitsDomain") %>%
      dplyr::select(trait_domain_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(trait_domain_name)
  )

add_to_db(
  conn = con,
  data = bien_traits_trait_domain,
  table_name = "TraitsDomain"
)

trait_domain_id <-
  dplyr::tbl(con, "TraitsDomain") %>%
  dplyr::select(trait_domain_id, trait_domain_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_traits_raw %>%
      dplyr::distinct(trait_domain_name),
    by = dplyr::join_by(trait_domain_name)
  )

# 7.2 Traits -----

bien_traits_traits <-
  bien_traits_traits_raw %>%
  dplyr::distinct(trait_domain_name, trait_name) %>%
  dplyr::left_join(
    trait_domain_id,
    by = dplyr::join_by(trait_domain_name)
  ) %>%
  dplyr::select(-trait_domain_name) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Traits") %>%
      dplyr::select(trait_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(trait_name)
  )

add_to_db(
  conn = con,
  data = bien_traits_traits,
  table_name = "Traits"
)

bien_traits_traits_id <-
  dplyr::tbl(con, "Traits") %>%
  dplyr::select(trait_id, trait_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    bien_traits_traits_raw %>%
      dplyr::distinct(trait_name),
    by = dplyr::join_by(trait_name)
  )

# 7.3 Trait value -----

bien_traits_traits_value <-
  bien_traits_traits_raw %>%
  dplyr::select(
    dataset_name, sample_name,
    trait_name,
    taxon_name = scrubbed_species_binomial,
    trait_value
  ) %>%
  tidyr::drop_na() %>%
  dplyr::left_join(
    bien_traits_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    bien_traits_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::left_join(
    bien_traits_traits_id,
    by = dplyr::join_by(trait_name)
  ) %>%
  dplyr::left_join(
    bien_traits_taxa_id,
    by = dplyr::join_by(taxon_name)
  ) %>%
  dplyr::select(
    trait_id, dataset_id, sample_id,
    taxon_id,
    trait_value
  )

dplyr::copy_to(
  con,
  bien_traits_traits_value,
  name = "TraitsValue",
  append = TRUE
)

#----------------------------------------------------------#
# 8. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
