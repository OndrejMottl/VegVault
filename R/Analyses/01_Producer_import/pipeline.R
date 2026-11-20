#----------------------------------------------------------#
#
#
#                         VegVault
#
#                 Producer import pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the producer import stage: every producer
#   artefact pinned in `Data/Producers/producer_manifest.yml`, resolved in
#   the mode of `producers: mode` (local files of the sibling checkouts in
#   `dev`, tagged and checksum-verified files in `release`), validated
#   against its contract in `Data/Contracts/`, and cut to the subset box in
#   the `subset` profile. Nothing is written to SQLite in this stage.
# Run with:
#   R/Analyses/01_Producer_import/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

# The artefacts add up to several gigabytes: each data target is kept in
#   memory only while a target needs it
targets::tar_option_set(
  seed = config_seed,
  memory = "transient",
  garbage_collection = TRUE
)


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# None: this is the first stage. Its inputs are the producer artefacts
#   pinned in the manifest, found in the sibling producer checkouts (`dev`)
#   or fetched at their release tags (`release`).


#----------------------------------------------------------#
# 2. Public targets -----
#----------------------------------------------------------#

# Proposed for the gridpoint and database assembly stages; the names are
#   agreed with the database-core lane before those stages import them.
#   - `data_<artefact id>` for splot_plots, bien_plots, fossilpol_assembly,
#     fossilpol_age_uncertainty, try_traits, bien_traits and wosis_soil:
#     the validated artefact as a named list of tables, one per file
#   - `data_chelsa_neoclimate_<variable>` and
#     `data_chelsa_trace21k_palaeoclimate_<variable>` for bio1, bio4,
#     bio6, bio12, bio15, bio18 and bio19: the same, per variable
#   - `data_chelsa_trace21k_coordinates`, `vec_chelsa_trace21k_ages` and
#     `data_chelsa_neoclimate_coordinates`: the grid of the gridpoints
#   - `check_fossilpol_relations`: the relations between the FOSSILPOL
#     artefacts hold
#   - `list_producer_pins`: the pins for save_build_manifest()
#   - `profile_build`: the profile of the latest run
# In the `subset` profile every data target holds only the subset box.
# validate_target_store_contract() refuses this store after a run that
#   failed, was interrupted or did not reach the imported targets. One
#   store serves every profile, so stage 03 compares `profile_build` with
#   its own profile.


#----------------------------------------------------------#
# 3. Define targets -----
#----------------------------------------------------------#

list(
  # Subset section of the active profile, checked with the profile below
  targets::tar_target(
    name = "list_subset",
    command = load_config_value(value = "subset"),
    cue = targets::tar_cue(mode = "always")
  ),
  # Only the box every data target is cut to (or `enabled: false`), so a
  #   new name or database file of the subset rebuilds no data
  targets::tar_target(
    name = "list_subset_box",
    command = purrr::keep_at(
      list_subset,
      c(
        "enabled", "lon_min", "lon_max", "lat_min", "lat_max", "margin_lon",
        "margin_lat"
      )
    )
  ),
  # Build profile, checked against the subset and, for a release, against
  #   a clean checkout, so nothing is resolved under a wrong profile
  targets::tar_target(
    name = "profile_build",
    command = validate_build_profile(
      profile = load_config_value(value = "profile"),
      list_subset = list_subset,
      flag_git_clean = is_git_clean()
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # How artefacts are found: local files (`dev`) or tagged files
  #   (`release`, required by the release profile)
  targets::tar_target(
    name = "mode_producers",
    command = resolve_producer_mode(
      profile = profile_build,
      mode = load_config_value(value = c("producers", "mode"))
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Folder of the sibling producer checkouts, read in the `dev` mode;
  #   normalised, so a build from another checkout of the same folder
  #   finds the same file paths and rebuilds nothing
  targets::tar_target(
    name = "dir_producer_dev_root",
    command = base::normalizePath(
      here::here(load_config_value(value = c("producers", "dev_root"))),
      winslash = "/",
      mustWork = FALSE
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Download cache of the release files, under the data root
  targets::tar_target(
    name = "dir_producer_cache",
    command = base::file.path(
      path_data_storage,
      load_config_value(value = c("producers", "cache_dir"))
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Where a release file is fetched from
  targets::tar_target(
    name = "url_template_release",
    command = load_config_value(value = c("producers", "release_url_template")),
    cue = targets::tar_cue(mode = "always")
  ),
  # The pin manifest and the contracts, tracked as files so that an edit
  #   of either loads the manifest again
  targets::tar_target(
    name = "file_producer_manifest",
    command = here::here(load_config_value(value = c("producers", "manifest"))),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_producer_contracts",
    command = base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$",
      full.names = TRUE
    ),
    format = "file",
    cue = targets::tar_cue(mode = "always")
  ),
  # The manifest, checked against its format and every contract
  targets::tar_target(
    name = "data_producer_manifest",
    command = load_producer_manifest(
      path_manifest = file_producer_manifest,
      dir_contracts = base::unique(base::dirname(file_producer_contracts))
    )
  ),
  # Per artefact: its contract, its resolved files and its validated data;
  #   then the FOSSILPOL relations, the grid of the gridpoints and the
  #   producer pins (see build_producer_import_targets())
  build_producer_import_targets(
    list_subset_filters = load_config_value(
      value = c("producers", "subset_filter")
    )
  )
)
