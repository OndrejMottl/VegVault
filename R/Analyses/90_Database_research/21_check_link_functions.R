#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Check the link functions of the gridpoint stage
#             - full size, against the research links
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Run the functions of the gridpoint stage (R/Functions/Gridpoints/) on all
#   positions of the v1.0.0 database, with the settings of the `link`
#   section of config.yml, and compare every result with the links of the
#   full-size research run (20_run_full_size_links.R, target `v1`):
#   - the positions, the linked gridpoints and every link must be the
#     same, with the same km and years;
#   - v1.0.0 holds positions with impossible coordinates (outside -180 to
#     180 or -90 to 90), which prepare_link_positions() refuses and the
#     2.0.0 producer contracts reject; they are left out of the check,
#     with their research links, and listed in positions_impossible.csv;
#   - that research run compared its links with the v1.0.0 links of a
#     random draw of positions and of draws near the dateline and the poles
#     (every v1.0.0 link found, every new link explained), so equal links
#     carry that result over to the new functions.
# The script also times each step and records the peak memory, as the
#   full-size benchmark of the link computation.
# Inputs, opened read-only: the links.sqlite of the research run (not
#   v1.0.0 itself) and the global grid of the research inputs. Its size,
#   modification time and header are compared before and after. Each call
#   writes a new folder under `Data/Temp/Database_research/Link_functions`
#   and overwrites nothing; a failed call is restarted in a new folder.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/21_check_link_functions.R
#     <v1 run folder of 20_run_full_size_links.R>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 1L,
  stringr::str_detect(vec_args, "^run_[0-9_]+_v1$"),
  msg = "Give the v1 run folder of 20_run_full_size_links.R."
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_engines <-
  purrr::chuck(list_settings, "engines")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_source_run <-
  base::file.path(path_research, "Full_links", vec_args)

path_source <-
  base::file.path(path_source_run, "links.sqlite")

path_cells <-
  here::here(purrr::chuck(list_settings_engines, "cells_file"))

path_ages <-
  here::here(purrr::chuck(list_settings_engines, "ages_file"))

assertthat::assert_that(
  base::file.exists(path_source),
  base::file.exists(path_cells),
  base::file.exists(path_ages),
  msg = "An input file is missing."
)

# The settings of the gridpoint stage
list_link <-
  load_config_value(value = "link")

time_run_start <-
  base::Sys.time()

path_out <-
  base::file.path(
    path_research,
    "Link_functions",
    stringr::str_c(
      "run_",
      base::format(time_run_start, "%Y%m%d_%H%M%S")
    )
  )

assertthat::assert_that(
  !base::dir.exists(path_out),
  msg = "The run folder exists already."
)

base::dir.create(path = path_out, recursive = TRUE)

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

size_bytes_before <-
  base::file.size(path_source)

mtime_before <-
  base::file.mtime(path_source)

vec_header_raw_before <-
  base::readBin(con = path_source, what = "raw", n = 100L)

data_step_log <-
  tibble::tibble(
    step = base::character(),
    seconds = base::numeric(),
    n_rows = base::numeric()
  )

time_step_start <-
  base::Sys.time()


#----------------------------------------------------------#
# 1. Read the research links -----
#----------------------------------------------------------#

con_source <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_source,
    flags = RSQLite::SQLITE_RO
  )

data_positions_research_all <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT p.position_id, p.coord_long, p.coord_lat, p.age, ",
      "COALESCE(s.n_samples, 0) AS n_samples ",
      "FROM Positions AS p LEFT JOIN (SELECT position_id, ",
      "COUNT(*) AS n_samples FROM SamplePosition GROUP BY position_id) ",
      "AS s ON s.position_id = p.position_id"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(
    position_id = base::as.integer(position_id),
    dplyr::across(
      .cols = c(coord_long, coord_lat, age),
      .fns = base::as.double
    ),
    flag_possible = coord_long >= -180 & coord_long <= 180 &
      coord_lat >= -90 & coord_lat <= 90
  ) |>
  dplyr::arrange(position_id)

data_positions_impossible <-
  data_positions_research_all |>
  dplyr::filter(!flag_possible) |>
  dplyr::select(-flag_possible)

# The possible positions, renumbered by the same sort as
#   prepare_link_positions(); research ids are kept for the comparison
data_positions_research <-
  data_positions_research_all |>
  dplyr::filter(flag_possible) |>
  dplyr::arrange(coord_long, coord_lat, age) |>
  dplyr::mutate(
    position_id_research = position_id,
    position_id = dplyr::row_number()
  ) |>
  dplyr::select(
    position_id, coord_long, coord_lat, age, position_id_research
  )

data_gridpoints_research <-
  DBI::dbGetQuery(
    con_source,
    "SELECT gridpoint_id, coord_long, coord_lat, age FROM Gridpoints"
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(
    gridpoint_id = base::as.integer(gridpoint_id),
    dplyr::across(
      .cols = c(coord_long, coord_lat, age),
      .fns = base::as.double
    )
  )

data_links_research <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT position_id, gridpoint_id, distance_in_km, ",
      "distance_in_years FROM PositionLink"
    )
  ) |>
  tibble::as_tibble()

DBI::dbDisconnect(con_source)

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "read_research_links",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_links_research)
    )
  )


#----------------------------------------------------------#
# 2. Run the functions of the gridpoint stage -----
#----------------------------------------------------------#

# As the targets of R/Analyses/02_Gridpoints/pipeline.R, without the
#   imports: the positions are those the research read from v1.0.0, and
#   the grid is the global grid of the research inputs

time_step_start <-
  base::Sys.time()

data_positions <-
  prepare_link_positions(
    list_positions = list(
      v1_positions = dplyr::select(
        data_positions_research,
        coord_long, coord_lat, age
      )
    )
  )

data_gridpoint_cells <-
  prepare_gridpoint_cells(
    list_coordinates = list(base::readRDS(path_cells)),
    n_digits = purrr::chuck(list_link, "coordinate_digits")
  )

vec_gridpoint_ages <-
  base::readRDS(path_ages)

list_link_windows <-
  build_link_windows(
    data_positions = data_positions,
    distance_km = purrr::chuck(list_link, "distance_km"),
    radius_min_km = purrr::chuck(list_link, "radius_min_km"),
    margin_deg = purrr::chuck(list_link, "window_margin_deg"),
    n_chunk_size = purrr::chuck(list_link, "chunk_size")
  )

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "positions_cells_windows",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_positions)
    )
  )

time_step_start <-
  base::Sys.time()

cli::cli_inform(
  "Computing links for {base::nrow(data_positions)} positions in \\
  {base::length(list_link_windows)} chunks."
)

# One call per chunk, as the branches of `data_position_links`
data_position_links <-
  purrr::map(
    .x = list_link_windows,
    .f = ~ compute_position_links(
      data_windows = .x,
      data_cells = data_gridpoint_cells,
      vec_ages = vec_gridpoint_ages,
      distance_km = purrr::chuck(list_link, "distance_km"),
      distance_years = purrr::chuck(list_link, "distance_years"),
      age_margin_years = purrr::chuck(list_link, "age_margin_years")
    )
  ) |>
  purrr::list_rbind()

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "links",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_position_links)
    ),
    tibble::tibble(
      step = "bytes_links_in_r",
      seconds = NA_real_,
      n_rows = base::as.numeric(utils::object.size(data_position_links))
    )
  )

time_step_start <-
  base::Sys.time()

data_gridpoints <-
  prepare_linked_gridpoints(
    data_position_links = data_position_links,
    data_cells = data_gridpoint_cells,
    vec_ages = vec_gridpoint_ages
  )

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "gridpoints",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_gridpoints)
    )
  )


#----------------------------------------------------------#
# 3. Compare with the research links -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

# Both number the possible positions by sorting on longitude, latitude
#   and age
flag_positions_same <-
  base::identical(
    data_positions,
    dplyr::select(data_positions_research, -position_id_research)
  )

# Research position id -> new position id; impossible positions stay NA
vec_position_lookup <-
  base::replace(
    x = base::rep(
      NA_integer_,
      base::max(dplyr::pull(data_positions_research_all, position_id))
    ),
    list = dplyr::pull(data_positions_research, position_id_research),
    values = dplyr::pull(data_positions_research, position_id)
  )

# The research links of the possible positions only
data_links_research_possible <-
  data_links_research |>
  dplyr::mutate(
    position_id = vec_position_lookup[position_id]
  ) |>
  dplyr::filter(!base::is.na(position_id))

n_links_research_impossible <-
  base::nrow(data_links_research) -
  base::nrow(data_links_research_possible)

# Gridpoints by coordinates and age; the two numberings differ. Research
#   gridpoints linked only to impossible positions are left out.
vec_gridpoint_keys <-
  c("coord_long", "coord_lat", "age")

data_gridpoints_research_possible <-
  data_gridpoints_research |>
  dplyr::filter(
    gridpoint_id %in%
      base::unique(dplyr::pull(data_links_research_possible, gridpoint_id))
  )

data_gridpoint_map <-
  dplyr::full_join(
    dplyr::select(
      data_gridpoints_research_possible,
      gridpoint_id_research = gridpoint_id,
      dplyr::all_of(vec_gridpoint_keys)
    ),
    dplyr::select(
      data_gridpoints,
      gridpoint_id,
      dplyr::all_of(vec_gridpoint_keys)
    ),
    by = dplyr::join_by(coord_long, coord_lat, age),
    relationship = "one-to-one"
  )

data_gridpoint_map_matched <-
  data_gridpoint_map |>
  dplyr::filter(
    !base::is.na(gridpoint_id_research),
    !base::is.na(gridpoint_id)
  )

n_gridpoints_matched <-
  base::nrow(data_gridpoint_map_matched)

# Research gridpoint id -> new gridpoint id, as a lookup vector
vec_gridpoint_lookup <-
  base::replace(
    x = base::rep(
      NA_integer_,
      base::max(dplyr::pull(data_gridpoints_research, gridpoint_id))
    ),
    list = dplyr::pull(data_gridpoint_map_matched, gridpoint_id_research),
    values = dplyr::pull(data_gridpoint_map_matched, gridpoint_id)
  )

data_links_research_mapped <-
  data_links_research_possible |>
  dplyr::mutate(
    position_id = base::as.integer(position_id),
    gridpoint_id = vec_gridpoint_lookup[gridpoint_id],
    distance_in_km = base::as.integer(distance_in_km),
    distance_in_years = base::as.integer(distance_in_years)
  ) |>
  dplyr::arrange(position_id, gridpoint_id)

flag_links_same <-
  base::identical(data_position_links, data_links_research_mapped)

# Only when the tables differ: count links found by one side only, and
#   links found by both but with other km or years
data_link_differences <-
  if (
    base::isTRUE(flag_links_same)
  ) {
    tibble::tibble(
      n_research_only = 0,
      n_new_only = 0,
      n_other_km_or_years = 0
    )
  } else {
    n_gridpoints_all <-
      base::as.double(base::nrow(data_gridpoint_cells)) *
        base::length(vec_gridpoint_ages)

    vec_key_new <-
      base::as.double(dplyr::pull(data_position_links, position_id)) *
        n_gridpoints_all +
        dplyr::pull(data_position_links, gridpoint_id)

    vec_key_research <-
      base::as.double(dplyr::pull(data_links_research_mapped, position_id)) *
        n_gridpoints_all +
        dplyr::pull(data_links_research_mapped, gridpoint_id)

    vec_match <-
      base::match(vec_key_research, vec_key_new)

    tibble::tibble(
      n_research_only = base::sum(base::is.na(vec_match)),
      n_new_only = base::sum(!(vec_key_new %in% vec_key_research)),
      n_other_km_or_years = base::sum(
        !base::is.na(vec_match) &
          (
            dplyr::pull(data_links_research_mapped, distance_in_km) !=
              dplyr::pull(data_position_links, distance_in_km)[vec_match] |
              dplyr::pull(data_links_research_mapped, distance_in_years) !=
                dplyr::pull(data_position_links, distance_in_years)[vec_match]
          )
      )
    )
  }

data_comparison <-
  tibble::tibble(
    n_positions_research_all = base::nrow(data_positions_research_all),
    n_positions_impossible = base::nrow(data_positions_impossible),
    n_positions_research = base::nrow(data_positions_research),
    n_positions_new = base::nrow(data_positions),
    flag_positions_same = flag_positions_same,
    n_gridpoints_research_all = base::nrow(data_gridpoints_research),
    n_gridpoints_research = base::nrow(data_gridpoints_research_possible),
    n_gridpoints_new = base::nrow(data_gridpoints),
    n_gridpoints_matched = n_gridpoints_matched,
    n_links_research_all = base::nrow(data_links_research),
    n_links_research_impossible = n_links_research_impossible,
    n_links_research = base::nrow(data_links_research_possible),
    n_links_new = base::nrow(data_position_links),
    flag_links_same = flag_links_same
  ) |>
  dplyr::bind_cols(data_link_differences)

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "compare",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_links_research)
    )
  )


#----------------------------------------------------------#
# 4. Counts -----
#----------------------------------------------------------#

data_counts <-
  tibble::tibble(
    n_positions = base::nrow(data_positions),
    n_positions_without_links = base::nrow(data_positions) -
      dplyr::n_distinct(dplyr::pull(data_position_links, position_id)),
    n_links = base::nrow(data_position_links),
    n_gridpoints = base::nrow(data_gridpoints),
    n_gridpoint_datasets = dplyr::n_distinct(
      dplyr::pull(data_gridpoints, dataset_name)
    ),
    n_sample_names_distinct = dplyr::n_distinct(
      dplyr::pull(data_gridpoints, sample_name)
    ),
    n_cells = base::nrow(data_gridpoint_cells),
    n_ages = base::length(vec_gridpoint_ages),
    n_chunks = base::length(list_link_windows),
    chunk_size = purrr::chuck(list_link, "chunk_size")
  )

# The v1.0.0 comparison of the research run, carried over by equal links
data_v1_comparison <-
  readr::read_csv(
    file = base::file.path(path_source_run, "compare_with_v1_by_stratum.csv"),
    show_col_types = FALSE
  )

data_gridpoint_names_example <-
  data_gridpoints |>
  dplyr::slice(
    base::unique(
      base::round(
        base::seq(from = 1, to = base::nrow(data_gridpoints), length.out = 5)
      )
    )
  )


#----------------------------------------------------------#
# 5. Record the run -----
#----------------------------------------------------------#

list_memory <-
  ps::ps_memory_info(ps::ps_handle())

flag_source_unchanged <-
  base::isTRUE(
    base::file.size(path_source) == size_bytes_before &&
      base::file.mtime(path_source) == mtime_before &&
      base::identical(
        vec_header_raw_before,
        base::readBin(con = path_source, what = "raw", n = 100L)
      ) &&
      !base::any(
        base::file.exists(stringr::str_c(path_source, vec_sibling_suffix))
      )
  )

readr::write_csv(
  x = data_comparison,
  file = base::file.path(path_out, "comparison.csv")
)

readr::write_csv(
  x = data_counts,
  file = base::file.path(path_out, "counts.csv")
)

# With the number of research links of each impossible position
readr::write_csv(
  x = data_positions_impossible |>
    dplyr::left_join(
      data_links_research |>
        dplyr::count(position_id, name = "n_links_research"),
      by = dplyr::join_by(position_id)
    ) |>
    dplyr::mutate(
      n_links_research = dplyr::coalesce(n_links_research, 0L)
    ),
  file = base::file.path(path_out, "positions_impossible.csv")
)

readr::write_csv(
  x = data_step_log,
  file = base::file.path(path_out, "steps.csv")
)

readr::write_csv(
  x = data_v1_comparison,
  file = base::file.path(path_out, "v1_comparison_of_research_run.csv")
)

readr::write_csv(
  x = data_gridpoint_names_example,
  file = base::file.path(path_out, "gridpoint_names_example.csv")
)

readr::write_csv(
  x = tibble::tibble(
    script = "21_check_link_functions.R",
    source_run = vec_args,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::as.numeric(
      base::difftime(base::Sys.time(), time_run_start, units = "secs")
    ),
    peak_wset_mb = purrr::chuck(list_memory, "peak_wset") / 1e6,
    n_cores_used = 1L,
    git_commit = load_git_commit(),
    r_version = base::as.character(base::getRversion()),
    source_unchanged = flag_source_unchanged
  ),
  file = base::file.path(path_out, "run_info.csv")
)

if (
  base::isFALSE(flag_source_unchanged)
) {
  cli::cli_abort("The research links file differs after the read-only run.")
}

if (
  !base::isTRUE(flag_positions_same) ||
    !base::isTRUE(flag_links_same) ||
    n_gridpoints_matched !=
      base::nrow(data_gridpoints_research_possible) ||
    n_gridpoints_matched != base::nrow(data_gridpoints)
) {
  cli::cli_abort(
    c(
      "The link functions differ from the research links.",
      "i" = "See {.path {base::file.path(path_out, 'comparison.csv')}}."
    )
  )
}

cli::cli_inform(
  c(
    "v" = "The link functions give the research links exactly.",
    "i" = "Results in {.path {path_out}}."
  )
)
