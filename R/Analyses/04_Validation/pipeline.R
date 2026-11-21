#----------------------------------------------------------#
#
#
#                         VegVault
#
#                   Validation pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the validation stage: the release checks of
#   the built database, read-only, and the validation report in
#   `validation: output_dir`. A failed check stops the stage after the
#   report is written; a flagged result is listed for review.
# The schema enforces keys, NOT NULL, UNIQUE and the documented ranges
#   (Documentation/Database_design_2.0.0.md, section 7); this stage
#   confirms that the schema is in place, runs integrity_check and
#   foreign_key_check once, and checks what no constraint can express.
# Run with:
#   R/Analyses/04_Validation/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

targets::tar_option_set(
  seed = config_seed
)


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# No store is imported. The upstream contract is the database and its
#   build manifest, which the last target of the database assembly
#   (R/Analyses/03_Database_assembly/00_run.R) writes next to the database.
#   Every check opens the database read-only and takes the manifest as an
#   argument, so the checks run again when a new build writes a new
#   manifest, and the database itself is never hashed.


#----------------------------------------------------------#
# 2. Define targets -----
#----------------------------------------------------------#

list(
  # Database to check: from `secrets.yaml`, or the disposable database of
  #   the `subset` profile. Resolved on every run, so a new path is noticed
  targets::tar_target(
    name = "path_database",
    command = resolve_database_path(),
    cue = targets::tar_cue(mode = "always")
  ),
  # Active profile, which the build manifest must record
  targets::tar_target(
    name = "profile_active",
    command = load_config_value(value = "profile"),
    cue = targets::tar_cue(mode = "always")
  ),
  # Folder that receives the report
  targets::tar_target(
    name = "dir_validation",
    command = resolve_output_dir(
      path_relative = load_config_value(value = c("validation", "output_dir")),
      section_name = "validation"
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Whether the shorter quick_check replaces integrity_check (development
  #   only; such a build is not eligible for release)
  targets::tar_target(
    name = "flag_quick_check",
    command = load_config_value(value = c("validation", "quick_check")),
    cue = targets::tar_cue(mode = "always")
  ),
  # Version being built: the last entry of `database: versions`
  targets::tar_target(
    name = "list_version_config",
    command = load_config_value(value = c("database", "versions")) |>
      purrr::pluck(-1),
    cue = targets::tar_cue(mode = "always")
  ),
  # The schema file and the pin manifest, tracked as files so that an edit
  #   of either runs the checks that read them again
  targets::tar_target(
    name = "file_database_schema",
    command = here::here("Data", "SQL", "make_tables.sql"),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_producer_manifest",
    command = here::here(load_config_value(value = c("producers", "manifest"))),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  # The contracts of the climate and soil artefacts, which give the
  #   variable labels, plausible ranges and forbidden values
  targets::tar_target(
    name = "file_contract_neoclimate",
    command = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_contract_palaeoclimate",
    command = here::here(
      "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
    ),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_contract_soil",
    command = here::here("Data", "Contracts", "hwsd_soil.yml"),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  # Storage caps, zero-share thresholds and their exceptions
  targets::tar_target(
    name = "list_abiotic_config",
    command = load_config_value(value = c("validation", "abiotic_values")),
    cue = targets::tar_cue(mode = "always")
  ),
  # Build manifest next to the database
  targets::tar_target(
    name = "path_build_manifest",
    command = resolve_build_manifest_path(path_database = path_database)
  ),
  # Manifest content, read on every run and checked against the database
  #   file and the active profile
  targets::tar_target(
    name = "list_build_manifest",
    command = load_build_manifest(
      path_manifest = path_build_manifest,
      path_database = path_database,
      profile_expected = profile_active
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Every table, view and index of the schema file, with its definition
  targets::tar_target(
    name = "data_check_schema",
    command = diagnose_database_schema(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      path_schema = file_database_schema
    )
  ),
  # The file structure, every index against its table, and the UNIQUE,
  #   CHECK and NOT NULL constraints on every row
  targets::tar_target(
    name = "data_check_integrity",
    command = diagnose_database_integrity(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      flag_quick_check = flag_quick_check
    )
  ),
  # Every declared foreign key, which the bulk load does not enforce
  targets::tar_target(
    name = "data_check_foreign_keys",
    command = diagnose_foreign_keys(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # The version row against config.yml, the manifest and the pin manifest
  targets::tar_target(
    name = "data_check_version_row",
    command = diagnose_version_row(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      list_version = list_version_config,
      path_producer_manifest = file_producer_manifest
    )
  ),
  # The BuildProducers rows against the producer pins of the manifest
  targets::tar_target(
    name = "data_check_build_producers",
    command = diagnose_build_producers(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # Repeated (sample, taxon) pairs, flagged until the vegetation producers
  #   resolve them; SampleTaxa has no key yet
  targets::tar_target(
    name = "data_check_sample_taxa_pairs",
    command = diagnose_sample_taxa_pairs(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # Repeated or missing names in the name columns the schema does not keep
  #   unique
  targets::tar_target(
    name = "data_check_names",
    command = diagnose_duplicate_names(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # Rows left without the rows that give them meaning, and links to the
  #   wrong kind of sample
  targets::tar_target(
    name = "data_check_orphans",
    command = diagnose_orphan_rows(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # Datasets without coordinates, which get no climate link
  targets::tar_target(
    name = "data_check_missing_coordinates",
    command = diagnose_missing_coordinates(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # One value rule per artefact and variable, from the contracts: age 0
  #   from the present day, older time steps from CHELSA-TraCE21k
  targets::tar_target(
    name = "data_abiotic_rules",
    command = build_abiotic_value_rules(
      path_contract_present = file_contract_neoclimate,
      path_contract_past = file_contract_palaeoclimate,
      path_contract_soil = file_contract_soil
    )
  ),
  # The ages at which gridpoints exist
  targets::tar_target(
    name = "vec_gridpoint_ages",
    command = build_gridpoint_ages(path_contract = file_contract_palaeoclimate)
  ),
  # Units and descriptions of the abiotic variables against the contracts
  targets::tar_target(
    name = "data_check_abiotic_variables",
    command = diagnose_abiotic_variables(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      data_rules = data_abiotic_rules
    )
  ),
  # Abiotic values outside their range or equal to a forbidden value fail;
  #   values at a storage cap are flagged
  targets::tar_target(
    name = "data_check_abiotic_values",
    command = diagnose_abiotic_values(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      data_rules = data_abiotic_rules,
      list_capped_values = purrr::pluck(
        list_abiotic_config, "capped_values",
        .default = base::list()
      )
    )
  ),
  # Shares of zeros per variable, age and latitude band, flagged for review
  targets::tar_target(
    name = "data_check_abiotic_zero_shares",
    command = diagnose_abiotic_zero_shares(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      data_rules = data_abiotic_rules,
      list_thresholds = purrr::chuck(list_abiotic_config, "zero_share"),
      list_exceptions = purrr::pluck(
        list_abiotic_config, "zero_share_exceptions",
        .default = base::list()
      ),
      min_values_per_band = purrr::chuck(
        list_abiotic_config, "min_values_per_band"
      )
    )
  ),
  # Missing ages, ages after the build and gridpoint ages off the time
  #   steps, flagged for review
  targets::tar_target(
    name = "data_check_sample_ages",
    command = diagnose_sample_ages(
      path_database = path_database,
      list_build_manifest = list_build_manifest,
      vec_gridpoint_ages = vec_gridpoint_ages
    )
  ),
  targets::tar_target(
    name = "data_checks_database",
    command = dplyr::bind_rows(
      data_check_schema,
      data_check_integrity,
      data_check_foreign_keys,
      data_check_version_row,
      data_check_build_producers,
      data_check_sample_taxa_pairs,
      data_check_names,
      data_check_orphans,
      data_check_missing_coordinates,
      data_check_abiotic_variables,
      data_check_abiotic_values,
      data_check_abiotic_zero_shares,
      data_check_sample_ages
    )
  ),
  # Release eligibility: the release profile, a clean checkout, no failed
  #   check and the full integrity_check
  targets::tar_target(
    name = "data_check_release",
    command = diagnose_release_eligibility(
      list_build_manifest = list_build_manifest,
      data_checks = data_checks_database
    )
  ),
  targets::tar_target(
    name = "data_checks",
    command = dplyr::bind_rows(data_checks_database, data_check_release)
  ),
  # The report: one row per check and scope, and a summary for review
  targets::tar_target(
    name = "file_validation_report",
    command = save_validation_report(
      data_checks = data_checks,
      list_build_manifest = list_build_manifest,
      dir_output = dir_validation
    ),
    format = "file"
  ),
  # Stops the stage when a check failed, after the report is written
  targets::tar_target(
    name = "check_validation",
    command = validate_database_checks(
      data_checks = data_checks,
      vec_paths_report = file_validation_report
    )
  )
)
