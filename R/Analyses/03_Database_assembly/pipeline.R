#----------------------------------------------------------#
#
#
#                         VegVault
#
#                Database assembly pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the database assembly stage: the tables of
#   every source prepared from the validated producer artefacts, the
#   positions, links and gridpoints of the gridpoint stage, the climate and
#   soil values, the taxon classification in cached batches (it needs
#   internet), the rows of every table with their ids, one bulk write of a
#   new SQLite file, and the build manifest next to it.
# Run with:
#   R/Analyses/03_Database_assembly/00_run.R
# Sourcing this script only declares targets; it does not execute them.
#   Running it writes the database at `resolve_database_path()`: in the
#   `subset` profile the disposable database under the data root, which it
#   replaces; otherwise the path of `secrets.yaml`, and an existing file
#   there stops the write (move it by hand first). A run always writes a
#   new file and never resumes a failed write; the table targets are
#   cached, so after a failure only the write runs again.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

# The tables of the full build hold tens of millions of rows: each large
#   target is kept in memory only while a target needs it
targets::tar_option_set(
  seed = config_seed,
  memory = "transient",
  garbage_collection = TRUE
)


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# Public targets of the producer import stage, agreed with the VegVault
#   pipeline lane: data_splot_plots, data_bien_plots,
#   data_fossilpol_assembly, data_fossilpol_age_uncertainty,
#   data_try_traits, data_bien_traits, data_hwsd_soil,
#   data_chelsa_neoclimate_<variable> and
#   data_chelsa_trace21k_palaeoclimate_<variable> for the variables of the
#   climate contracts, check_fossilpol_relations, list_producer_pins,
#   data_trait_unit_rules and profile_build.
# Public targets of the gridpoint stage: data_positions,
#   data_position_links, data_gridpoints and profile_build.
# The imports, one fingerprint per store and the profile checks are
#   declared by build_database_assembly_targets().
store_producer_import <-
  resolve_pipeline_store_path(
    path_data_storage = path_data_storage,
    store_relative_path = "producer_import"
  )

runner_producer_import <- "R/Analyses/01_Producer_import/00_run.R"

store_gridpoints <-
  resolve_pipeline_store_path(
    path_data_storage = path_data_storage,
    store_relative_path = "gridpoints"
  )

runner_gridpoints <- "R/Analyses/02_Gridpoints/00_run.R"


#----------------------------------------------------------#
# 2. Public targets -----
#----------------------------------------------------------#

# For the validation, export and figure stages: `file_build_manifest`,
#   the build manifest next to the database. These stages do not import
#   it from this store; they resolve it next to the database with
#   resolve_build_manifest_path() and read it with load_build_manifest().
# `list_database_load` holds the steps, timings and row counts of the
#   write, for the build-time records.


#----------------------------------------------------------#
# 3. Define targets -----
#----------------------------------------------------------#

list(
  #--------------------------------------------------#
  ## 3.1. Machine and checkout -----
  #--------------------------------------------------#

  # Subset section of the active profile, checked with the profile below
  targets::tar_target(
    name = "list_subset",
    command = load_config_value(value = "subset"),
    cue = targets::tar_cue(mode = "always")
  ),
  # Whether the checkout has no uncommitted or untracked files
  targets::tar_target(
    name = "flag_git_clean",
    command = is_git_clean(),
    cue = targets::tar_cue(mode = "always")
  ),
  # Commit of the code that builds the database, recorded in the version
  #   row and the manifest
  targets::tar_target(
    name = "git_commit",
    command = load_git_commit(),
    cue = targets::tar_cue(mode = "always")
  ),
  # Build profile, checked against the subset and, for a release, against
  #   a clean checkout, so nothing is built under a wrong profile
  targets::tar_target(
    name = "profile_active",
    command = validate_build_profile(
      profile = load_config_value(value = "profile"),
      list_subset = list_subset,
      flag_git_clean = flag_git_clean
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Database to write: from `secrets.yaml`, or the disposable database of
  #   the `subset` profile. Resolved on every run, so a new path is noticed
  targets::tar_target(
    name = "path_database",
    command = resolve_database_path(),
    cue = targets::tar_cue(mode = "always")
  ),

  #--------------------------------------------------#
  ## 3.2. Imports, tables, classification, write -----
  #--------------------------------------------------#

  build_database_assembly_targets(
    store_producer_import = store_producer_import,
    runner_producer_import = runner_producer_import,
    store_gridpoints = store_gridpoints,
    runner_gridpoints = runner_gridpoints
  )
)
