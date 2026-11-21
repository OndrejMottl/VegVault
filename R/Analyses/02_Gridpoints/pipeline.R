#----------------------------------------------------------#
#
#
#                         VegVault
#
#                   Gridpoints pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the gridpoints stage: the positions of the
#   samples (longitude, latitude and age), the gridpoint cells of the
#   climate grid, and the links between positions and gridpoints under the
#   v1.0.0 rule (at most 50 km and at most 5000 years, see the `link`
#   section of `config.yml`). The links are computed once per position, in
#   branches of `link: chunk_size` positions. Nothing is written to SQLite
#   in this stage; the database assembly stage writes its public targets.
# Run with:
#   R/Analyses/02_Gridpoints/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

# The link table holds tens of millions of rows: each large target is kept
#   in memory only while a target needs it
targets::tar_option_set(
  seed = config_seed,
  memory = "transient",
  garbage_collection = TRUE
)


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# Public targets of the producer import stage, agreed with the VegVault
#   pipeline lane. Only coordinates and ages are read from the artefacts:
#   each import target keeps the positions or the grid, not the artefact.
vec_public_targets_producer_import <-
  c(
    "data_chelsa_trace21k_coordinates",
    "data_chelsa_neoclimate_coordinates",
    "vec_chelsa_trace21k_ages",
    "data_splot_plots",
    "data_bien_plots",
    "data_fossilpol_assembly",
    "data_try_traits",
    "data_bien_traits",
    "profile_build"
  )

store_producer_import <-
  resolve_pipeline_store_path(
    path_data_storage = path_data_storage,
    store_relative_path = "producer_import"
  )

runner_producer_import <- "R/Analyses/01_Producer_import/00_run.R"


#----------------------------------------------------------#
# 2. Public targets -----
#----------------------------------------------------------#

# For the database assembly stage:
#   - `data_positions`: one row per distinct position of the samples that
#     are not gridpoints (`position_id`, `coord_long`, `coord_lat`, `age`);
#     the assembly joins its samples to them by the three values
#   - `data_position_links`: one row per link (`position_id`,
#     `gridpoint_id`, `distance_in_km`, `distance_in_years`), the rows of
#     the `PositionLink` table once gridpoint ids become sample ids
#   - `data_gridpoints`: one row per linked gridpoint (`gridpoint_id`,
#     `coord_long`, `coord_lat`, `age`, `dataset_name`, `sample_name`)
#   - `profile_build`: the profile of the producer import run the links
#     were computed from, to be compared with the active profile
# The ids are deterministic: they follow from sorting the positions and
#   the gridpoints by longitude, latitude and age, never from a database.


#----------------------------------------------------------#
# 3. Define targets -----
#----------------------------------------------------------#

list(
  #--------------------------------------------------#
  ## 3.1. Settings -----
  #--------------------------------------------------#

  # One link setting per target, so a changed value reruns only the
  #   targets that use it
  targets::tar_target(
    name = "value_link_distance_km",
    command = load_config_value(value = c("link", "distance_km")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "value_link_distance_years",
    command = load_config_value(value = c("link", "distance_years")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "n_link_coordinate_digits",
    command = load_config_value(value = c("link", "coordinate_digits")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "value_link_radius_min_km",
    command = load_config_value(value = c("link", "radius_min_km")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "value_link_window_margin_deg",
    command = load_config_value(value = c("link", "window_margin_deg")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "value_link_age_margin_years",
    command = load_config_value(value = c("link", "age_margin_years")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "n_link_chunk_size",
    command = load_config_value(value = c("link", "chunk_size")),
    cue = targets::tar_cue(mode = "always")
  ),

  #--------------------------------------------------#
  ## 3.2. Imports from the producer import stage -----
  #--------------------------------------------------#

  # Fingerprint of the imported public targets: a change upstream
  #   invalidates the imports below; the check itself reads metadata only
  targets::tar_target(
    name = "fingerprint_producer_import",
    command = compute_target_store_fingerprint(
      store = store_producer_import,
      target_names = vec_public_targets_producer_import,
      runner = runner_producer_import
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Profile of the producer import run, passed on for the assembly stage
  targets::tar_target(
    name = "profile_build",
    command = {
      fingerprint_producer_import

      load_target_store_value(
        store = store_producer_import,
        target_name = "profile_build",
        runner = runner_producer_import
      )
    }
  ),
  # The climate grid: coordinates of both CHELSA artefacts and the ages of
  #   the palaeoclimate time slices (the soil grid is not used, as in
  #   v1.0.0)
  targets::tar_target(
    name = "data_chelsa_trace21k_coordinates",
    command = {
      fingerprint_producer_import

      load_target_store_value(
        store = store_producer_import,
        target_name = "data_chelsa_trace21k_coordinates",
        runner = runner_producer_import
      )
    }
  ),
  targets::tar_target(
    name = "data_chelsa_neoclimate_coordinates",
    command = {
      fingerprint_producer_import

      load_target_store_value(
        store = store_producer_import,
        target_name = "data_chelsa_neoclimate_coordinates",
        runner = runner_producer_import
      )
    }
  ),
  targets::tar_target(
    name = "vec_chelsa_trace21k_ages",
    command = {
      fingerprint_producer_import

      load_target_store_value(
        store = store_producer_import,
        target_name = "vec_chelsa_trace21k_ages",
        runner = runner_producer_import
      )
    }
  ),
  # Positions of every sample source; plots and trait records have age 0
  targets::tar_target(
    name = "data_positions_splot_plots",
    command = {
      fingerprint_producer_import

      prepare_modern_positions(
        list_data = load_target_store_value(
          store = store_producer_import,
          target_name = "data_splot_plots",
          runner = runner_producer_import
        )
      )
    }
  ),
  targets::tar_target(
    name = "data_positions_bien_plots",
    command = {
      fingerprint_producer_import

      prepare_modern_positions(
        list_data = load_target_store_value(
          store = store_producer_import,
          target_name = "data_bien_plots",
          runner = runner_producer_import
        )
      )
    }
  ),
  targets::tar_target(
    name = "data_positions_fossilpol_assembly",
    command = {
      fingerprint_producer_import

      prepare_fossilpol_positions(
        list_data = load_target_store_value(
          store = store_producer_import,
          target_name = "data_fossilpol_assembly",
          runner = runner_producer_import
        )
      )
    }
  ),
  targets::tar_target(
    name = "data_positions_try_traits",
    command = {
      fingerprint_producer_import

      prepare_modern_positions(
        list_data = load_target_store_value(
          store = store_producer_import,
          target_name = "data_try_traits",
          runner = runner_producer_import
        )
      )
    }
  ),
  targets::tar_target(
    name = "data_positions_bien_traits",
    command = {
      fingerprint_producer_import

      prepare_modern_positions(
        list_data = load_target_store_value(
          store = store_producer_import,
          target_name = "data_bien_traits",
          runner = runner_producer_import
        )
      )
    }
  ),

  #--------------------------------------------------#
  ## 3.3. Positions and gridpoint cells -----
  #--------------------------------------------------#

  # Distinct positions of all samples that are not gridpoints, numbered
  #   by longitude, latitude and age
  targets::tar_target(
    name = "data_positions",
    command = prepare_link_positions(
      list_positions = list(
        splot_plots = data_positions_splot_plots,
        bien_plots = data_positions_bien_plots,
        fossilpol_assembly = data_positions_fossilpol_assembly,
        try_traits = data_positions_try_traits,
        bien_traits = data_positions_bien_traits
      )
    ),
    format = "qs"
  ),
  # Cells of the gridpoints: both CHELSA grids, rounded and numbered
  targets::tar_target(
    name = "data_gridpoint_cells",
    command = prepare_gridpoint_cells(
      list_coordinates = list(
        data_chelsa_trace21k_coordinates,
        data_chelsa_neoclimate_coordinates
      ),
      n_digits = n_link_coordinate_digits
    ),
    format = "qs"
  ),

  #--------------------------------------------------#
  ## 3.4. Links -----
  #--------------------------------------------------#

  # Search windows of the positions, one list element per chunk, so that
  #   each chunk is one branch of the links below
  targets::tar_target(
    name = "list_link_windows",
    command = build_link_windows(
      data_positions = data_positions,
      distance_km = value_link_distance_km,
      radius_min_km = value_link_radius_min_km,
      margin_deg = value_link_window_margin_deg,
      n_chunk_size = n_link_chunk_size
    ),
    iteration = "list",
    format = "qs"
  ),
  # Links of each chunk under the v1.0.0 rule; read as one table, the
  #   branches give the links of all positions
  targets::tar_target(
    name = "data_position_links",
    command = compute_position_links(
      data_windows = list_link_windows,
      data_cells = data_gridpoint_cells,
      vec_ages = vec_chelsa_trace21k_ages,
      distance_km = value_link_distance_km,
      distance_years = value_link_distance_years,
      age_margin_years = value_link_age_margin_years
    ),
    pattern = map(list_link_windows),
    format = "qs"
  ),
  # Gridpoints with at least one link, with their v1.0.0 names
  targets::tar_target(
    name = "data_gridpoints",
    command = prepare_linked_gridpoints(
      data_position_links = data_position_links,
      data_cells = data_gridpoint_cells,
      vec_ages = vec_chelsa_trace21k_ages
    ),
    format = "qs"
  )
)
