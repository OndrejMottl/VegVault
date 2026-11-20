#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Run the 2.0.0 link step on all v1.0.0 positions
#            - v1.0.0 read-only; links to a new file
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Run the link step of the r_memory engine (17a_run_build_engine.R) on all
#   positions of a database, and write the position tables in one bulk
#   load, to measure at full size what question 5 could only extrapolate:
#   1. Read the non-gridpoint samples with coordinates and age, number the
#      positions, compute the links under the 2.0.0 rule in chunks, and
#      find the linked gridpoints. The code of these steps is a copy of
#      17a_run_build_engine.R and must stay identical to it; the `subset`
#      target checks that: its tables must equal those of the r_memory
#      reference output of a benchmark run.
#   2. Write Positions, SamplePosition, PositionLink and Gridpoints into a
#      new SQLite file in one transaction, and run `ANALYZE`.
#   3. Count links per position and per latitude band, and log the time of
#      every step and the peak memory of the process.
#   4. For the `v1` target, compare the 2.0.0 links with the v1 links for a
#      drawn set of positions: a random draw, and draws among positions
#      near the dateline and near the poles (`full_links` settings). The v1
#      links of a position are those of its lowest sample id; every v1 link
#      should be found with the same km and years, and links found only
#      with the 2.0.0 rule are described by why v1 missed them.
# The source database is opened read-only. For `v1`, its path comes from
#   the secrets file and is never printed; the file size, modification
#   time and header are compared before and after, and no journal, WAL or
#   SHM file may appear. Each call writes a new folder under
#   `Data/Temp/Database_research/Full_links` and overwrites nothing; a
#   failed call is restarted in a new folder.
#
# A third target, `positions`, reruns the link step on the positions that
#   a `v1` run saved (its links.sqlite, not v1.0.0 itself) with another
#   chunk size, to measure time and memory against the chunk size. It
#   writes no database and compares its counts with that run.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/20_run_full_size_links.R
#     subset <run folder of script 17>
#   Rscript R/Analyses/90_Database_research/20_run_full_size_links.R v1
#   Rscript R/Analyses/90_Database_research/20_run_full_size_links.R
#     positions <v1 run folder of this script> <chunk size>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::identical(vec_args, "v1") ||
    (
      base::length(vec_args) == 2L &&
        purrr::chuck(vec_args, 1L) == "subset" &&
        stringr::str_detect(purrr::chuck(vec_args, 2L), "^run_[0-9_]+$")
    ) ||
    (
      base::length(vec_args) == 3L &&
        purrr::chuck(vec_args, 1L) == "positions" &&
        stringr::str_detect(
          purrr::chuck(vec_args, 2L), "^run_[0-9_]+_v1$"
        ) &&
        stringr::str_detect(purrr::chuck(vec_args, 3L), "^[0-9]+$")
    ),
  msg = stringr::str_c(
    "Give `v1`, `subset` and the run folder of script 17, or `positions`, ",
    "a v1 run folder of this script and a chunk size."
  )
)

name_target <-
  purrr::chuck(vec_args, 1L)

flag_write <-
  name_target != "positions"

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_engines <-
  purrr::chuck(list_settings, "engines")

list_settings_full <-
  purrr::chuck(list_settings, "full_links")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_source <-
  if (
    name_target == "v1"
  ) {
    # Load configuration (resolves `path_to_vegvault` from the secrets file)
    source(here::here("R/00_Config_file.R"))

    path_to_vegvault
  } else if (
    name_target == "subset"
  ) {
    base::file.path(
      path_research,
      "Subset",
      stringr::str_c(
        "v1_subset_",
        purrr::chuck(list_settings, "subset", "box_name"),
        ".sqlite"
      )
    )
  } else {
    base::file.path(
      path_research, "Full_links", purrr::chuck(vec_args, 2L), "links.sqlite"
    )
  }

assertthat::assert_that(
  base::file.exists(path_source),
  msg = "The source database does not exist."
)

time_run_start <-
  base::Sys.time()

path_out <-
  base::file.path(
    path_research,
    "Full_links",
    stringr::str_c(
      "run_", base::format(time_run_start, "%Y%m%d_%H%M%S"), "_",
      name_target,
      dplyr::if_else(
        name_target == "positions",
        stringr::str_c("_chunk", dplyr::last(vec_args)),
        ""
      )
    )
  )

assertthat::assert_that(
  !base::dir.exists(path_out),
  msg = "The run folder exists already."
)

base::dir.create(path = path_out, recursive = TRUE)

path_db_out <-
  base::file.path(path_out, "links.sqlite")

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

n_chunk_size <-
  if (
    name_target == "positions"
  ) {
    dplyr::last(vec_args) |>
      base::as.integer()
  } else {
    purrr::chuck(list_settings_engines, "chunk_size") |>
      base::as.integer()
  }

value_distance_km <-
  purrr::chuck(list_settings_engines, "distance_km")

value_distance_years <-
  purrr::chuck(list_settings_engines, "distance_years")

value_margin_deg <-
  purrr::chuck(list_settings_engines, "window_margin_deg")

# Angular radius of the link distance on the smallest radius of curvature
value_delta_rad <-
  value_distance_km / purrr::chuck(list_settings_engines, "radius_min_km")

value_dlat_deg <-
  value_delta_rad * 180 / pi + value_margin_deg

# The v1 fine window: +-1 degree of longitude (half the 2-degree grid)
value_v1_window_deg <-
  purrr::chuck(list_settings, "profiling", "grid_size_degree") / 2

# The global cells and ages, numbered as in 17_benchmark_build_engines.R
data_cells <-
  purrr::chuck(list_settings_engines, "cells_file") |>
  here::here() |>
  base::readRDS() |>
  dplyr::transmute(
    cell_index = dplyr::row_number(),
    grid_long = long,
    grid_lat = lat
  )

data_ages <-
  tibble::tibble(
    grid_age = base::readRDS(
      here::here(purrr::chuck(list_settings_engines, "ages_file"))
    ) |>
      base::sort()
  ) |>
  dplyr::mutate(age_index = dplyr::row_number(), .before = 1L)

n_ages <-
  base::nrow(data_ages)

# The output tables, from the output schema of the benchmark
vec_table_sql <-
  readr::read_lines(
    here::here(
      "R/Analyses/90_Database_research/Prototype_schemas",
      "engine_output_tables.sql"
    )
  ) |>
  stringr::str_subset(pattern = "^\\s*--", negate = TRUE) |>
  stringr::str_c(collapse = "\n") |>
  stringr::str_split(pattern = ";\\s*(\\n|$)") |>
  purrr::chuck(1L) |>
  stringr::str_trim() |>
  purrr::keep(.p = base::nzchar) |>
  stringr::str_subset(
    pattern = stringr::str_c(
      "^CREATE TABLE \"(Positions|SamplePosition|PositionLink|Gridpoints)\""
    )
  )

assertthat::assert_that(
  base::length(vec_table_sql) == 4L,
  msg = "The output schema lacks a position table."
)

sql_sample_source <-
  if (
    name_target == "positions"
  ) {
    # The samples and positions that a v1 run saved
    stringr::str_c(
      "SELECT sp.sample_id, p.coord_long, p.coord_lat, p.age ",
      "FROM SamplePosition AS sp ",
      "JOIN Positions AS p ON p.position_id = sp.position_id"
    )
  } else {
    stringr::str_c(
      "SELECT s.sample_id, d.coord_long, d.coord_lat, s.age ",
      "FROM Samples AS s ",
      "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
      "WHERE d.dataset_type_id != (SELECT dataset_type_id FROM ",
      "DatasetTypeID WHERE dataset_type = 'gridpoints') ",
      "AND d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL ",
      "AND s.age IS NOT NULL"
    )
  }

data_step_log <-
  tibble::tibble(
    step = base::character(),
    seconds = base::numeric(),
    n_rows = base::numeric()
  )


#----------------------------------------------------------#
# 1. Record the source state before reading -----
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

con_src <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_source,
    flags = RSQLite::SQLITE_RO
  )


#----------------------------------------------------------#
# 2. Positions and links (as in 17a_run_build_engine.R) -----
#----------------------------------------------------------#

time_step_start <-
  base::Sys.time()

cli::cli_inform("Reading the samples.")

data_sample_source <-
  DBI::dbGetQuery(con_src, sql_sample_source) |>
  tibble::as_tibble()

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "read_samples",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      n_rows = base::nrow(data_sample_source)
    )
  )

time_step_start <-
  base::Sys.time()

data_positions <-
  data_sample_source |>
  dplyr::distinct(coord_long, coord_lat, age) |>
  dplyr::arrange(coord_long, coord_lat, age) |>
  dplyr::mutate(position_id = dplyr::row_number(), .before = 1L)

data_sample_position <-
  data_sample_source |>
  dplyr::inner_join(
    data_positions,
    by = dplyr::join_by(coord_long, coord_lat, age),
    multiple = "error",
    unmatched = "error"
  ) |>
  dplyr::select(sample_id, position_id) |>
  dplyr::arrange(sample_id)

# Candidate windows: latitude band, and a longitude band that grows with
#   latitude; a band crossing the dateline gets a second, shifted window
data_windows_base <-
  data_positions |>
  dplyr::mutate(
    chunk = (position_id - 1L) %/% n_chunk_size + 1L,
    lat_lo = coord_lat - value_dlat_deg,
    lat_hi = coord_lat + value_dlat_deg,
    lat_edge_rad = base::pmin(base::abs(coord_lat) + value_dlat_deg, 90) *
      pi / 180,
    ratio_lon = base::sin(value_delta_rad) / base::cos(lat_edge_rad),
    dlon = dplyr::if_else(
      condition = ratio_lon >= 1,
      true = 180,
      false = base::asin(base::pmin(ratio_lon, 1)) * 180 / pi +
        value_margin_deg
    )
  )

data_windows <-
  dplyr::bind_rows(
    data_windows_base |>
      dplyr::mutate(
        lon_lo = dplyr::if_else(
          dlon >= 180, -180, base::pmax(coord_long - dlon, -180)
        ),
        lon_hi = dplyr::if_else(
          dlon >= 180, 180, base::pmin(coord_long + dlon, 180)
        )
      ),
    data_windows_base |>
      dplyr::filter(dlon < 180, coord_long - dlon < -180) |>
      dplyr::mutate(lon_lo = coord_long - dlon + 360, lon_hi = 180),
    data_windows_base |>
      dplyr::filter(dlon < 180, coord_long + dlon > 180) |>
      dplyr::mutate(lon_lo = -180, lon_hi = coord_long + dlon - 360)
  ) |>
  dplyr::select(
    position_id, chunk, coord_long, coord_lat, age,
    lat_lo, lat_hi, lon_lo, lon_hi
  )

vec_chunks <-
  data_windows |>
  dplyr::pull(chunk) |>
  base::unique() |>
  base::sort()

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "positions",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      n_rows = base::nrow(data_positions)
    )
  )

time_step_start <-
  base::Sys.time()

cli::cli_inform(
  "Computing links for {nrow(data_positions)} positions in \\
  {length(vec_chunks)} chunks."
)

list_link_chunks <-
  purrr::map(
    .x = vec_chunks,
    .f = ~ {
      data_windows_chunk <-
        data_windows |>
        dplyr::filter(chunk == .x)

      data_cells_chunk <-
        data_cells |>
        dplyr::filter(
          grid_lat >= base::min(data_windows_chunk |> dplyr::pull(lat_lo)),
          grid_lat <= base::max(data_windows_chunk |> dplyr::pull(lat_hi)),
          grid_long >= base::min(data_windows_chunk |> dplyr::pull(lon_lo)),
          grid_long <= base::max(data_windows_chunk |> dplyr::pull(lon_hi))
        )

      data_links_chunk <-
        data_cells_chunk |>
        dplyr::inner_join(
          data_windows_chunk,
          by = dplyr::join_by(
            dplyr::between(grid_lat, lat_lo, lat_hi),
            dplyr::between(grid_long, lon_lo, lon_hi)
          )
        ) |>
        dplyr::distinct(position_id, cell_index, .keep_all = TRUE) |>
        dplyr::mutate(
          distance_in_m = geosphere::distGeo(
            p1 = base::cbind(coord_long, coord_lat),
            p2 = base::cbind(grid_long, grid_lat)
          )
        ) |>
        dplyr::filter(distance_in_m <= value_distance_km * 1000) |>
        dplyr::mutate(
          age_lo = age - value_distance_years,
          age_hi = age + value_distance_years
        )

      data_ages |>
        dplyr::inner_join(
          data_links_chunk,
          by = dplyr::join_by(dplyr::between(grid_age, age_lo, age_hi))
        ) |>
        dplyr::mutate(
          distance_in_years_exact = base::abs(age - grid_age)
        ) |>
        dplyr::filter(distance_in_years_exact <= value_distance_years) |>
        dplyr::transmute(
          position_id,
          gridpoint_id = (cell_index - 1L) * n_ages + age_index,
          distance_in_km = base::as.integer(
            base::floor(distance_in_m / 1000)
          ),
          distance_in_years = base::as.integer(distance_in_years_exact)
        ) |>
        dplyr::arrange(position_id, gridpoint_id)
    }
  )

data_links <-
  list_link_chunks |>
  dplyr::bind_rows()

base::rm(list_link_chunks)

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "links",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      n_rows = base::nrow(data_links)
    ),
    tibble::tibble(
      step = "bytes_links_in_r",
      seconds = NA_real_,
      n_rows = utils::object.size(data_links) |>
        base::as.numeric()
    )
  )

time_step_start <-
  base::Sys.time()

data_gridpoints_out <-
  tibble::tibble(
    gridpoint_id = data_links |>
      dplyr::pull(gridpoint_id) |>
      base::unique() |>
      base::sort()
  ) |>
  dplyr::mutate(
    cell_index = (gridpoint_id - 1L) %/% n_ages + 1L,
    age_index = (gridpoint_id - 1L) %% n_ages + 1L
  ) |>
  # Every gridpoint must find its cell and age; unused cells and ages drop
  dplyr::inner_join(
    data_cells,
    by = dplyr::join_by(cell_index),
    multiple = "error",
    unmatched = c("error", "drop")
  ) |>
  dplyr::inner_join(
    data_ages,
    by = dplyr::join_by(age_index),
    multiple = "error",
    unmatched = c("error", "drop")
  ) |>
  dplyr::transmute(
    gridpoint_id,
    coord_long = grid_long,
    coord_lat = grid_lat,
    age = base::as.integer(grid_age)
  )

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "gridpoints",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      n_rows = base::nrow(data_gridpoints_out)
    )
  )


#----------------------------------------------------------#
# 3. Write the position tables in one transaction -----
#----------------------------------------------------------#

# The `positions` target only times the link step
if (
  base::isTRUE(flag_write)
) {
  time_step_start <-
    base::Sys.time()

  cli::cli_inform("Writing {nrow(data_links)} links.")

  con_out <-
    DBI::dbConnect(RSQLite::SQLite(), path_db_out)

  data_journal_mode <-
    DBI::dbGetQuery(con_out, "PRAGMA journal_mode = OFF")

  DBI::dbExecute(con_out, "PRAGMA synchronous = OFF")

  DBI::dbExecute(con_out, "PRAGMA cache_size = -1048576")

  purrr::walk(
    .x = vec_table_sql,
    .f = ~ DBI::dbExecute(con_out, .x)
  )

  DBI::dbBegin(con_out)

  purrr::iwalk(
    .x = list(
      Positions = data_positions,
      SamplePosition = data_sample_position,
      PositionLink = data_links,
      Gridpoints = data_gridpoints_out
    ),
    .f = ~ DBI::dbAppendTable(con_out, .y, .x)
  )

  DBI::dbCommit(con_out)

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "write",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = base::nrow(data_positions) +
          base::nrow(data_sample_position) +
          base::nrow(data_links) +
          base::nrow(data_gridpoints_out)
      )
    )

  time_step_start <-
    base::Sys.time()

  DBI::dbExecute(con_out, "ANALYZE main")

  DBI::dbDisconnect(con_out)

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "analyze",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = NA_real_
      )
    )

}

#----------------------------------------------------------#
# 4. Counts -----
#----------------------------------------------------------#

data_links_per_position <-
  data_positions |>
  dplyr::select(position_id, coord_lat) |>
  dplyr::left_join(
    data_links |>
      dplyr::count(position_id, name = "n_links"),
    by = "position_id"
  ) |>
  dplyr::mutate(n_links = dplyr::coalesce(n_links, 0L))

readr::write_csv(
  x = tibble::tibble(
    target = name_target,
    n_samples = base::nrow(data_sample_source),
    n_positions = base::nrow(data_positions),
    n_positions_without_links = data_links_per_position |>
      dplyr::filter(n_links == 0L) |>
      base::nrow(),
    n_links = base::nrow(data_links),
    n_gridpoints = base::nrow(data_gridpoints_out),
    n_chunks = base::length(vec_chunks),
    file_mb = dplyr::if_else(
      flag_write,
      base::file.size(path_db_out) / 1e6,
      NA_real_
    )
  ),
  file = base::file.path(path_out, "counts.csv")
)

data_links_per_position |>
  dplyr::mutate(
    lat_band = base::floor(coord_lat / 10) * 10
  ) |>
  dplyr::summarise(
    n_positions = dplyr::n(),
    n_links = base::sum(n_links),
    .by = lat_band
  ) |>
  dplyr::arrange(lat_band) |>
  readr::write_csv(
    file = base::file.path(path_out, "links_by_latitude_band.csv")
  )

data_links_per_position |>
  dplyr::count(n_links, name = "n_positions") |>
  readr::write_csv(
    file = base::file.path(path_out, "links_per_position.csv")
  )


#----------------------------------------------------------#
# 5. Checks: benchmark (subset), v1 (v1), chunk size (positions) -----
#----------------------------------------------------------#

if (
  name_target == "subset"
) {
  # The tables must equal those of the r_memory reference output
  path_reference <-
    base::file.path(
      path_research, "Engines", purrr::chuck(vec_args, 2L),
      "r_memory_rep1.sqlite"
    )

  assertthat::assert_that(
    base::file.exists(path_reference),
    msg = "The reference output of the benchmark is missing."
  )

  data_code_check <-
    c("Positions", "SamplePosition", "PositionLink", "Gridpoints") |>
    purrr::map(
      .f = ~ {
        name_table <- .x

        vec_hashes <-
          c(path_db_out, path_reference) |>
          purrr::map_chr(
            .f = ~ {
              con_check <-
                DBI::dbConnect(
                  RSQLite::SQLite(),
                  .x,
                  flags = RSQLite::SQLITE_RO
                )

              vec_columns <-
                DBI::dbGetQuery(
                  con_check,
                  stringr::str_c("PRAGMA table_info(\"", name_table, "\")")
                ) |>
                dplyr::pull(name)

              text_hash <-
                DBI::dbGetQuery(
                  con_check,
                  stringr::str_c(
                    "SELECT * FROM \"", name_table, "\" ORDER BY ",
                    stringr::str_c("\"", vec_columns, "\"", collapse = ", ")
                  )
                ) |>
                base::as.list() |>
                base::unname() |>
                rlang::hash()

              DBI::dbDisconnect(con_check)

              text_hash
            }
          )

        tibble::tibble(
          table_name = name_table,
          hash_run = purrr::chuck(vec_hashes, 1L),
          hash_reference = purrr::chuck(vec_hashes, 2L),
          flag_same = hash_run == hash_reference
        )
      }
    ) |>
    dplyr::bind_rows()

  readr::write_csv(
    x = data_code_check,
    file = base::file.path(path_out, "code_check.csv")
  )

  assertthat::assert_that(
    base::all(data_code_check |> dplyr::pull(flag_same)),
    msg = "The link code differs from the benchmark's r_memory engine."
  )
}

if (
  name_target == "v1"
) {
  time_step_start <-
    base::Sys.time()

  cli::cli_inform("Comparing drawn positions with the v1 links.")

  # The lowest sample id of each position stands for it
  data_position_samples <-
    data_sample_position |>
    dplyr::summarise(sample_id = base::min(sample_id), .by = position_id) |>
    dplyr::left_join(data_positions, by = "position_id")

  base::set.seed(purrr::chuck(list_settings_full, "seed"))

  data_draw <-
    dplyr::bind_rows(
      data_position_samples |>
        dplyr::slice_sample(
          n = purrr::chuck(list_settings_full, "n_draw_random")
        ) |>
        dplyr::mutate(stratum = "random"),
      data_position_samples |>
        dplyr::filter(
          base::abs(coord_long) >=
            purrr::chuck(list_settings_full, "dateline_long")
        ) |>
        dplyr::slice_sample(
          n = purrr::chuck(list_settings_full, "n_draw_dateline")
        ) |>
        dplyr::mutate(stratum = "dateline"),
      data_position_samples |>
        dplyr::filter(
          base::abs(coord_lat) >=
            purrr::chuck(list_settings_full, "polar_lat")
        ) |>
        dplyr::slice_sample(
          n = purrr::chuck(list_settings_full, "n_draw_polar")
        ) |>
        dplyr::mutate(stratum = "polar")
    )

  data_draw_positions <-
    data_draw |>
    dplyr::distinct(position_id, sample_id)

  DBI::dbWriteTable(
    conn = con_src,
    name = "tmp_draw",
    value = data_draw_positions,
    temporary = TRUE
  )

  # v1 links of the drawn positions, with the gridpoint coordinates and age
  data_v1_links <-
    DBI::dbGetQuery(
      con_src,
      stringr::str_c(
        "SELECT r.position_id, d.coord_long AS grid_long, ",
        "d.coord_lat AS grid_lat, s.age AS grid_age, ",
        "l.distance_in_km, l.distance_in_years ",
        "FROM temp.tmp_draw AS r ",
        "JOIN AbioticDataReference AS l ON l.sample_id = r.sample_id ",
        "JOIN Samples AS s ON s.sample_id = l.sample_ref_id ",
        "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
        "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id"
      )
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(grid_age = base::as.numeric(grid_age))

  data_new_links <-
    data_links |>
    dplyr::filter(
      position_id %in% (data_draw_positions |> dplyr::pull(position_id))
    ) |>
    dplyr::left_join(
      data_gridpoints_out |>
        dplyr::rename(
          grid_long = coord_long,
          grid_lat = coord_lat,
          grid_age = age
        ),
      by = "gridpoint_id"
    ) |>
    dplyr::mutate(grid_age = base::as.numeric(grid_age)) |>
    dplyr::select(-gridpoint_id)

  vec_keys <-
    c("position_id", "grid_long", "grid_lat", "grid_age")

  data_v1_matched <-
    data_v1_links |>
    dplyr::left_join(
      data_new_links |>
        dplyr::rename(
          km_new = distance_in_km,
          years_new = distance_in_years
        ),
      by = vec_keys,
      multiple = "error"
    )

  data_new_only <-
    data_new_links |>
    dplyr::anti_join(data_v1_links, by = vec_keys) |>
    dplyr::left_join(
      data_positions |> dplyr::select(position_id, coord_long, coord_lat),
      by = "position_id"
    ) |>
    dplyr::mutate(
      longitude_difference = base::abs(coord_long - grid_long),
      reason = dplyr::case_when(
        longitude_difference > 180 ~ "across the dateline",
        longitude_difference > value_v1_window_deg ~
          "longitude difference above the v1 window",
        .default = "other"
      )
    )

  data_compare_by_stratum <-
    data_draw |>
    dplyr::distinct(stratum, position_id) |>
    dplyr::summarise(
      n_positions = dplyr::n(),
      .by = stratum
    ) |>
    dplyr::left_join(
      data_draw |>
        dplyr::distinct(stratum, position_id) |>
        dplyr::left_join(
          data_v1_matched |>
            dplyr::summarise(
              n_v1 = dplyr::n(),
              n_v1_found = base::sum(!base::is.na(km_new)),
              n_v1_same = base::sum(
                !base::is.na(km_new) &
                  km_new == distance_in_km &
                  years_new == distance_in_years
              ),
              .by = position_id
            ),
          by = "position_id"
        ) |>
        dplyr::left_join(
          data_new_links |>
            dplyr::count(position_id, name = "n_new"),
          by = "position_id"
        ) |>
        dplyr::left_join(
          data_new_only |>
            dplyr::count(position_id, reason) |>
            tidyr::pivot_wider(
              names_from = reason,
              values_from = n,
              values_fill = 0L
            ),
          by = "position_id"
        ) |>
        dplyr::summarise(
          dplyr::across(
            .cols = -position_id,
            .fns = ~ base::sum(.x, na.rm = TRUE)
          ),
          .by = stratum
        ),
      by = "stratum"
    )

  readr::write_csv(
    x = data_compare_by_stratum,
    file = base::file.path(path_out, "compare_with_v1_by_stratum.csv")
  )

  # Any v1 link that the 2.0.0 rule does not reproduce, for inspection
  data_v1_matched |>
    dplyr::filter(
      base::is.na(km_new) |
        km_new != distance_in_km |
        years_new != distance_in_years
    ) |>
    readr::write_csv(
      file = base::file.path(path_out, "v1_links_not_reproduced.csv")
    )

  data_new_only |>
    dplyr::filter(reason == "other") |>
    readr::write_csv(
      file = base::file.path(path_out, "new_links_other_reason.csv")
    )

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "compare_with_v1",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = base::nrow(data_v1_links)
      )
    )
}

if (
  name_target == "positions"
) {
  # Another chunk size must give the same links as the run it reads
  data_source_counts <-
    readr::read_csv(
      file = base::file.path(
        path_research, "Full_links", purrr::chuck(vec_args, 2L), "counts.csv"
      ),
      show_col_types = FALSE,
      num_threads = 1L
    )

  data_chunk_check <-
    tibble::tibble(
      chunk_size = n_chunk_size,
      n_links_run = base::nrow(data_links),
      n_links_source = data_source_counts |> dplyr::pull(n_links),
      n_gridpoints_run = base::nrow(data_gridpoints_out),
      n_gridpoints_source = data_source_counts |> dplyr::pull(n_gridpoints)
    ) |>
    dplyr::mutate(
      flag_same = n_links_run == n_links_source &
        n_gridpoints_run == n_gridpoints_source
    )

  readr::write_csv(
    x = data_chunk_check,
    file = base::file.path(path_out, "chunk_check.csv")
  )

  assertthat::assert_that(
    base::isTRUE(data_chunk_check |> dplyr::pull(flag_same)),
    msg = "Another chunk size gave other links."
  )
}

DBI::dbDisconnect(con_src)


#----------------------------------------------------------#
# 6. Record the run -----
#----------------------------------------------------------#

list_memory <-
  ps::ps_memory_info(ps::ps_handle())

readr::write_csv(
  x = data_step_log |>
    dplyr::mutate(target = name_target, .before = 1L),
  file = base::file.path(path_out, "steps.csv")
)

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
  x = tibble::tibble(
    script = "20_run_full_size_links.R",
    target = name_target,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    peak_wset_mb = purrr::chuck(list_memory, "peak_wset") / 1e6,
    chunk_size = n_chunk_size,
    connection_flags = "RSQLite SQLITE_RO; temporary tables only",
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

cli::cli_inform(
  c(
    "v" = "Ran the link step on {name_target}; the source is unchanged.",
    "i" = "Results in {.path {path_out}}."
  )
)
