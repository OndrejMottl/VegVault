#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Smoke test: contract fixtures through the import
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Show that the synthetic fixtures in Data/Contracts/fixtures/valid/ carry
#   everything the v1 import needs. The fixtures are read and validated
#   with validate_producer_artefact(), transformed as the import scripts
#   R/02_Main_analyses/01 to 09 transform the real artefacts, and written
#   with the existing writers into an empty schema built from
#   Data/SQL/make_tables.sql in a temporary SQLite file. The live database
#   is never touched. The trait writers read the unit-conversion registry
#   from the sibling VegVault-Trait_data checkout (save_trait_rules()), as
#   the trait import scripts do.
# Also checks that the unit and detail strings of the climate and soil
#   contracts equal the strings hard-coded in scripts 07, 08 and 09.
# Run from the repository root:
#   Rscript tests/test_contract_fixtures_integration.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_function_files <-
  base::list.files(
    path = here::here("R", "Functions"),
    pattern = "[.]R$",
    recursive = TRUE,
    full.names = TRUE
  )

purrr::walk(
  .x = vec_function_files,
  .f = ~ base::source(file = .x, encoding = "UTF-8")
)

# The v1 writers call %>% and other functions without a namespace and rely
#   on R/00_Config_file.R to attach packages. That file is not sourced here
#   because it restores renv and resolves the live database path, so the
#   packages the writers need are attached directly
purrr::walk(
  .x = c("assertthat", "DBI", "RSQLite", "rlang", "tidyverse"),
  .f = ~ base::suppressPackageStartupMessages(
    base::library(package = .x, character.only = TRUE)
  )
)

path_database <-
  base::tempfile(fileext = ".sqlite")

con <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_database
  )

# The connection is closed and the file deleted in section 9; if the
#   script stops earlier, R deletes its temporary directory on exit
DBI::dbExecute(conn = con, statement = "PRAGMA foreign_keys = ON")

text_schema <-
  base::readLines(here::here("Data", "SQL", "make_tables.sql")) |>
  stringr::str_c(collapse = "\n")

vec_statements <-
  stringr::str_split_1(string = text_schema, pattern = stringr::fixed(";")) |>
  stringr::str_trim()

purrr::walk(
  .x = vec_statements[vec_statements != ""],
  .f = ~ DBI::dbExecute(conn = con, statement = .x)
)

text_reference <- "Synthetic reference written by the contract smoke test"


#----------------------------------------------------------#
# 1. Read and validate the fixtures -----
#----------------------------------------------------------#

vec_contract_ids <-
  c(
    "splot_plots", "bien_plots", "fossilpol_assembly",
    "fossilpol_age_uncertainty", "try_traits", "bien_traits",
    "chelsa_neoclimate", "chelsa_trace21k_palaeoclimate", "wosis_soil"
  )

list_contracts <-
  purrr::map(
    .x = vec_contract_ids,
    .f = ~ load_producer_contract(
      path_contract = here::here(
        "Data", "Contracts", stringr::str_c(.x, ".yml")
      )
    )
  ) |>
  rlang::set_names(vec_contract_ids)

list_artefacts <-
  purrr::map(
    .x = vec_contract_ids,
    .f = ~ validate_producer_artefact(
      contract = purrr::chuck(list_contracts, .x),
      path_artefact = base::list.files(
        path = here::here("Data", "Contracts", "fixtures", "valid", .x),
        full.names = TRUE
      ),
      verbose = FALSE
    )
  ) |>
  rlang::set_names(vec_contract_ids)


#----------------------------------------------------------#
# 2. sPlotOpen (as 01_Import_splot_data.R) -----
#----------------------------------------------------------#

data_splot <-
  purrr::chuck(list_artefacts, "splot_plots", 1)

data_splot_datasets <-
  data_splot |>
  dplyr::mutate(
    dataset_type = "vegetation_plot",
    dataset_source_type = "sPlotOpen",
    data_source_type_reference = text_reference,
    data_source_desc = givd_id,
    data_source_reference = NA_character_,
    dataset_name = stringr::str_c("splot_", plot_observation_id),
    coord_long = base::as.numeric(longitude),
    coord_lat = base::as.numeric(latitude),
    dataset_reference = NA_character_
  )

data_splot_dataset_id <-
  save_datasets(
    data_source = data_splot_datasets,
    con = con,
    data_type = save_dataset_type(data_source = data_splot_datasets, con = con),
    data_source_type = save_dataset_source_type(
      data_source = data_splot_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_splot_datasets,
      con = con
    )
  )

data_splot_samples <-
  data_splot_datasets |>
  dplyr::mutate(
    sample_name = stringr::str_c("splot_", plot_observation_id),
    age = 0,
    sample_size = releve_area,
    description = "square meters",
    sample_reference = NA_character_
  )

data_splot_samples_id <-
  save_samples(data_source = data_splot_samples, con = con)

save_dataset_sample(
  data_source = data_splot_samples,
  con = con,
  dataset_id = data_splot_dataset_id,
  sample_id = data_splot_samples_id
)

data_splot_taxa <-
  data_splot_samples |>
  dplyr::pull(taxa) |>
  purrr::map(.f = ~ purrr::chuck(.x, "Species")) |>
  purrr::list_c() |>
  base::unique() |>
  base::sort() |>
  tibble::enframe(name = NULL, value = "taxon_name") |>
  dplyr::filter(taxon_name != "") |>
  dplyr::mutate(taxon_reference = "sPlotOpen")

data_splot_taxa_id <-
  save_taxa(data_source = data_splot_taxa, con = con)

data_splot_sample_taxa <-
  data_splot_samples |>
  dplyr::select(sample_name, taxa) |>
  tidyr::unnest(taxa) |>
  dplyr::rename(taxon_name = Species, value = Original_abundance) |>
  dplyr::select(sample_name, taxon_name, value)

save_sample_taxa(
  data_source = data_splot_sample_taxa,
  con = con,
  samples_id = data_splot_samples_id,
  taxa_id = data_splot_taxa_id
)


#----------------------------------------------------------#
# 3. BIEN plots (as 02_Import_bien_data.R) -----
#----------------------------------------------------------#

data_bien <-
  purrr::chuck(list_artefacts, "bien_plots", 1)

data_bien_datasets <-
  data_bien |>
  dplyr::mutate(
    dataset_type = "vegetation_plot",
    dataset_source_type = "BIEN",
    data_source_type_reference = text_reference,
    data_source_desc = datasource,
    data_source_reference = NA_character_,
    dataset_name = stringr::str_c("bien_", dplyr::row_number()),
    coord_long = longitude,
    coord_lat = latitude,
    sampling_reference = purrr::map(
      .x = methodology_reference,
      .f = ~ c("BIEN", .x)
    ),
    sampling_method_details = methodology_description,
    dataset_reference = NA_character_
  )

data_bien_dataset_id <-
  save_datasets(
    data_source = data_bien_datasets,
    con = con,
    data_type = save_dataset_type(data_source = data_bien_datasets, con = con),
    data_source_type = save_dataset_source_type(
      data_source = data_bien_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_bien_datasets,
      con = con
    ),
    sampling_method = save_sampling_method(
      data_source = data_bien_datasets,
      con = con
    )
  )

data_bien_samples <-
  data_bien_datasets |>
  dplyr::mutate(
    sample_name = stringr::str_c("bien_", dplyr::row_number()),
    age = 0,
    sample_size = plot_area_ha * 10000,
    description = "square meters",
    sample_reference = NA_character_
  )

data_bien_samples_id <-
  save_samples(data_source = data_bien_samples, con = con)

save_dataset_sample(
  data_source = data_bien_samples,
  con = con,
  dataset_id = data_bien_dataset_id,
  sample_id = data_bien_samples_id
)

data_bien_taxa <-
  data_bien_samples |>
  dplyr::pull(plot_data) |>
  purrr::map(.f = ~ purrr::chuck(.x, "name_matched")) |>
  purrr::list_c() |>
  base::unique() |>
  base::sort() |>
  tibble::enframe(name = NULL, value = "taxon_name") |>
  dplyr::filter(taxon_name != "") |>
  tidyr::drop_na() |>
  dplyr::mutate(taxon_reference = "BIEN")

data_bien_taxa_id <-
  save_taxa(data_source = data_bien_taxa, con = con)

data_bien_sample_taxa <-
  data_bien_samples |>
  dplyr::select(sample_name, plot_data) |>
  tidyr::unnest(plot_data) |>
  dplyr::rename(taxon_name = name_matched, value = individual_count) |>
  dplyr::select(sample_name, taxon_name, value)

save_sample_taxa(
  data_source = data_bien_sample_taxa,
  con = con,
  samples_id = data_bien_samples_id,
  taxa_id = data_bien_taxa_id
)


#----------------------------------------------------------#
# 4. FOSSILPOL (as 03_Import_fossilpol_data.R) -----
#----------------------------------------------------------#

data_fossilpol <-
  purrr::chuck(list_artefacts, "fossilpol_assembly", 1)

data_fossilpol_datasets <-
  data_fossilpol |>
  dplyr::mutate(
    dataset_type = "fossil_pollen_archive",
    dataset_source_type = "FOSSILPOL",
    data_source_type_reference = text_reference,
    data_source_desc = source_of_data,
    data_source_reference = text_reference,
    dataset_name = stringr::str_c("fossilpol_", dataset_id),
    dataset_reference = doi,
    coord_long = long,
    coord_lat = lat,
    sampling_method_details = depositionalenvironment,
    sampling_reference = "Neotoma"
  ) |>
  dplyr::select(-dataset_id)

data_fossilpol_dataset_id <-
  save_datasets(
    data_source = data_fossilpol_datasets,
    con = con,
    data_type = save_dataset_type(
      data_source = data_fossilpol_datasets,
      con = con
    ),
    data_source_type = save_dataset_source_type(
      data_source = data_fossilpol_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_fossilpol_datasets,
      con = con,
      mandatory = TRUE
    ),
    sampling_method = save_sampling_method(
      data_source = data_fossilpol_datasets,
      con = con
    )
  )

# The v1 script names samples with the database dataset_id and replaces
#   missing numeric values by 0; the contract forbids missing ages and
#   counts, so no value is replaced here
data_fossilpol_levels <-
  data_fossilpol_datasets |>
  dplyr::left_join(
    data_fossilpol_dataset_id,
    by = dplyr::join_by(dataset_name)
  ) |>
  dplyr::mutate(
    samples = purrr::map2(
      .x = levels,
      .y = counts_harmonised,
      .f = ~ .x |>
        dplyr::select(sample_id, age) |>
        dplyr::inner_join(.y, by = dplyr::join_by(sample_id))
    )
  ) |>
  dplyr::select(dataset_name, dataset_id, samples) |>
  tidyr::unnest(samples) |>
  dplyr::mutate(
    sample_name = stringr::str_c("fossilpol_", dataset_id, "_", sample_id),
    sample_size = NA_real_,
    description = NA_character_,
    sample_reference = NA_character_
  )

data_fossilpol_samples_id <-
  save_samples(
    data_source = dplyr::select(
      data_fossilpol_levels,
      dataset_name, sample_name, age, sample_size, description,
      sample_reference
    ),
    con = con
  )

save_dataset_sample(
  data_source = dplyr::select(
    data_fossilpol_levels,
    dataset_name, sample_name
  ),
  dataset_id = data_fossilpol_dataset_id,
  sample_id = data_fossilpol_samples_id,
  con = con
)

data_fossilpol_uncertainty <-
  purrr::chuck(list_artefacts, "fossilpol_age_uncertainty") |>
  dplyr::bind_rows() |>
  dplyr::mutate(
    dataset_name = stringr::str_c("fossilpol_", dataset_id),
    age_uncertainty_nested = purrr::map(
      .x = age_uncertainty,
      .f = ~ base::as.data.frame(.x) |>
        tibble::rowid_to_column("iteration") |>
        tidyr::pivot_longer(
          cols = -iteration,
          names_to = "sample_id",
          values_to = "age"
        )
    )
  ) |>
  dplyr::select(-c(dataset_id, age_uncertainty)) |>
  tidyr::unnest(age_uncertainty_nested)

save_sample_age_uncertainty(
  data_source = data_fossilpol_uncertainty,
  dataset_id = data_fossilpol_dataset_id,
  samples_id = data_fossilpol_samples_id,
  con = con,
  sel_name = "fossilpol_"
)

# Taxa are the count columns only; the v1 script also takes the sample
#   description columns as taxa, a v1 defect that is not repeated here
vec_fossilpol_taxa <-
  data_fossilpol_levels |>
  dplyr::select(
    -c(
      dataset_name, dataset_id, sample_id, age, sample_name, sample_size,
      description, sample_reference
    )
  ) |>
  base::names()

data_fossilpol_taxa_id <-
  save_taxa(
    data_source = tibble::tibble(
      taxon_name = base::sort(vec_fossilpol_taxa),
      taxon_reference = "Neotoma"
    ),
    con = con
  )

data_fossilpol_sample_taxa <-
  data_fossilpol_levels |>
  dplyr::select(sample_name, dplyr::all_of(vec_fossilpol_taxa)) |>
  tidyr::pivot_longer(
    cols = -sample_name,
    names_to = "taxon_name",
    values_to = "value"
  ) |>
  dplyr::filter(value > 0)

save_sample_taxa(
  data_source = data_fossilpol_sample_taxa,
  taxa_id = data_fossilpol_taxa_id,
  samples_id = data_fossilpol_samples_id,
  con = con
)


#----------------------------------------------------------#
# 5. Gridpoints (stand-in for 06_Create_gridpoints.R) -----
#----------------------------------------------------------#

# Only the gridpoint datasets and samples the abiotic writers attach to;
#   links between gridpoints and other samples belong to the gridpoint
#   stage and are not built here
data_neo_grid <-
  purrr::chuck(list_artefacts, "chelsa_neoclimate", 1) |>
  dplyr::select(long, lat)

vec_trace_time_ids <-
  purrr::chuck(list_artefacts, "chelsa_trace21k_palaeoclimate") |>
  purrr::map(.f = ~ dplyr::pull(.x, time_id)) |>
  purrr::list_c() |>
  base::unique() |>
  base::as.numeric()

# Age in years before 1950, as save_chelsa_trace_data.R:39 computes it
vec_grid_ages <-
  base::sort(base::unique(c(0, -vec_trace_time_ids * 100 + 2000)))

data_grid_samples <-
  tidyr::expand_grid(data_neo_grid, age = vec_grid_ages) |>
  dplyr::mutate(
    dataset_type = "gridpoints",
    dataset_source_type = "gridpoints",
    data_source_type_reference = text_reference,
    data_source_desc = "gridpoints",
    data_source_reference = text_reference,
    dataset_reference = text_reference,
    coord_long = long,
    coord_lat = lat,
    dataset_name = stringr::str_c(
      "geo_",
      base::round(long, digits = 2),
      "_",
      base::round(lat, digits = 2)
    ),
    sample_name = stringr::str_c(dataset_name, "_", age),
    sample_size = NA_real_,
    description = "gridpoint",
    sample_reference = text_reference
  )

data_grid_datasets <-
  dplyr::distinct(
    data_grid_samples,
    dataset_type, dataset_source_type, data_source_type_reference,
    data_source_desc, data_source_reference, dataset_reference,
    coord_long, coord_lat, dataset_name
  )

data_grid_dataset_id <-
  save_datasets(
    data_source = data_grid_datasets,
    con = con,
    data_type = save_dataset_type(data_source = data_grid_datasets, con = con),
    data_source_type = save_dataset_source_type(
      data_source = data_grid_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_grid_datasets,
      con = con
    )
  )

data_grid_samples_id <-
  save_samples(data_source = data_grid_samples, con = con)

save_dataset_sample(
  data_source = data_grid_samples,
  con = con,
  dataset_id = data_grid_dataset_id,
  sample_id = data_grid_samples_id
)


#----------------------------------------------------------#
# 6. Climate and soil (as 07, 08 and 09) -----
#----------------------------------------------------------#

# Units and details come from the contracts' variables tables instead of
#   being hard-coded as in the v1 scripts; each file is matched to its
#   variable through the file name
data_samples_db <-
  dplyr::tbl(con, "Samples") |>
  dplyr::distinct(sample_id, sample_name) |>
  dplyr::collect()

data_climate_files <-
  dplyr::bind_rows(
    purrr::map(
      .x = c("chelsa_neoclimate", "chelsa_trace21k_palaeoclimate"),
      .f = ~ build_producer_file_table(
        vec_file_names = base::names(purrr::chuck(list_artefacts, .x)),
        contract = purrr::chuck(list_contracts, .x)
      ) |>
        dplyr::mutate(
          contract_id = .x,
          data_file = purrr::chuck(list_artefacts, .x) |> base::unname()
        )
    )
  )

data_climate_variables <-
  purrr::map(
    .x = c("chelsa_neoclimate", "chelsa_trace21k_palaeoclimate"),
    .f = ~ purrr::chuck(list_contracts, .x, "variables", "table") |>
      purrr::map(
        .f = ~ tibble::tibble(
          variable = purrr::chuck(.x, "variable"),
          var_unit = purrr::chuck(.x, "unit"),
          var_detail = purrr::chuck(.x, "description")
        )
      ) |>
      dplyr::bind_rows() |>
      dplyr::mutate(contract_id = .x)
  ) |>
  dplyr::bind_rows()

data_climate_values <-
  data_climate_files |>
  dplyr::left_join(
    data_climate_variables,
    by = dplyr::join_by(contract_id, variable)
  ) |>
  dplyr::select(contract_id, variable, var_unit, var_detail, data_file) |>
  tidyr::unnest(data_file) |>
  dplyr::mutate(
    # Present-day values sit at age 0; palaeoclimate age 0 is skipped as
    #   save_chelsa_trace_data.R:44 does
    age = dplyr::if_else(
      contract_id == "chelsa_neoclimate",
      0,
      -base::as.numeric(time_id) * 100 + 2000
    ),
    abiotic_variable_name = variable
  ) |>
  dplyr::filter(age > 0 | contract_id == "chelsa_neoclimate") |>
  dplyr::select(
    long, lat, value, age, abiotic_variable_name, var_unit, var_detail
  )

data_soil_values <-
  purrr::chuck(list_artefacts, "wosis_soil", 1) |>
  dplyr::mutate(
    age = 0,
    abiotic_variable_name = var_name,
    var_unit = "Unitless",
    var_detail = "SoilGrids-soil_class"
  ) |>
  dplyr::select(
    long, lat, value, age, abiotic_variable_name, var_unit, var_detail
  )

data_abiotic_values <-
  dplyr::bind_rows(data_climate_values, data_soil_values) |>
  dplyr::mutate(
    dataset_name = stringr::str_c(
      "geo_",
      base::round(long, digits = 2),
      "_",
      base::round(lat, digits = 2)
    ),
    sample_name = stringr::str_c(dataset_name, "_", age),
    var_reference = text_reference
  ) |>
  dplyr::filter(sample_name %in% dplyr::pull(data_samples_db, sample_name))

data_abiotic_variable_id <-
  save_abiotic_variable(data_source = data_abiotic_values, con = con)

save_sample_abiotic_value(
  data_source = data_abiotic_values,
  con = con,
  sample_id = data_samples_db,
  abiotic_variable_id = data_abiotic_variable_id
)


#----------------------------------------------------------#
# 7. Traits (as 04_Import_try_data.R and 05) -----
#----------------------------------------------------------#

#--------------------------------------------------#
## 7.1 TRY -----
#--------------------------------------------------#

data_try <-
  purrr::chuck(list_artefacts, "try_traits", 1)

data_try_records <-
  data_try |>
  dplyr::mutate(
    dataset_type = "traits",
    dataset_source_type = "TRY",
    data_source_type_reference = text_reference,
    data_source_desc = dataset,
    coord_long = base::as.numeric(longitude),
    coord_lat = base::as.numeric(latitude),
    data_source_reference = reference_source,
    sample_reference = dataset_reference_citation,
    dataset_reference = NA_character_
  )

# One dataset per combination of source, location and references
data_try_datasets <-
  data_try_records |>
  dplyr::distinct(
    dataset_type, dataset_source_type, data_source_type_reference,
    data_source_desc, coord_long, coord_lat, data_source_reference,
    dataset_reference
  ) |>
  dplyr::mutate(dataset_name = stringr::str_c("try_", dplyr::row_number()))

data_try_dataset_id <-
  save_datasets(
    data_source = data_try_datasets,
    con = con,
    data_type = save_dataset_type(data_source = data_try_datasets, con = con),
    data_source_type = save_dataset_source_type(
      data_source = data_try_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_try_datasets,
      con = con
    )
  )

data_try_samples <-
  data_try_records |>
  dplyr::mutate(sample_name = stringr::str_c("try_", observation_id)) |>
  dplyr::left_join(
    data_try_datasets,
    by = dplyr::join_by(
      dataset_type, dataset_source_type, data_source_type_reference,
      data_source_desc, data_source_reference, coord_long, coord_lat,
      dataset_reference
    )
  ) |>
  dplyr::mutate(
    age = 0,
    sample_size = NA_real_,
    description = NA_character_
  )

data_try_samples_id <-
  save_samples(data_source = data_try_samples, con = con)

save_dataset_sample(
  data_source = data_try_samples,
  dataset_id = data_try_dataset_id,
  sample_id = data_try_samples_id,
  con = con
)

data_try_taxa_id <-
  save_taxa(
    data_source = data_try_samples |>
      dplyr::rename(taxon_name = acc_species_name) |>
      dplyr::mutate(taxon_reference = "TRY"),
    con = con
  )

data_try_traits <-
  data_try_samples |>
  dplyr::rename(trait_domain_name = trait_domain) |>
  dplyr::mutate(trait_reference = "TRY")

data_trait_rules <-
  save_trait_rules(con = con)

data_try_traits_id <-
  save_traits(data_source = data_try_traits, con = con)

data_try_trait_audit <-
  data_try_traits |>
  dplyr::select(
    source_provider, source_dataset_key, source_record_id, source_trait_id,
    original_value_string, original_unit, normalized_original_unit,
    conversion_status, conversion_rule_key, derivation_rule_key, trait_unit,
    dataset_name, sample_name,
    trait_name = trait_full_name,
    taxon_name = acc_species_name,
    trait_value
  ) |>
  save_trait_value(
    dataset_id = data_try_dataset_id,
    samples_id = data_try_samples_id,
    traits_id = data_try_traits_id,
    taxa_id = data_try_taxa_id,
    con = con
  )

#--------------------------------------------------#
## 7.2 BIEN traits -----
#--------------------------------------------------#

data_bien_traits <-
  purrr::chuck(list_artefacts, "bien_traits") |>
  dplyr::bind_rows()

data_bien_trait_records <-
  data_bien_traits |>
  dplyr::mutate(
    dataset_type = "traits",
    dataset_source_type = "BIEN",
    data_source_type_reference = text_reference,
    data_source_desc = project_pi,
    coord_long = base::as.numeric(longitude),
    coord_lat = base::as.numeric(latitude),
    data_source_reference = source_citation,
    dataset_reference = NA_character_
  )

data_bien_trait_datasets <-
  data_bien_trait_records |>
  dplyr::distinct(
    dataset_type, dataset_source_type, data_source_type_reference,
    data_source_desc, coord_long, coord_lat, data_source_reference,
    dataset_reference
  ) |>
  dplyr::mutate(
    dataset_name = stringr::str_c("bien_traits_", dplyr::row_number())
  )

data_bien_trait_dataset_id <-
  save_datasets(
    data_source = data_bien_trait_datasets,
    con = con,
    data_type = save_dataset_type(
      data_source = data_bien_trait_datasets,
      con = con
    ),
    data_source_type = save_dataset_source_type(
      data_source = data_bien_trait_datasets,
      con = con
    ),
    dataset_source = save_data_source(
      data_source = data_bien_trait_datasets,
      con = con
    )
  )

data_bien_trait_samples <-
  data_bien_trait_records |>
  dplyr::mutate(sample_name = stringr::str_c("bien_traits_", id)) |>
  dplyr::left_join(
    data_bien_trait_datasets,
    by = dplyr::join_by(
      dataset_type, data_source_desc, coord_long, coord_lat,
      dataset_source_type, data_source_type_reference,
      data_source_reference, dataset_reference
    )
  ) |>
  dplyr::mutate(
    age = 0,
    sample_size = NA_real_,
    description = NA_character_,
    sample_reference = NA_character_
  )

data_bien_trait_samples_id <-
  save_samples(data_source = data_bien_trait_samples, con = con)

save_dataset_sample(
  data_source = data_bien_trait_samples,
  dataset_id = data_bien_trait_dataset_id,
  sample_id = data_bien_trait_samples_id,
  con = con
)

data_bien_trait_taxa <-
  data_bien_trait_samples |>
  dplyr::rename(taxon_name = scrubbed_species_binomial) |>
  dplyr::mutate(taxon_reference = "BIEN")

data_bien_trait_taxa_id <-
  save_taxa(data_source = data_bien_trait_taxa, con = con)

data_bien_trait_traits <-
  data_bien_trait_taxa |>
  dplyr::rename(trait_domain_name = trait_domain) |>
  dplyr::mutate(trait_reference = "BIEN")

data_bien_trait_traits_id <-
  save_traits(data_source = data_bien_trait_traits, con = con)

data_bien_trait_audit <-
  data_bien_trait_traits |>
  dplyr::select(
    source_provider, source_dataset_key, source_record_id, source_trait_id,
    original_value_string, original_unit, normalized_original_unit,
    conversion_status, conversion_rule_key, derivation_rule_key, trait_unit,
    dataset_name, sample_name,
    trait_name = trait_full_name,
    taxon_name,
    trait_value
  ) |>
  save_trait_value(
    dataset_id = data_bien_trait_dataset_id,
    samples_id = data_bien_trait_samples_id,
    traits_id = data_bien_trait_traits_id,
    taxa_id = data_bien_trait_taxa_id,
    con = con
  )


#----------------------------------------------------------#
# 8. Unit strings equal the v1 import scripts -----
#----------------------------------------------------------#

# Each call of save_chelsa_neo_data() or save_chelsa_trace_data() in the v1
#   scripts passes sel_var_name, sel_var_unit and sel_var_detail; they are
#   read per call and compared with the contracts
data_script_calls <-
  tibble::tibble(
    contract_id = c("chelsa_neoclimate", "chelsa_trace21k_palaeoclimate"),
    path_script = here::here(
      "R", "02_Main_analyses",
      c(
        "07_Import_chelsa_neo_climate_data.R",
        "08_Import_chelsa_trace21k_climate_data.R"
      )
    )
  ) |>
  dplyr::mutate(
    text_calls = purrr::map(
      .x = path_script,
      .f = ~ base::readLines(.x) |>
        stringr::str_c(collapse = "\n") |>
        stringr::str_split_1(pattern = "save_chelsa_(neo|trace)_data\\(") |>
        utils::tail(-1)
    )
  ) |>
  tidyr::unnest(text_calls) |>
  dplyr::mutate(
    variable = stringr::str_match(
      text_calls, "sel_var_name = \"([^\"]+)\""
    )[, 2],
    unit_script = stringr::str_match(
      text_calls, "sel_var_unit = \"([^\"]+)\""
    )[, 2],
    detail_script = stringr::str_match(
      text_calls, "sel_var_detail = \"([^\"]+)\""
    )[, 2]
  ) |>
  dplyr::filter(!base::is.na(variable))

data_unit_checks <-
  data_climate_variables |>
  dplyr::left_join(
    dplyr::select(
      data_script_calls,
      contract_id, variable, unit_script, detail_script
    ),
    by = dplyr::join_by(contract_id, variable)
  ) |>
  dplyr::mutate(
    is_unit_equal = var_unit == unit_script,
    is_detail_equal = var_detail == detail_script
  )

value_soil_unit <-
  purrr::chuck(list_contracts, "wosis_soil", "columns") |>
  purrr::keep(.p = ~ purrr::chuck(.x, "name") == "value") |>
  purrr::chuck(1, "unit")

flag_soil_unit <-
  base::readLines(
    here::here("R", "02_Main_analyses", "09_Import_wosis_soil_data.R")
  ) |>
  stringr::str_detect(
    pattern = stringr::fixed(
      stringr::str_c("var_unit = \"", value_soil_unit, "\"")
    )
  ) |>
  base::any()


#----------------------------------------------------------#
# 9. Checks -----
#----------------------------------------------------------#

n_splot <- base::nrow(data_splot)

n_bien <- base::nrow(data_bien)

n_fossilpol_levels <- base::nrow(data_fossilpol_levels)

n_grid_samples <- base::nrow(data_grid_samples)

# Trait records share samples: one sample per observation (TRY) or
#   measurement (BIEN)
n_trait_samples <-
  dplyr::n_distinct(dplyr::pull(data_try_samples, sample_name)) +
  dplyr::n_distinct(dplyr::pull(data_bien_trait_samples, sample_name))

n_trait_datasets <-
  base::nrow(data_try_datasets) + base::nrow(data_bien_trait_datasets)

n_samples_expected <-
  n_splot + n_bien + n_fossilpol_levels + n_grid_samples + n_trait_samples

data_expected <-
  tibble::tibble(
    table_name = c(
      "Datasets", "Samples", "DatasetSample", "SampleTaxa",
      "SampleUncertainty", "AbioticData", "AbioticVariable", "TraitsValue"
    ),
    n_expected = c(
      n_splot + n_bien + base::nrow(data_fossilpol) +
        base::nrow(data_neo_grid) + n_trait_datasets,
      n_samples_expected,
      n_samples_expected,
      base::nrow(data_splot_sample_taxa) +
        base::nrow(data_bien_sample_taxa) +
        base::nrow(data_fossilpol_sample_taxa),
      base::nrow(data_fossilpol_uncertainty),
      base::nrow(data_abiotic_values),
      base::length(
        base::unique(dplyr::pull(data_abiotic_values, abiotic_variable_name))
      ),
      base::nrow(data_try) + base::nrow(data_bien_traits)
    )
  ) |>
  dplyr::mutate(
    n_observed = purrr::map_int(
      .x = table_name,
      .f = ~ DBI::dbGetQuery(
        conn = con,
        statement = stringr::str_c("SELECT COUNT(*) AS n FROM ", .x)
      ) |>
        dplyr::pull(n) |>
        base::as.integer()
    )
  )

n_fk_violations <-
  DBI::dbGetQuery(conn = con, statement = "PRAGMA foreign_key_check") |>
  base::nrow()

n_sample_taxa_no_taxon <-
  DBI::dbGetQuery(
    conn = con,
    statement = "SELECT COUNT(*) AS n FROM SampleTaxa WHERE taxon_id IS NULL"
  ) |>
  dplyr::pull(n)

DBI::dbDisconnect(con)

base::unlink(path_database)

base::print(data_expected)

base::print(
  dplyr::select(
    data_unit_checks,
    contract_id, variable, is_unit_equal, is_detail_equal
  ),
  n = 20
)

cli::cli_inform(
  c(
    "Foreign-key violations: {n_fk_violations}.",
    "SampleTaxa rows without a taxon: {n_sample_taxa_no_taxon}.",
    "Soil unit found in 09: {flag_soil_unit}."
  )
)

flag_counts_ok <-
  base::all(
    dplyr::pull(data_expected, n_expected) ==
      dplyr::pull(data_expected, n_observed)
  )

flag_units_ok <-
  base::all(dplyr::pull(data_unit_checks, is_unit_equal) %in% TRUE) &&
  base::all(dplyr::pull(data_unit_checks, is_detail_equal) %in% TRUE)

if (
  !flag_counts_ok ||
    n_fk_violations > 0L ||
    n_sample_taxa_no_taxon > 0L ||
    !flag_units_ok ||
    !flag_soil_unit
) {
  cli::cli_abort("Contract fixture smoke test failed.")
}

cli::cli_alert_success("Contract fixture smoke test passed.")
