#----------------------------------------------------------#
#
#
#                       VegVault
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
    path_to_vegvault
  )

DBI::dbListTables(con)


#----------------------------------------------------------#
# 2. Load data -----
#----------------------------------------------------------#

data_try <-
  load_local_trait_artifacts("data_trait_try_")


#----------------------------------------------------------#
# 3. Datasets -----
#----------------------------------------------------------#

try_dataset_raw <-
  data_try %>%
  dplyr::mutate(
    dataset_type = "traits",
    dataset_source_type = "TRY",
    data_source_type_reference = paste(
      "Kattge J, Bönisch G, Díaz S, et al. TRY plant trait database",
      "– enhanced coverage and open access. Glob Change Biol. 2020;",
      "26: 119–188. https://doi.org/10.1111/gcb.14904"
    ),
    data_source_desc = dataset,
    coord_long = as.numeric(longitude),
    coord_lat = as.numeric(latitude),
    data_source_reference = reference_source,
    sample_reference = dataset_reference_citation,
    dataset_reference = NA_character_
  )

try_dataset_raw_distinct <-
  try_dataset_raw %>%
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
  add_dataset_source_type(
    data_source = try_dataset_raw_distinct,
    con = con
  )

# - 3.3 dataset source -----
data_try_data_source_id_db <-
  add_data_source(
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

try_samples_raw <-
  try_sample_raw_id %>%
  dplyr::left_join(
    try_dataset_raw_distinct,
    by = dplyr::join_by(
      dataset_type,
      dataset_source_type, data_source_type_reference,
      data_source_desc, data_source_reference,
      coord_long, coord_lat,
      dataset_reference
    )
  ) %>%
  dplyr::mutate(
    age = 0,
    sample_size = NA_real_,
    description = NA_character_
  )

# 4.1 samples -----
try_samples_id <-
  add_samples(
    data_source = try_samples_raw,
    con = con
  )

#----------------------------------------------------------#
# 5. Dataset - Sample -----
#----------------------------------------------------------#

add_dataset_sample(
  data_source = try_samples_raw,
  dataset_id = try_dataset_id,
  sample_id = try_samples_id,
  con = con
)

#----------------------------------------------------------#
# 6. taxa -----
#----------------------------------------------------------#

try_taxa_raw <-
  try_samples_raw %>%
  dplyr::rename(taxon_name = acc_species_name) %>%
  dplyr::mutate(
    taxon_reference = "TRY"
  )

try_taxa_id <-
  add_taxa(
    data_source = try_taxa_raw,
    con = con
  )


#----------------------------------------------------------#
# 7. Traits -----
#----------------------------------------------------------#

try_traits_raw <-
  try_samples_raw %>%
  dplyr::rename(trait_domain_name = trait_domain) %>%
  dplyr::mutate(
    trait_reference = "TRY"
  )

data_try_trait_rules <-
  add_trait_rules(con = con)

# 7.1 Traits -----
try_traits_id <-
  add_traits(
    data_source = try_traits_raw,
    con = con
  )


# 7.3 Trait value -----

data_try_trait_audit <-
  try_traits_raw %>%
    dplyr::select(
      source_provider, source_dataset_key, source_record_id, source_trait_id,
      original_value_string, original_unit, normalized_original_unit,
      conversion_status, conversion_rule_key, derivation_rule_key, trait_unit,
      dataset_name, sample_name,
      trait_name = trait_full_name,
      taxon_name = acc_species_name,
      trait_value
    ) %>%
    add_trait_value(
      dataset_id = try_dataset_id,
      samples_id = try_samples_id,
      traits_id = try_traits_id,
      taxa_id = try_taxa_id,
      con = con
    )

path_trait_audit <-
  here::here("Data", "Temp", "trait_database_audit")
dir.create(path_trait_audit, recursive = TRUE, showWarnings = FALSE)
qs2::qs_save(
  object = data_try_trait_audit,
  file = file.path(path_trait_audit, "trait_database_audit_try.qs")
)


#----------------------------------------------------------#
# 8. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
