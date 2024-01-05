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

url_gh_traits <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Trait_data/",
    "main/"
  )

url_try <-
  paste0(
    url_gh_traits,
    "Outputs/Data/",
    "data_trait_try_2023-12-13__7fccd01cd7e534f3f233cf3d176f736a__.qs"
  )

data_try <-
  dowload_and_load(url_try)

#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

try_dataset_raw <-
  data_try %>%
  dplyr::mutate(
    dataset_type = "try",
    data_source_desc = dataset,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    sampling_reference = data_try$dataset_reference_citation
  )

try_dataset_raw_unique <-
  try_dataset_raw %>%
  dplyr::distinct(
    dataset_type, data_source_desc,
    coord_long, coord_lat,
    sampling_reference
  ) %>%
  dplyr::mutate(
    dataset_name = paste0(
      "try_",
      dplyr::row_number()
    )
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Datasets") %>%
      dplyr::select(dataset_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_name)
  )

# 3.1 dataset source -----

data_try_data_source_id <-
  try_dataset_raw_unique %>%
  dplyr::distinct(data_source_desc) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetSourcesID") %>%
      dplyr::select(data_source_desc) %>%
      dplyr::collect(),
    by = dplyr::join_by(data_source_desc)
  )

add_to_db(
  conn = con,
  data = data_try_data_source_id,
  table_name = "DatasetSourcesID"
)

data_try_data_source_id_db <-
  dplyr::tbl(con, "DatasetSourcesID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_dataset_raw %>%
      dplyr::distinct(data_source_desc),
    by = dplyr::join_by(data_source_desc)
  )

# 3.2 dataset type -----

data_try_dataset_type_id <-
  try_dataset_raw_unique %>%
  dplyr::distinct(dataset_type) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::select(dataset_type) %>%
      dplyr::collect(),
    by = dplyr::join_by(dataset_type)
  )

add_to_db(
  conn = con,
  data = data_try_dataset_type_id,
  table_name = "DatasetTypeID"
)

data_try_dataset_type_id_db <-
  dplyr::tbl(con, "DatasetTypeID") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_dataset_raw %>%
      dplyr::distinct(dataset_type),
    by = dplyr::join_by(dataset_type)
  )

# 3.3 dataset reference -----

data_try_reference <-
  try_dataset_raw_unique %>%
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
  data = data_try_reference,
  table_name = "References"
)

data_try_reference_db <-
  dplyr::tbl(con, "References") %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_dataset_raw_unique %>%
      dplyr::distinct(sampling_reference),
    by = dplyr::join_by(reference_detail == sampling_reference)
  )

# 3.4 datasets -----

try_dataset <-
  try_dataset_raw_unique %>%
  dplyr::left_join(
    data_try_data_source_id_db,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::left_join(
    data_try_dataset_type_id_db,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::left_join(
    data_try_reference_db,
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
  data = try_dataset,
  table_name = "Datasets"
)

try_dataset_id <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::select(dataset_id, dataset_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_dataset_raw_unique %>%
      dplyr::distinct(dataset_name),
    by = dplyr::join_by(dataset_name)
  )

#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

try_samples_raw <-
  try_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "try_",
      observation_id
    )
  ) %>%
  dplyr::left_join(
    try_dataset_raw_unique,
    by = dplyr::join_by(
      dataset_type, data_source_desc,
      coord_long, coord_lat,
      sampling_reference
    )
  )


# 4.1 samples references -----

try_samples_reference <-
  try_samples_raw %>%
  dplyr::distinct(reference_source) %>%
  tidyr::drop_na() %>%
  dplyr::rename(
    reference_detail = reference_source
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "References") %>%
      dplyr::select(reference_detail) %>%
      dplyr::collect(),
    by = dplyr::join_by(reference_detail)
  )

add_to_db(
  conn = con,
  data = try_samples_reference,
  table_name = "References"
)

try_samples_reference_id <-
  dplyr::tbl(con, "References") %>%
  dplyr::select(reference_id, reference_detail) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_samples_raw %>%
      dplyr::distinct(reference_source),
    by = dplyr::join_by(reference_detail == reference_source)
  )


# 4.1 samples -----

try_samples <-
  try_samples_raw %>%
  dplyr::distinct(sample_name, reference_source) %>%
  dplyr::left_join(
    try_samples_reference_id,
    by = dplyr::join_by(reference_source == reference_detail)
  ) %>%
  dplyr::select(-reference_source) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Samples") %>%
      dplyr::select(sample_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::rename(
    sample_reference = reference_id
  )

add_to_db(
  conn = con,
  data = try_samples,
  table_name = "Samples"
)

try_samples_id <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::select(sample_id, sample_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_samples_raw %>%
      dplyr::distinct(sample_name),
    by = dplyr::join_by(sample_name)
  )

#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

data_try_dataset_sample <-
  try_samples_raw %>%
  dplyr::distinct(
    dataset_name, sample_name
  ) %>%
  dplyr::left_join(
    try_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    try_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::select(
    dataset_id, sample_id
  )

dplyr::copy_to(
  con,
  data_try_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)


#----------------------------------------------------------#
# 6. taxa -----
#----------------------------------------------------------#

try_taxa_raw <-
  try_samples_raw %>%
  dplyr::rename(taxon_name = acc_species_name)

try_taxa <-
  try_taxa_raw %>%
  dplyr::distinct(taxon_name) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Taxa") %>%
      dplyr::select(taxon_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(taxon_name)
  )

add_to_db(
  conn = con,
  data = try_taxa,
  table_name = "Taxa"
)

try_taxa_id <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::select(taxon_id, taxon_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_taxa_raw %>%
      dplyr::distinct(taxon_name),
    by = dplyr::join_by(taxon_name)
  )


#----------------------------------------------------------#
# 7. Traits -----
#----------------------------------------------------------#

try_traits_raw <-
  try_samples_raw %>%
  dplyr::rename(trait_domain_name = trait_domain)


# 7.1 Trait domains -----

try_trait_domain <-
  try_traits_raw %>%
  dplyr::distinct(trait_domain_name) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "TraitsDomain") %>%
      dplyr::select(trait_domain_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(trait_domain_name)
  )

add_to_db(
  conn = con,
  data = try_trait_domain,
  table_name = "TraitsDomain"
)

trait_domain_id <-
  dplyr::tbl(con, "TraitsDomain") %>%
  dplyr::select(trait_domain_id, trait_domain_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_traits_raw %>%
      dplyr::distinct(trait_domain_name),
    by = dplyr::join_by(trait_domain_name)
  )

# 7.2 Traits -----

try_traits <-
  try_traits_raw %>%
  dplyr::distinct(trait_domain_name, trait_full_name) %>%
  dplyr::left_join(
    trait_domain_id,
    by = dplyr::join_by(trait_domain_name)
  ) %>%
  dplyr::select(-trait_domain_name) %>%
  dplyr::rename(
    trait_name = trait_full_name
  ) %>%
  dplyr::anti_join(
    dplyr::tbl(con, "Traits") %>%
      dplyr::select(trait_name) %>%
      dplyr::collect(),
    by = dplyr::join_by(trait_name)
  )

add_to_db(
  conn = con,
  data = try_traits,
  table_name = "Traits"
)

try_traits_id <-
  dplyr::tbl(con, "Traits") %>%
  dplyr::select(trait_id, trait_name) %>%
  dplyr::collect() %>%
  dplyr::inner_join(
    try_traits_raw  %>% 
      dplyr::distinct(trait_full_name),
    by = dplyr::join_by(trait_name == trait_full_name)
  )

# 7.3 Trait value -----

try_traits_value <-
  try_traits_raw %>%
  dplyr::select(
    dataset_name, sample_name,
    trait_name = trait_full_name,
    taxon_name = acc_species_name,
    trait_value
  ) %>%
  dplyr::left_join(
    try_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) %>%
  dplyr::left_join(
    try_samples_id,
    by = dplyr::join_by(sample_name)
  ) %>%
  dplyr::left_join(
    try_traits_id,
    by = dplyr::join_by(trait_name)
  ) %>%
  dplyr::left_join(
    try_taxa_id,
    by = dplyr::join_by(taxon_name)
  ) %>%
  dplyr::select(
    trait_id, dataset_id, sample_id,
    taxon_id,
    trait_value
  )

dplyr::copy_to(
  con,
  try_traits_value,
  name = "TraitsValue",
  append = TRUE
)

#----------------------------------------------------------#
# 8. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
