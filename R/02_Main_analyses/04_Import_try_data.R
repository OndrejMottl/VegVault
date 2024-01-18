#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                     Import TRY trait data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import TRY trait data

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
    dataset_type = "traits",
    dataset_source_type = "TRY",
    data_source_type_reference = "https://doi.org/10.1111/gcb.14904",
    data_source_desc = dataset,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    data_source_reference = dataset_reference_citation
  )

try_dataset_raw_distinct <-
  try_dataset_raw %>%
  dplyr::distinct(
    dataset_type,
    dataset_source_type, data_source_type_reference,
    data_source_desc,
    coord_long, coord_lat,
    data_source_reference
  ) %>%
  dplyr::mutate(
    dataset_name = paste0(
      "try_",
      dplyr::row_number()
    )
  )

# - 3.1 dataset type -----
data_try_dataset_type_id_db <-
  add_dataset_type(
    data_source = try_dataset_raw_distinct,
    con = con
  )

# - 3.2 dataset source type -----
data_try_dataset_source_type_db <-
  add_dataset_source_type_with_reference(
    data_source = try_dataset_raw_distinct,
    con = con
  )

# - 3.3 dataset source -----
data_try_data_source_id_db <-
  add_data_source_with_reference(
    data_source = try_dataset_raw_distinct,
    con = con
  )

# 3.4 datasets -----
try_dataset_id <-
  add_datasets(
    data_source = try_dataset_raw_distinct,
    con = con,
    data_type = data_try_dataset_type_id_db,
    data_source_type = data_try_dataset_source_type_db,
    dataset_source = data_try_data_source_id_db
  )

#----------------------------------------------------------#
# 4. Samples -----
#----------------------------------------------------------#

try_sample_raw_id <-
  try_dataset_raw %>%
  dplyr::mutate(
    sample_name = paste0(
      "try_",
      observation_id
    )
  )

try_samples_raw <
  try_sample_raw_id %>%
    dplyr::left_join(
      try_dataset_raw_distinct,
      by = dplyr::join_by(
        dataset_type, data_source_desc,
        coord_long, coord_lat
      ),
      relationship = "many-to-many"
    )

# 4.1 samples -----
try_samples_id <-
  add_samples_with_reference(
    data_source = try_samples_raw,
    con = con
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
    try_traits_raw %>%
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
