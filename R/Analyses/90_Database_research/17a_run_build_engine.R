#----------------------------------------------------------#
#
#
#                       VegVault
#
#       Build the benchmark output with one build engine
#         - called by 17_benchmark_build_engines.R only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Build the benchmark output from the regional subset with one engine, in
#   its own R process, and log the time of every step and the peak memory
#   (peak working set) of the process. Every engine computes the same
#   tables with the same ids:
#   - positions: the distinct (coord_long, coord_lat, age) of the
#     non-gridpoint samples, numbered in that order;
#   - links: every gridpoint (cell and age) within `distance_km` (geodesic,
#     WGS84) and `distance_years` of a position. Candidate cells come from
#     a window that grows with latitude, covers the poles and wraps at the
#     dateline; the exact distance decides. km and years are stored as
#     integers rounded down, as v1 did. The gridpoint id is derived from the
#     cell number and the age number, so it does not depend on the order
#     of the work;
#   - gridpoints: the linked gridpoints with their coordinates and age, and
#     the bio1 value of each linked gridpoint of age 0;
#   - copies of the other subset tables (without the gridpoint rows);
#   - the secondary indexes of engine_output_indexes.sql and `ANALYZE`.
# Engines:
#   - r_memory: dplyr in memory, links computed in chunks and kept, then
#     one bulk load into a new SQLite file in one transaction;
#   - sqlite_incremental: the same R code, but each chunk of links is
#     written in its own transaction (WAL, synchronous = NORMAL) with a row
#     in BuildChunks, and every later step records itself in BuildSteps, so
#     a run that stops resumes where it stopped;
#   - duckdb: everything in DuckDB SQL (spatial extension for the geodesic
#     distance), written into the SQLite file through the sqlite extension.
#   Indexes and `ANALYZE` run through RSQLite in every engine.
# The subset is opened read-only.
#
# Arguments: engine (`r_memory`, `sqlite_incremental` or `duckdb`), run
#   folder, label (file name of the output), chunk order (`forward` or
#   `reverse`), stop after (0 to run to the end; k > 0 to stop in the middle
#   of chunk k + 1 of this session without committing it, which
#   sqlite_incremental uses to test resuming), DuckDB threads (0 for the
#   setting).


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 6L,
  msg = "Six arguments are expected."
)

name_engine <-
  purrr::chuck(vec_args, 1L)

path_run <-
  purrr::chuck(vec_args, 2L)

name_label <-
  purrr::chuck(vec_args, 3L)

name_chunk_order <-
  purrr::chuck(vec_args, 4L)

n_stop_after <-
  purrr::chuck(vec_args, 5L) |>
  base::as.integer()

n_duckdb_threads_arg <-
  purrr::chuck(vec_args, 6L) |>
  base::as.integer()

assertthat::assert_that(
  name_engine %in% c("r_memory", "sqlite_incremental", "duckdb"),
  name_chunk_order %in% c("forward", "reverse"),
  base::dir.exists(path_run),
  msg = "Unknown engine or chunk order, or no run folder."
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_engines <-
  purrr::chuck(list_settings, "engines")

path_subset <-
  here::here(
    "Data", "Temp", "Database_research", "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings, "subset", "box_name"),
      ".sqlite"
    )
  ) |>
  base::normalizePath(winslash = "/", mustWork = TRUE)

uri_subset <-
  stringr::str_c("file:", path_subset, "?mode=ro")

path_db_out <-
  base::file.path(path_run, stringr::str_c(name_label, ".sqlite")) |>
  base::normalizePath(winslash = "/", mustWork = FALSE)

path_step_log <-
  base::file.path(path_run, stringr::str_c(name_label, "_steps.csv"))

path_memory_log <-
  base::file.path(path_run, stringr::str_c(name_label, "_memory.csv"))

name_session <-
  base::format(base::Sys.time(), "%Y%m%d_%H%M%S")

n_chunk_size <-
  purrr::chuck(list_settings_engines, "chunk_size") |>
  base::as.integer()

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

# Output schema
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
  purrr::keep(.p = base::nzchar)

vec_index_sql <-
  readr::read_lines(
    here::here(
      "R/Analyses/90_Database_research/Prototype_schemas",
      "engine_output_indexes.sql"
    )
  ) |>
  stringr::str_subset(pattern = "^\\s*--", negate = TRUE) |>
  stringr::str_c(collapse = "\n") |>
  stringr::str_split(pattern = ";\\s*(\\n|$)") |>
  purrr::chuck(1L) |>
  stringr::str_trim() |>
  purrr::keep(.p = base::nzchar)

# Inputs prepared by 17_benchmark_build_engines.R
data_cells <-
  base::readRDS(base::file.path(path_run, "inputs", "cells.rds"))

data_ages <-
  base::readRDS(base::file.path(path_run, "inputs", "ages.rds"))

n_ages <-
  base::nrow(data_ages)

value_bio1_id <-
  base::readRDS(base::file.path(path_run, "inputs", "bio1_variable_id.rds"))

# Source rows; <SRC> is replaced by the schema prefix of each engine
sql_gridpoint_type <-
  stringr::str_c(
    "(SELECT dataset_type_id FROM <SRC>DatasetTypeID ",
    "WHERE dataset_type = 'gridpoints')"
  )

sql_sample_source <-
  stringr::str_c(
    "SELECT s.sample_id, d.coord_long, d.coord_lat, s.age ",
    "FROM <SRC>Samples AS s ",
    "JOIN <SRC>DatasetSample AS ds ON ds.sample_id = s.sample_id ",
    "JOIN <SRC>Datasets AS d ON d.dataset_id = ds.dataset_id ",
    "WHERE d.dataset_type_id != ", sql_gridpoint_type, " ",
    "AND d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL ",
    "AND s.age IS NOT NULL"
  )

sql_non_gridpoint_datasets <-
  stringr::str_c(
    "SELECT dataset_id FROM <SRC>Datasets ",
    "WHERE dataset_type_id != ", sql_gridpoint_type
  )

sql_non_gridpoint_samples <-
  stringr::str_c(
    "SELECT ds.sample_id FROM <SRC>DatasetSample AS ds ",
    "JOIN <SRC>Datasets AS d ON d.dataset_id = ds.dataset_id ",
    "WHERE d.dataset_type_id != ", sql_gridpoint_type
  )

# The tables copied from the subset; gridpoint rows are left out
data_copies <-
  tibble::tribble(
    ~table_name, ~sql_where,
    "version_control", "",
    "Authors", "",
    "Datasets", stringr::str_c(
      " WHERE dataset_id IN (", sql_non_gridpoint_datasets, ")"
    ),
    "DatasetReferences", stringr::str_c(
      " WHERE dataset_id IN (", sql_non_gridpoint_datasets, ")"
    ),
    "DatasetTypeID", "",
    "DatasetSourceTypeID", "",
    "DatasetSourceTypeReference", "",
    "DatasetSourcesID", "",
    "DatasetSourcesReference", "",
    "SamplingMethodID", "",
    "SamplingMethodReference", "",
    "Samples", stringr::str_c(
      " WHERE sample_id IN (", sql_non_gridpoint_samples, ")"
    ),
    "SampleReference", stringr::str_c(
      " WHERE sample_id IN (", sql_non_gridpoint_samples, ")"
    ),
    "DatasetSample", stringr::str_c(
      " WHERE dataset_id IN (", sql_non_gridpoint_datasets, ")"
    ),
    "SampleUncertainty", "",
    "SampleSizeID", "",
    "SampleTaxa", "",
    "Taxa", "",
    "TaxonClassification", "",
    "TaxonReference", "",
    "TraitsDomain", "",
    "Traits", "",
    "TraitsValue", "",
    "TraitsReference", "",
    "AbioticVariable", "",
    "AbioticVariableReference", "",
    "References", ""
  )

# Columns and key order of every output table, from the output schema
con_schema <-
  DBI::dbConnect(RSQLite::SQLite(), ":memory:")

purrr::walk(
  .x = vec_table_sql,
  .f = ~ DBI::dbExecute(con_schema, .x)
)

data_table_info <-
  DBI::dbGetQuery(
    con_schema,
    stringr::str_c(
      "SELECT m.name AS table_name, p.name AS column_name, p.cid, p.pk ",
      "FROM sqlite_schema AS m JOIN pragma_table_info(m.name) AS p ",
      "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%'"
    )
  ) |>
  tibble::as_tibble()

DBI::dbDisconnect(con_schema)

data_table_columns <-
  data_table_info |>
  dplyr::arrange(table_name, cid) |>
  dplyr::summarise(
    text_columns = stringr::str_c("\"", column_name, "\"", collapse = ", "),
    .by = table_name
  ) |>
  dplyr::left_join(
    data_table_info |>
      dplyr::filter(pk > 0L) |>
      dplyr::arrange(table_name, pk) |>
      dplyr::summarise(
        text_key = stringr::str_c("\"", column_name, "\"", collapse = ", "),
        .by = table_name
      ),
    by = "table_name"
  ) |>
  # Tables without a key are ordered by all their columns
  dplyr::mutate(text_key = dplyr::coalesce(text_key, text_columns))

data_copies <-
  data_copies |>
  dplyr::left_join(data_table_columns, by = "table_name") |>
  dplyr::mutate(
    sql_select = stringr::str_c(
      "SELECT ", text_columns, " FROM <SRC>\"", table_name, "\"",
      sql_where, " ORDER BY ", text_key
    )
  )

assertthat::assert_that(
  !base::anyNA(data_copies |> dplyr::pull(text_columns)),
  msg = "A copied table is missing from the output schema."
)

# Steps are logged as they finish; the log is written at the end of the
#   session, or before a deliberate stop
data_step_log <-
  tibble::tibble(
    step = base::character(),
    seconds = base::numeric(),
    n_rows = base::numeric()
  )

time_step_start <-
  base::Sys.time()

cli::cli_inform("{name_engine}: {name_label}, session {name_session}.")


#----------------------------------------------------------#
# 1. R engines: positions and links -----
#----------------------------------------------------------#

if (
  name_engine %in% c("r_memory", "sqlite_incremental")
) {
  con_src <-
    DBI::dbConnect(
      RSQLite::SQLite(),
      path_subset,
      flags = RSQLite::SQLITE_RO
    )

  data_sample_source <-
    DBI::dbGetQuery(
      con_src,
      stringr::str_replace_all(sql_sample_source, "<SRC>", "")
    ) |>
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

  if (
    name_chunk_order == "reverse"
  ) {
    vec_chunks <- base::rev(vec_chunks)
  }

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

  # sqlite_incremental: open or resume the output, and write the positions
  if (
    name_engine == "sqlite_incremental"
  ) {
    flag_resume <-
      base::file.exists(path_db_out)

    con_out <-
      DBI::dbConnect(RSQLite::SQLite(), path_db_out)

    DBI::dbGetQuery(con_out, "PRAGMA journal_mode = WAL")

    DBI::dbExecute(con_out, "PRAGMA synchronous = NORMAL")

    DBI::dbExecute(con_out, "PRAGMA cache_size = -1048576")

    if (
      base::isFALSE(flag_resume)
    ) {
      purrr::walk(
        .x = vec_table_sql,
        .f = ~ DBI::dbExecute(con_out, .x)
      )
    }

    vec_steps_done <-
      DBI::dbGetQuery(con_out, "SELECT step FROM BuildSteps") |>
      dplyr::pull(step)

    if (
      !"positions" %in% vec_steps_done
    ) {
      DBI::dbBegin(con_out)

      DBI::dbAppendTable(con_out, "Positions", data_positions)

      DBI::dbAppendTable(con_out, "SamplePosition", data_sample_position)

      DBI::dbExecute(
        con_out,
        "INSERT INTO BuildSteps (step, n_rows) VALUES ('positions', ?)",
        params = list(base::nrow(data_positions))
      )

      DBI::dbCommit(con_out)
    }

    vec_chunks_done <-
      DBI::dbGetQuery(con_out, "SELECT chunk FROM BuildChunks") |>
      dplyr::pull(chunk)

    vec_chunks <-
      vec_chunks[!vec_chunks %in% vec_chunks_done]

    data_step_log <-
      data_step_log |>
      dplyr::bind_rows(
        tibble::tibble(
          step = "write_positions",
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
  }

  # Links, chunk by chunk
  list_link_chunks <-
    purrr::map2(
      .x = vec_chunks,
      .y = base::seq_along(vec_chunks),
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

        data_links_chunk <-
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

        if (
          name_engine == "r_memory"
        ) {
          data_links_chunk
        } else if (
          n_stop_after > 0L && .y == n_stop_after + 1L
        ) {
          # A deliberate stop in the middle of a chunk: half of its links
          #   are written in an open transaction, which is never committed
          readr::write_csv(
            x = data_step_log |>
              dplyr::mutate(
                session = name_session,
                engine = name_engine,
                label = name_label,
                .before = 1L
              ),
            file = path_step_log,
            append = base::file.exists(path_step_log)
          )

          DBI::dbBegin(con_out)

          DBI::dbAppendTable(
            con_out,
            "PositionLink",
            data_links_chunk |>
              dplyr::slice_head(
                n = base::nrow(data_links_chunk) %/% 2L
              )
          )

          cli::cli_inform("Stopping in the middle of a chunk, as asked.")

          # The process kills itself, as a crash would: no commit, no
          #   clean close of the connection
          ps::ps_kill(ps::ps_handle())
        } else {
          DBI::dbBegin(con_out)

          DBI::dbAppendTable(con_out, "PositionLink", data_links_chunk)

          DBI::dbExecute(
            con_out,
            stringr::str_c(
              "INSERT INTO BuildChunks (chunk, n_positions, n_links) ",
              "VALUES (?, ?, ?)"
            ),
            params = list(
              .x,
              data_windows_chunk |>
                dplyr::distinct(position_id) |>
                base::nrow(),
              base::nrow(data_links_chunk)
            )
          )

          DBI::dbCommit(con_out)

          tibble::tibble(chunk = .x, n_links = base::nrow(data_links_chunk))
        }
      }
    )

  data_link_chunks <-
    list_link_chunks |>
    dplyr::bind_rows()

  # All links of the output, including chunks of an earlier session
  n_links_total <-
    if (
      name_engine == "r_memory"
    ) {
      base::nrow(data_link_chunks)
    } else {
      DBI::dbGetQuery(con_out, "SELECT count(*) AS n FROM PositionLink") |>
        dplyr::pull(n)
    }

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
        n_rows = n_links_total
      )
    )

  time_step_start <-
    base::Sys.time()

  # Linked gridpoints and their bio1 values (age 0)
  vec_gridpoint_ids <-
    if (
      name_engine == "r_memory"
    ) {
      data_link_chunks |>
        dplyr::pull(gridpoint_id) |>
        base::unique() |>
        base::sort()
    } else {
      DBI::dbGetQuery(
        con_out,
        "SELECT DISTINCT gridpoint_id FROM PositionLink ORDER BY 1"
      ) |>
        dplyr::pull(gridpoint_id)
    }

  data_gridpoints <-
    tibble::tibble(gridpoint_id = vec_gridpoint_ids) |>
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
    )

  data_gridpoints_out <-
    data_gridpoints |>
    dplyr::transmute(
      gridpoint_id,
      coord_long = grid_long,
      coord_lat = grid_lat,
      age = base::as.integer(grid_age)
    )

  data_gridpoint_values <-
    data_gridpoints |>
    dplyr::filter(grid_age == 0, !base::is.na(bio1_value)) |>
    dplyr::transmute(
      gridpoint_id,
      abiotic_variable_id = value_bio1_id,
      abiotic_value = bio1_value
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

  time_step_start <-
    base::Sys.time()
}


#----------------------------------------------------------#
# 2. r_memory: read the copies and write everything at once -----
#----------------------------------------------------------#

if (
  name_engine == "r_memory"
) {
  list_copies <-
    data_copies |>
    dplyr::pull(sql_select) |>
    rlang::set_names(data_copies |> dplyr::pull(table_name)) |>
    purrr::map(
      .f = ~ DBI::dbGetQuery(
        con_src,
        stringr::str_replace_all(.x, "<SRC>", "")
      )
    )

  DBI::dbDisconnect(con_src)

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "read_copies",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = list_copies |>
          purrr::map_int(.f = base::nrow) |>
          base::sum()
      ),
      # Memory held in R, for the extrapolation: bytes of the links and of
      #   the copied tables (seconds is empty, n_rows holds the bytes)
      tibble::tibble(
        step = "bytes_links_in_r",
        seconds = NA_real_,
        n_rows = utils::object.size(data_link_chunks) |>
          base::as.numeric()
      ),
      tibble::tibble(
        step = "bytes_copies_in_r",
        seconds = NA_real_,
        n_rows = utils::object.size(list_copies) |>
          base::as.numeric()
      )
    )

  time_step_start <-
    base::Sys.time()

  assertthat::assert_that(
    !base::file.exists(path_db_out),
    msg = "The output file exists already."
  )

  con_out <-
    DBI::dbConnect(RSQLite::SQLite(), path_db_out)

  DBI::dbGetQuery(con_out, "PRAGMA journal_mode = OFF")

  DBI::dbExecute(con_out, "PRAGMA synchronous = OFF")

  DBI::dbExecute(con_out, "PRAGMA cache_size = -1048576")

  purrr::walk(
    .x = vec_table_sql,
    .f = ~ DBI::dbExecute(con_out, .x)
  )

  DBI::dbBegin(con_out)

  purrr::iwalk(
    .x = c(
      list(
        Positions = data_positions,
        SamplePosition = data_sample_position,
        PositionLink = data_link_chunks |>
          dplyr::arrange(position_id, gridpoint_id),
        Gridpoints = data_gridpoints_out,
        GridpointValues = data_gridpoint_values
      ),
      list_copies
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
        n_rows = base::nrow(data_link_chunks)
      )
    )

  time_step_start <-
    base::Sys.time()
}


#----------------------------------------------------------#
# 3. sqlite_incremental: gridpoints, values and copies -----
#----------------------------------------------------------#

if (
  name_engine == "sqlite_incremental"
) {
  DBI::dbDisconnect(con_src)

  DBI::dbExecute(
    con_out,
    "ATTACH DATABASE ? AS src",
    params = list(uri_subset)
  )

  # Each step is one transaction, recorded in BuildSteps
  data_late_steps <-
    dplyr::bind_rows(
      tibble::tibble(
        step = "gridpoints",
        table_name = "Gridpoints",
        sql_select = NA_character_
      ),
      tibble::tibble(
        step = "gridpoint_values",
        table_name = "GridpointValues",
        sql_select = NA_character_
      ),
      data_copies |>
        dplyr::transmute(
          step = stringr::str_c("copy_", table_name),
          table_name,
          sql_select = stringr::str_replace_all(sql_select, "<SRC>", "src.")
        )
    ) |>
    dplyr::left_join(
      data_table_columns |> dplyr::select(table_name, text_columns),
      by = "table_name"
    )

  vec_steps_done <-
    DBI::dbGetQuery(con_out, "SELECT step FROM BuildSteps") |>
    dplyr::pull(step)

  data_late_steps |>
    dplyr::filter(!step %in% vec_steps_done) |>
    dplyr::select(step, table_name, sql_select, text_columns) |>
    purrr::pwalk(
      .f = ~ {
        DBI::dbBegin(con_out)

        n_rows_step <-
          if (
            ..1 == "gridpoints"
          ) {
            DBI::dbAppendTable(con_out, "Gridpoints", data_gridpoints_out)
          } else if (
            ..1 == "gridpoint_values"
          ) {
            DBI::dbAppendTable(
              con_out, "GridpointValues", data_gridpoint_values
            )
          } else {
            DBI::dbExecute(
              con_out,
              stringr::str_c(
                "INSERT INTO main.\"", ..2, "\" (", ..4, ") ", ..3
              )
            )
          }

        DBI::dbExecute(
          con_out,
          "INSERT INTO BuildSteps (step, n_rows) VALUES (?, ?)",
          params = list(..1, n_rows_step)
        )

        DBI::dbCommit(con_out)
      }
    )

  DBI::dbExecute(con_out, "DETACH DATABASE src")

  # One file again: the WAL is written back and the rollback journal used
  DBI::dbGetQuery(con_out, "PRAGMA wal_checkpoint(TRUNCATE)")

  DBI::dbGetQuery(con_out, "PRAGMA journal_mode = DELETE")

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "write_late_steps",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = base::nrow(data_late_steps)
      )
    )

  time_step_start <-
    base::Sys.time()
}


#----------------------------------------------------------#
# 4. duckdb: everything in DuckDB SQL -----
#----------------------------------------------------------#

if (
  name_engine == "duckdb"
) {
  base::.libPaths(
    c(
      here::here("Data/Temp/Database_research/R_library"),
      base::.libPaths()
    )
  )

  path_duckdb_file <-
    base::file.path(path_run, stringr::str_c(name_label, ".duckdb"))

  path_extension_dir <-
    here::here(purrr::chuck(list_settings_engines, "duckdb_extension_dir")) |>
    base::normalizePath(winslash = "/", mustWork = TRUE)

  n_duckdb_threads <-
    dplyr::if_else(
      n_duckdb_threads_arg > 0L,
      n_duckdb_threads_arg,
      base::as.integer(
        purrr::chuck(list_settings_engines, "duckdb_threads")
      )
    )

  # The extension folder is set below, so the temporary home is accepted
  con_duck <-
    DBI::dbConnect(
      duckdb::duckdb(dbdir = path_duckdb_file, shared_home = FALSE)
    )

  DBI::dbExecute(
    con_duck,
    stringr::str_c("SET extension_directory = '", path_extension_dir, "'")
  )

  DBI::dbExecute(
    con_duck,
    stringr::str_c("SET threads = ", n_duckdb_threads)
  )

  DBI::dbExecute(
    con_duck,
    stringr::str_c(
      "SET memory_limit = '",
      purrr::chuck(list_settings_engines, "duckdb_memory_limit"),
      "'"
    )
  )

  DBI::dbExecute(con_duck, "LOAD spatial")

  DBI::dbExecute(con_duck, "LOAD sqlite")

  # DuckDB 2.0 needs the axis order set; points are (longitude, latitude)
  DBI::dbExecute(con_duck, "SET geometry_always_xy = true")

  DBI::dbExecute(
    con_duck,
    stringr::str_c(
      "ATTACH '", path_subset, "' AS src (TYPE sqlite, READ_ONLY)"
    )
  )

  # Each step: a name and its statements; the last statement's table is
  #   counted
  data_duck_steps <-
    tibble::tribble(
      ~step, ~sql, ~table_counted,
      "read_samples",
      list(
        stringr::str_c(
          "CREATE TABLE sample_source AS ",
          stringr::str_replace_all(sql_sample_source, "<SRC>", "src.")
        )
      ),
      "sample_source",
      "positions",
      list(
        stringr::str_c(
          "CREATE TABLE positions AS SELECT CAST(row_number() OVER ",
          "(ORDER BY coord_long, coord_lat, age) AS INTEGER) AS position_id, ",
          "coord_long, coord_lat, age FROM (SELECT DISTINCT coord_long, ",
          "coord_lat, age FROM sample_source)"
        ),
        stringr::str_c(
          "CREATE TABLE sample_position AS SELECT s.sample_id, ",
          "p.position_id FROM sample_source AS s JOIN positions AS p ",
          "ON p.coord_long = s.coord_long AND p.coord_lat = s.coord_lat ",
          "AND p.age = s.age"
        )
      ),
      "positions",
      "links",
      list(
        stringr::str_c(
          "CREATE TABLE search_windows AS WITH w AS (SELECT position_id, ",
          "coord_long, coord_lat, age, ",
          "coord_lat - ", value_dlat_deg, " AS lat_lo, ",
          "coord_lat + ", value_dlat_deg, " AS lat_hi, ",
          "sin(", value_delta_rad, ") / cos(radians(least(abs(coord_lat) + ",
          value_dlat_deg, ", 90))) AS ratio_lon FROM positions), ",
          "v AS (SELECT *, CASE WHEN ratio_lon >= 1 THEN 180 ELSE ",
          "degrees(asin(least(ratio_lon, 1))) + ", value_margin_deg,
          " END AS dlon FROM w) ",
          "SELECT position_id, coord_long, coord_lat, age, lat_lo, lat_hi, ",
          "CASE WHEN dlon >= 180 THEN -180 ELSE greatest(coord_long - dlon, ",
          "-180) END AS lon_lo, CASE WHEN dlon >= 180 THEN 180 ELSE ",
          "least(coord_long + dlon, 180) END AS lon_hi FROM v ",
          "UNION ALL SELECT position_id, coord_long, coord_lat, age, ",
          "lat_lo, lat_hi, coord_long - dlon + 360, 180 FROM v ",
          "WHERE dlon < 180 AND coord_long - dlon < -180 ",
          "UNION ALL SELECT position_id, coord_long, coord_lat, age, ",
          "lat_lo, lat_hi, -180, coord_long + dlon - 360 FROM v ",
          "WHERE dlon < 180 AND coord_long + dlon > 180"
        ),
        # Each window is listed once per 1-degree longitude bin it covers,
        #   so that the join to the cells has an equality to work with
        stringr::str_c(
          "CREATE TABLE window_bins AS SELECT *, unnest(range(",
          "CAST(floor(lon_lo) AS BIGINT), CAST(floor(lon_hi) AS BIGINT) ",
          "+ 1)) AS lon_bin FROM search_windows"
        ),
        stringr::str_c(
          "CREATE TABLE pairs AS SELECT DISTINCT w.position_id, w.age, ",
          "c.cell_index, ST_Distance_Spheroid(ST_Point(w.coord_long, ",
          "w.coord_lat), ST_Point(c.grid_long, c.grid_lat)) AS ",
          "distance_in_m FROM window_bins AS w JOIN cells AS c ",
          "ON c.lon_bin = w.lon_bin ",
          "AND c.grid_lat BETWEEN w.lat_lo AND w.lat_hi ",
          "AND c.grid_long BETWEEN w.lon_lo AND w.lon_hi"
        ),
        stringr::str_c(
          "CREATE TABLE links AS SELECT p.position_id, ",
          "CAST((p.cell_index - 1) * ", n_ages, " + a.age_index AS INTEGER) ",
          "AS gridpoint_id, CAST(floor(p.distance_in_m / 1000) AS INTEGER) ",
          "AS distance_in_km, CAST(trunc(abs(p.age - a.grid_age)) AS ",
          "INTEGER) AS distance_in_years FROM pairs AS p JOIN ages AS a ",
          "ON abs(p.age - a.grid_age) <= ", value_distance_years, " ",
          "WHERE p.distance_in_m <= ", value_distance_km * 1000
        )
      ),
      "links",
      "gridpoints",
      list(
        stringr::str_c(
          "CREATE TABLE gridpoints AS SELECT g.gridpoint_id, ",
          "c.grid_long AS coord_long, c.grid_lat AS coord_lat, ",
          "CAST(a.grid_age AS INTEGER) AS age, c.bio1_value FROM ",
          "(SELECT DISTINCT gridpoint_id FROM links) AS g ",
          "JOIN cells AS c ON c.cell_index = (g.gridpoint_id - 1) // ",
          n_ages, " + 1 JOIN ages AS a ON a.age_index = ",
          "(g.gridpoint_id - 1) % ", n_ages, " + 1"
        ),
        stringr::str_c(
          "CREATE TABLE gridpoint_values AS SELECT gridpoint_id, ",
          value_bio1_id, " AS abiotic_variable_id, bio1_value AS ",
          "abiotic_value FROM gridpoints WHERE age = 0 AND bio1_value ",
          "IS NOT NULL"
        )
      ),
      "gridpoints"
    )

  # The R inputs, as DuckDB tables
  duckdb::duckdb_register(con_duck, "cells_r", data_cells)

  duckdb::duckdb_register(con_duck, "ages_r", data_ages)

  DBI::dbExecute(
    con_duck,
    stringr::str_c(
      "CREATE TABLE cells AS SELECT *, ",
      "CAST(floor(grid_long) AS BIGINT) AS lon_bin FROM cells_r"
    )
  )

  DBI::dbExecute(con_duck, "CREATE TABLE ages AS SELECT * FROM ages_r")

  duckdb::duckdb_unregister(con_duck, "cells_r")

  duckdb::duckdb_unregister(con_duck, "ages_r")

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      tibble::tibble(
        step = "read_inputs",
        seconds = base::difftime(
          base::Sys.time(), time_step_start,
          units = "secs"
        ) |>
          base::as.numeric(),
        n_rows = base::nrow(data_cells)
      )
    )

  time_step_start <-
    base::Sys.time()

  data_step_log <-
    data_step_log |>
    dplyr::bind_rows(
      data_duck_steps |>
        dplyr::mutate(
          result = purrr::pmap(
            .l = list(sql, table_counted),
            .f = ~ {
              time_duck_start <-
                base::Sys.time()

              purrr::walk(
                .x = ..1,
                .f = ~ DBI::dbExecute(con_duck, .x)
              )

              tibble::tibble(
                seconds = base::difftime(
                  base::Sys.time(), time_duck_start,
                  units = "secs"
                ) |>
                  base::as.numeric(),
                n_rows = DBI::dbGetQuery(
                  con_duck,
                  stringr::str_c("SELECT count(*) AS n FROM ", ..2)
                ) |>
                  dplyr::pull(n) |>
                  base::as.numeric()
              )
            }
          )
        ) |>
        tidyr::unnest(result) |>
        dplyr::select(step, seconds, n_rows)
    )

  time_step_start <-
    base::Sys.time()

  # The SQLite schema is created by RSQLite; DuckDB fills it
  assertthat::assert_that(
    !base::file.exists(path_db_out),
    msg = "The output file exists already."
  )

  con_out_create <-
    DBI::dbConnect(RSQLite::SQLite(), path_db_out)

  purrr::walk(
    .x = vec_table_sql,
    .f = ~ DBI::dbExecute(con_out_create, .x)
  )

  DBI::dbDisconnect(con_out_create)

  DBI::dbExecute(
    con_duck,
    stringr::str_c("ATTACH '", path_db_out, "' AS out (TYPE sqlite)")
  )

  data_duck_inserts <-
    dplyr::bind_rows(
      tibble::tribble(
        ~table_name, ~sql_from,
        "Positions", "positions",
        "SamplePosition", "sample_position",
        "PositionLink", "links",
        "Gridpoints", "gridpoints",
        "GridpointValues", "gridpoint_values"
      ) |>
        dplyr::left_join(data_table_columns, by = "table_name") |>
        dplyr::mutate(
          sql_select = stringr::str_c(
            "SELECT ", text_columns, " FROM ", sql_from,
            " ORDER BY ", text_key
          )
        ),
      data_copies |>
        dplyr::mutate(
          sql_select = stringr::str_replace_all(sql_select, "<SRC>", "src.")
        )
    ) |>
    dplyr::mutate(
      sql_insert = stringr::str_c(
        "INSERT INTO out.\"", table_name, "\" (", text_columns, ") ",
        sql_select
      )
    )

  purrr::walk(
    .x = data_duck_inserts |> dplyr::pull(sql_insert),
    .f = ~ DBI::dbExecute(con_duck, .x)
  )

  DBI::dbExecute(con_duck, "DETACH out")

  n_duck_links <-
    DBI::dbGetQuery(con_duck, "SELECT count(*) AS n FROM links") |>
    dplyr::pull(n)

  DBI::dbDisconnect(con_duck, shutdown = TRUE)

  value_duckdb_file_mb <-
    base::file.size(path_duckdb_file) / 1e6

  base::unlink(
    c(path_duckdb_file, stringr::str_c(path_duckdb_file, ".wal"))
  )

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
        n_rows = base::as.numeric(n_duck_links)
      ),
      tibble::tibble(
        step = "duckdb_file_mb",
        seconds = NA_real_,
        n_rows = value_duckdb_file_mb
      )
    )

  time_step_start <-
    base::Sys.time()

  con_out <-
    DBI::dbConnect(RSQLite::SQLite(), path_db_out)
}


#----------------------------------------------------------#
# 5. Indexes and ANALYZE, through RSQLite -----
#----------------------------------------------------------#

purrr::walk(
  .x = vec_index_sql,
  .f = ~ DBI::dbExecute(con_out, .x)
)

data_step_log <-
  data_step_log |>
  dplyr::bind_rows(
    tibble::tibble(
      step = "indexes",
      seconds = base::difftime(
        base::Sys.time(), time_step_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      n_rows = base::length(vec_index_sql)
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


#----------------------------------------------------------#
# 6. Logs -----
#----------------------------------------------------------#

readr::write_csv(
  x = data_step_log |>
    dplyr::mutate(
      session = name_session,
      engine = name_engine,
      label = name_label,
      .before = 1L
    ),
  file = path_step_log,
  append = base::file.exists(path_step_log)
)

list_memory <-
  ps::ps_memory_info(ps::ps_handle())

readr::write_csv(
  x = tibble::tibble(
    session = name_session,
    engine = name_engine,
    label = name_label,
    peak_wset_mb = purrr::chuck(list_memory, "peak_wset") / 1e6,
    peak_pagefile_mb = purrr::chuck(list_memory, "peak_pagefile") / 1e6,
    file_mb = base::file.size(path_db_out) / 1e6
  ),
  file = path_memory_log,
  append = base::file.exists(path_memory_log)
)

cli::cli_inform("{name_label}: done.")
