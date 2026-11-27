#----------------------------------------------------------#
#
#
#                       VegVault
#
#      Check the links of the gridpoint stage against v1.0.0
#             - every position, read-only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Compare the links of the functions of the gridpoint stage
#   (R/Functions/Gridpoints/) with the links stored in a v1.0.0 database,
#   for every position:
#   1. Read the samples that are not gridpoints, with the coordinates of
#      their dataset and their age, and number their positions with
#      prepare_link_positions(). Positions with impossible coordinates
#      (outside -180 to 180 or -90 to 90) are refused by that function and
#      by the 2.0.0 producer contracts; they are left out and listed.
#   2. Compute the links with the settings of the `link` section of
#      config.yml and the global grid of the research inputs.
#   3. Read the v1.0.0 links of one sample per position, its lowest sample
#      id, and match them by position and by gridpoint coordinates and age:
#      every v1.0.0 link must be found, with the same km and years, and
#      every new link must be explained by the two known gaps of the v1.0.0
#      search, a longitude difference above its 1-degree window (high
#      latitudes) or a position across the dateline from the gridpoint.
#   4. Check that every other sample of a position has as many v1.0.0 links
#      as the sample that stands for it, so that the links of one sample
#      stand for the links of all (one grouped count over the link table).
# The source database is opened read-only and only temporary tables are
#   written to the connection. For `v1`, its path comes from the secrets
#   file and is never printed; for `subset`, it is the research extract of
#   the Alaska-Yukon box (04_extract_v1_subset.R). Size, modification time
#   and header are compared before and after, and no journal, WAL or SHM
#   file may appear. Each call writes a new folder under
#   `Data/Temp/Database_research/Links_against_v1` and overwrites nothing;
#   a failed call is restarted in a new folder.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/22_check_links_against_v1.R
#     subset
#   Rscript R/Analyses/90_Database_research/22_check_links_against_v1.R v1


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
  vec_args %in% c("subset", "v1"),
  msg = "Give the target: `subset` or `v1`."
)

name_target <- vec_args

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_engines <-
  purrr::chuck(list_settings, "engines")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_source <-
  if (
    name_target == "v1"
  ) {
    resolve_database_path(key = "database_v1_path")
  } else {
    base::file.path(
      path_research,
      "Subset",
      stringr::str_c(
        "v1_subset_",
        purrr::chuck(list_settings, "subset", "box_name"),
        ".sqlite"
      )
    )
  }

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

# The v1 fine window: +-1 degree of longitude (half the 2-degree grid)
value_v1_window_deg <-
  purrr::chuck(list_settings, "profiling", "grid_size_degree") / 2

time_run_start <-
  base::Sys.time()

path_out <-
  base::file.path(
    path_research,
    "Links_against_v1",
    stringr::str_c(
      "run_",
      base::format(time_run_start, "%Y%m%d_%H%M%S"),
      "_",
      name_target
    )
  )

assertthat::assert_that(
  !base::dir.exists(path_out),
  msg = "The run folder exists already."
)

base::dir.create(path = path_out, recursive = TRUE)

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

data_step_log <-
  tibble::tibble(
    step = base::character(),
    seconds = base::numeric(),
    n_rows = base::numeric()
  )


#----------------------------------------------------------#
# 1. Record the source state and open it read-only -----
#----------------------------------------------------------#

vec_header_raw_before <-
  base::readBin(con = path_source, what = "raw", n = 100L)

size_bytes_before <-
  base::file.size(path_source)

mtime_before <-
  base::file.mtime(path_source)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(
      base::file.exists(stringr::str_c(path_source, vec_sibling_suffix))
    )
) {
  cli::cli_abort(
    c(
      "The database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}

con_source <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_source,
    flags = RSQLite::SQLITE_RO
  )

time_step_start <-
  base::Sys.time()

cli::cli_inform("Reading the samples of the {name_target} database.")

sql_gridpoint_type <-
  stringr::str_c(
    "(SELECT dataset_type_id FROM DatasetTypeID ",
    "WHERE dataset_type = 'gridpoints')"
  )

data_samples <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT s.sample_id, d.coord_long, d.coord_lat, s.age ",
      "FROM Samples AS s ",
      "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
      "WHERE d.dataset_type_id != ", sql_gridpoint_type, " ",
      "AND d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL ",
      "AND s.age IS NOT NULL"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(
    sample_id = base::as.integer(sample_id),
    dplyr::across(
      .cols = c(coord_long, coord_lat, age),
      .fns = base::as.double
    )
  )

# The gridpoint samples of v1.0.0, with the coordinates of their dataset
data_gridpoints_v1 <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT s.sample_id, d.coord_long, d.coord_lat, s.age ",
      "FROM Samples AS s ",
      "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
      "WHERE d.dataset_type_id = ", sql_gridpoint_type
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(
    sample_id = base::as.integer(sample_id),
    dplyr::across(
      .cols = c(coord_long, coord_lat, age),
      .fns = base::as.double
    )
  )

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "read_samples",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_samples)
    )
  )


#----------------------------------------------------------#
# 2. Positions and links of the gridpoint stage -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

data_samples_flagged <-
  data_samples |>
  dplyr::mutate(
    flag_possible = coord_long >= -180 & coord_long <= 180 &
      coord_lat >= -90 & coord_lat <= 90
  )

data_positions <-
  prepare_link_positions(
    list_positions = list(
      v1_samples = data_samples_flagged |>
        dplyr::filter(flag_possible) |>
        dplyr::select(coord_long, coord_lat, age)
    )
  )

# Every sample with possible coordinates has exactly one position
data_sample_position <-
  data_samples_flagged |>
  dplyr::filter(flag_possible) |>
  dplyr::inner_join(
    data_positions,
    by = dplyr::join_by(coord_long, coord_lat, age),
    relationship = "many-to-one",
    unmatched = "error"
  ) |>
  dplyr::select(sample_id, position_id)

# The lowest sample id of each position stands for it
data_position_samples <-
  data_sample_position |>
  dplyr::summarise(
    sample_id = base::min(sample_id),
    n_samples = dplyr::n(),
    .by = position_id
  ) |>
  dplyr::arrange(position_id)

# first() after sorting, because min() warns on an empty table
data_impossible <-
  data_samples_flagged |>
  dplyr::filter(!flag_possible) |>
  dplyr::arrange(sample_id) |>
  dplyr::summarise(
    n_samples = dplyr::n(),
    sample_id = dplyr::first(sample_id),
    .by = c(coord_long, coord_lat, age)
  )

data_gridpoint_cells <-
  prepare_gridpoint_cells(
    list_coordinates = list(base::readRDS(path_cells)),
    n_digits = purrr::chuck(list_link, "coordinate_digits")
  )

vec_gridpoint_ages <-
  base::readRDS(path_ages)

n_ages <-
  base::length(vec_gridpoint_ages)

n_gridpoints_all <-
  base::as.double(base::nrow(data_gridpoint_cells)) * n_ages

list_link_windows <-
  build_link_windows(
    data_positions = data_positions,
    distance_km = purrr::chuck(list_link, "distance_km"),
    radius_min_km = purrr::chuck(list_link, "radius_min_km"),
    margin_deg = purrr::chuck(list_link, "window_margin_deg"),
    n_chunk_size = purrr::chuck(list_link, "chunk_size")
  )

cli::cli_inform(
  "Computing links for {base::nrow(data_positions)} positions in \\
  {base::length(list_link_windows)} chunks."
)

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
      step = "positions_and_links",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_position_links)
    )
  )


#----------------------------------------------------------#
# 3. v1.0.0 links of one sample per position -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

cli::cli_inform(
  "Reading the v1.0.0 links of {base::nrow(data_position_samples)} \\
  samples, one per position."
)

# The gridpoint id of each v1.0.0 gridpoint sample, by its coordinates and
#   age on the grid of the gridpoint stage; NA when it is not on the grid
data_gridpoints_v1_ids <-
  data_gridpoints_v1 |>
  dplyr::left_join(
    data_gridpoint_cells,
    by = dplyr::join_by(coord_long, coord_lat),
    relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    age_index = base::match(age, vec_gridpoint_ages),
    gridpoint_id = base::as.integer((cell_index - 1L) * n_ages + age_index)
  )

vec_gridpoint_lookup <-
  base::replace(
    x = base::rep(
      NA_integer_,
      base::max(dplyr::pull(data_gridpoints_v1_ids, sample_id))
    ),
    list = dplyr::pull(data_gridpoints_v1_ids, sample_id),
    values = dplyr::pull(data_gridpoints_v1_ids, gridpoint_id)
  )

DBI::dbWriteTable(
  conn = con_source,
  name = "tmp_position_samples",
  value = dplyr::select(data_position_samples, position_id, sample_id),
  temporary = TRUE
)

data_links_v1 <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT r.position_id, l.sample_ref_id, l.distance_in_km, ",
      "l.distance_in_years ",
      "FROM temp.tmp_position_samples AS r ",
      "JOIN AbioticDataReference AS l ON l.sample_id = r.sample_id"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(
    position_id = base::as.integer(position_id),
    gridpoint_id = vec_gridpoint_lookup[sample_ref_id],
    distance_in_km = base::as.integer(distance_in_km),
    distance_in_years = base::as.integer(distance_in_years)
  )

# v1.0.0 links of the samples that stand for impossible positions
DBI::dbWriteTable(
  conn = con_source,
  name = "tmp_impossible_samples",
  value = dplyr::select(data_impossible, sample_id),
  temporary = TRUE
)

data_impossible_links_v1 <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT r.sample_id, COUNT(l.sample_id) AS n_links_v1 ",
      "FROM temp.tmp_impossible_samples AS r ",
      "LEFT JOIN AbioticDataReference AS l ON l.sample_id = r.sample_id ",
      "GROUP BY r.sample_id"
    )
  ) |>
  tibble::as_tibble()

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "read_v1_links",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_links_v1)
    )
  )


#----------------------------------------------------------#
# 4. Compare the links -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

vec_key_new <-
  base::as.double(dplyr::pull(data_position_links, position_id)) *
    n_gridpoints_all +
    dplyr::pull(data_position_links, gridpoint_id)

vec_key_v1 <-
  base::as.double(dplyr::pull(data_links_v1, position_id)) *
    n_gridpoints_all +
    dplyr::pull(data_links_v1, gridpoint_id)

vec_match_v1 <-
  base::match(vec_key_v1, vec_key_new)

data_v1_matched <-
  data_links_v1 |>
  dplyr::mutate(
    flag_found = !base::is.na(vec_match_v1),
    km_new = dplyr::pull(data_position_links, distance_in_km)[vec_match_v1],
    years_new = dplyr::pull(data_position_links, distance_in_years)[
      vec_match_v1
    ],
    flag_same = flag_found &
      km_new == distance_in_km &
      years_new == distance_in_years
  )

data_v1_not_reproduced <-
  data_v1_matched |>
  dplyr::filter(!flag_same)

# Links found only by the gridpoint stage, with the reason v1.0.0 missed
#   them, from the position and the gridpoint coordinates
data_new_only <-
  data_position_links |>
  dplyr::filter(!(vec_key_new %in% vec_key_v1)) |>
  dplyr::mutate(
    cell_index = (gridpoint_id - 1L) %/% n_ages + 1L
  ) |>
  dplyr::left_join(
    dplyr::select(
      data_gridpoint_cells,
      cell_index,
      grid_long = coord_long,
      grid_lat = coord_lat
    ),
    by = dplyr::join_by(cell_index),
    relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    dplyr::select(data_positions, position_id, coord_long, coord_lat),
    by = dplyr::join_by(position_id),
    relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    longitude_difference = base::abs(coord_long - grid_long),
    reason = dplyr::case_when(
      longitude_difference > 180 ~ "across the dateline",
      longitude_difference > value_v1_window_deg ~
        "longitude difference above the v1 window",
      .default = "other"
    ),
    lat_band = base::floor(coord_lat / 10) * 10
  )

data_comparison <-
  tibble::tibble(
    target = name_target,
    n_samples = base::nrow(data_samples),
    n_samples_impossible = base::sum(
      !dplyr::pull(data_samples_flagged, flag_possible)
    ),
    n_positions = base::nrow(data_positions),
    n_positions_impossible = base::nrow(data_impossible),
    n_gridpoints_v1 = base::nrow(data_gridpoints_v1),
    n_gridpoints_v1_off_grid = base::sum(
      base::is.na(dplyr::pull(data_gridpoints_v1_ids, gridpoint_id))
    ),
    n_links_v1 = base::nrow(data_links_v1),
    n_links_v1_found = base::sum(dplyr::pull(data_v1_matched, flag_found)),
    n_links_v1_same = base::sum(dplyr::pull(data_v1_matched, flag_same)),
    n_links_new = base::nrow(data_position_links),
    n_links_new_only = base::nrow(data_new_only),
    n_new_only_dateline = base::sum(
      dplyr::pull(data_new_only, reason) == "across the dateline"
    ),
    n_new_only_window = base::sum(
      dplyr::pull(data_new_only, reason) ==
        "longitude difference above the v1 window"
    ),
    n_new_only_other = base::sum(
      dplyr::pull(data_new_only, reason) == "other"
    ),
    n_positions_with_new_links = dplyr::n_distinct(
      dplyr::pull(data_new_only, position_id)
    ),
    n_links_v1_impossible = base::sum(
      dplyr::pull(data_impossible_links_v1, n_links_v1)
    )
  )

data_new_only_by_latitude <-
  data_new_only |>
  dplyr::count(lat_band, reason, name = "n_links") |>
  dplyr::left_join(
    data_new_only |>
      dplyr::distinct(lat_band, reason, position_id) |>
      dplyr::count(lat_band, reason, name = "n_positions"),
    by = dplyr::join_by(lat_band, reason)
  ) |>
  dplyr::arrange(lat_band, reason)

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "compare_links",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_links_v1)
    )
  )


#----------------------------------------------------------#
# 5. The other samples of each position -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

cli::cli_inform("Counting the v1.0.0 links of every sample.")

# One grouped count over the whole link table, through its sample index
data_link_counts_v1 <-
  DBI::dbGetQuery(
    con_source,
    stringr::str_c(
      "SELECT sample_id, COUNT(*) AS n_links_v1 ",
      "FROM AbioticDataReference GROUP BY sample_id"
    )
  ) |>
  tibble::as_tibble() |>
  dplyr::mutate(sample_id = base::as.integer(sample_id))

DBI::dbDisconnect(con_source)

data_position_counts_v1 <-
  data_links_v1 |>
  dplyr::count(position_id, name = "n_links_position")

data_sample_counts <-
  data_sample_position |>
  dplyr::left_join(
    data_link_counts_v1,
    by = dplyr::join_by(sample_id),
    relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    data_position_counts_v1,
    by = dplyr::join_by(position_id),
    relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    n_links_v1 = dplyr::coalesce(n_links_v1, 0L),
    n_links_position = dplyr::coalesce(n_links_position, 0L),
    flag_same_count = n_links_v1 == n_links_position
  )

data_counts_check <-
  tibble::tibble(
    n_samples_checked = base::nrow(data_sample_counts),
    n_samples_same_count = base::sum(
      dplyr::pull(data_sample_counts, flag_same_count)
    ),
    n_samples_other_count = base::sum(
      !dplyr::pull(data_sample_counts, flag_same_count)
    ),
    n_positions_other_count = data_sample_counts |>
      dplyr::filter(!flag_same_count) |>
      dplyr::distinct(position_id) |>
      base::nrow(),
    n_link_rows_v1 = base::sum(dplyr::pull(data_link_counts_v1, n_links_v1)),
    n_samples_with_links_v1 = base::nrow(data_link_counts_v1),
    n_samples_with_links_without_position = data_link_counts_v1 |>
      dplyr::anti_join(data_sample_position, by = dplyr::join_by(sample_id)) |>
      base::nrow()
  )

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "count_links_per_sample",
      seconds = base::as.numeric(
        base::difftime(base::Sys.time(), time_step_start, units = "secs")
      ),
      n_rows = base::nrow(data_link_counts_v1)
    )
  )


#----------------------------------------------------------#
# 6. Record the run -----
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
  x = data_counts_check,
  file = base::file.path(path_out, "counts_per_sample.csv")
)

readr::write_csv(
  x = data_new_only_by_latitude,
  file = base::file.path(path_out, "new_links_by_latitude.csv")
)

readr::write_csv(
  x = data_v1_not_reproduced,
  file = base::file.path(path_out, "v1_links_not_reproduced.csv")
)

readr::write_csv(
  x = dplyr::filter(data_new_only, reason == "other"),
  file = base::file.path(path_out, "new_links_other_reason.csv")
)

readr::write_csv(
  x = data_sample_counts |>
    dplyr::filter(!flag_same_count) |>
    utils::head(n = 1000L),
  file = base::file.path(path_out, "samples_other_count_first_1000.csv")
)

readr::write_csv(
  x = data_impossible |>
    dplyr::left_join(
      data_impossible_links_v1,
      by = dplyr::join_by(sample_id)
    ),
  file = base::file.path(path_out, "positions_impossible.csv")
)

readr::write_csv(
  x = data_step_log |>
    dplyr::mutate(target = name_target, .before = 1L),
  file = base::file.path(path_out, "steps.csv")
)

readr::write_csv(
  x = tibble::tibble(
    script = "22_check_links_against_v1.R",
    target = name_target,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::as.numeric(
      base::difftime(base::Sys.time(), time_run_start, units = "secs")
    ),
    peak_wset_mb = purrr::chuck(list_memory, "peak_wset") / 1e6,
    connection_flags = "RSQLite SQLITE_RO; temporary tables only",
    git_commit = load_git_commit(),
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    source_unchanged = flag_source_unchanged
  ),
  file = base::file.path(path_out, "run_info.csv")
)

if (
  base::isFALSE(flag_source_unchanged)
) {
  cli::cli_abort("The source database differs after the read-only session.")
}

if (
  base::nrow(data_v1_not_reproduced) > 0L ||
    purrr::chuck(data_comparison, "n_new_only_other") > 0L ||
    purrr::chuck(data_counts_check, "n_samples_other_count") > 0L
) {
  cli::cli_abort(
    c(
      "The links differ from {name_target} in an unexplained way.",
      "i" = "See {.path {path_out}}."
    )
  )
}

cli::cli_inform(
  c(
    "v" = "Every {name_target} link is found with the same km and years, \\
    and every new link is explained.",
    "i" = "Results in {.path {path_out}}."
  )
)
