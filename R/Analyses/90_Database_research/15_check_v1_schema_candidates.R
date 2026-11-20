#----------------------------------------------------------#
#
#
#                       VegVault
#
#       Check the schema candidates against v1.0.0 content
#                 - read-only, temporary tables only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Measure on v1.0.0 what the schema prototypes of question 4 can only show
#   on the regional subset:
#   1. Positions: the distinct (coord_long, coord_lat, age) of the
#      non-gridpoint samples with coordinates and age, and the number of
#      links each position has (the links of its lowest sample id, counted
#      through the index on AbioticDataReference.sample_id). Their sum is
#      the size of the link table when links are stored once per position.
#   2. Link sets: for `n_draw_positions` positions with two or more samples,
#      drawn with `seed`, the links of up to `n_draw_samples` samples each
#      are compared; links per position are only lossless if all samples of
#      a position have the same links.
#   3. Duplicates and missing values of the composite keys of the junction
#      and value tables (all except AbioticDataReference, whose 2.07 G rows
#      are not grouped here), of sample and dataset names, and the
#      duplicated (sample, taxon) pairs of SampleTaxa by source.
#   4. Fractional ages per dataset type, coordinates outside -180 to 180
#      and -90 to 90 per source, and the stored values of
#      References.mandatory.
#   5. Gridpoint rows: the references, dataset columns and names that a
#      dedicated gridpoint table would replace.
# v1.0.0 is opened read-only (`SQLITE_RO`); temporary tables live in the
#   temporary store, not next to the file. The file size, modification
#   time and header are compared before and after, and no journal, WAL or
#   SHM file may appear. The path is never printed. Each run writes a new
#   folder `run_<timestamp>` under `V1_schema_checks`.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/15_check_v1_schema_candidates.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

list_settings_checks <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("v1_schema_checks")

time_run_start <-
  base::Sys.time()

path_output <-
  here::here(
    "Data", "Temp", "Database_research", "V1_schema_checks",
    stringr::str_c("run_", base::format(time_run_start, "%Y%m%d_%H%M%S"))
  )

assertthat::assert_that(
  !base::dir.exists(path_output),
  msg = "The run folder exists already."
)

base::dir.create(path = path_output, recursive = TRUE)

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

# Connection page cache in KiB (negative value); 4 GiB of the 64 GiB RAM
value_cache_size_kib <- -4194304

assertthat::assert_that(
  base::file.exists(path_to_vegvault),
  msg = "The database file named in the secrets file does not exist."
)

# The id of the gridpoint dataset type, looked up in every query
sql_gridpoint_type <-
  stringr::str_c(
    "(SELECT dataset_type_id FROM DatasetTypeID ",
    "WHERE dataset_type = 'gridpoints')"
  )

# The composite keys of the WITHOUT ROWID prototype and the natural keys;
#   AbioticDataReference is left out (2.07 G rows)
data_keys <-
  tibble::tribble(
    ~table_name, ~key_columns,
    "DatasetSample", "dataset_id, sample_id",
    "SampleTaxa", "sample_id, taxon_id",
    "SampleReference", "sample_id, reference_id",
    "SampleUncertainty", "sample_id, iteration",
    "AbioticData", "sample_id, abiotic_variable_id",
    "TraitsValue", "trait_id, dataset_id, sample_id, taxon_id",
    "TaxonClassification", "taxon_id",
    "DatasetReferences", "dataset_id, reference_id",
    "DatasetSourceTypeReference", "data_source_type_id, reference_id",
    "DatasetSourcesReference", "data_source_id, reference_id",
    "SamplingMethodReference", "sampling_method_id, reference_id",
    "TaxonReference", "taxon_id, reference_id",
    "TraitsReference", "trait_id, reference_id",
    "AbioticVariableReference", "abiotic_variable_id, reference_id",
    "Samples", "sample_name",
    "Datasets", "dataset_name"
  ) |>
  dplyr::mutate(
    text_null = stringr::str_split(key_columns, ", ") |>
      purrr::map_chr(
        .f = ~ stringr::str_c(.x, " IS NULL", collapse = " OR ")
      ),
    sql_one = stringr::str_c(
      "SELECT '", table_name, "' AS table_name, '", key_columns,
      "' AS key_columns, ",
      "(SELECT count(*) FROM \"", table_name, "\") AS n_rows, ",
      "g.n_dup_keys, g.n_dup_rows, ",
      "(SELECT count(*) FROM \"", table_name, "\" WHERE ", text_null,
      ") AS n_null_key ",
      "FROM (SELECT count(*) AS n_dup_keys, coalesce(sum(n), 0) AS ",
      "n_dup_rows FROM (SELECT count(*) AS n FROM \"", table_name,
      "\" GROUP BY ", key_columns, " HAVING count(*) > 1)) AS g"
    )
  )

sql_key_duplicates <-
  data_keys |>
  dplyr::pull(sql_one) |>
  stringr::str_c(collapse = " UNION ALL ")


#----------------------------------------------------------#
# 1. Record the file state before reading -----
#----------------------------------------------------------#

vec_header_raw_before <-
  base::readBin(con = path_to_vegvault, what = "raw", n = 100L)

size_bytes_before <-
  base::file.size(path_to_vegvault)

mtime_before <-
  base::file.mtime(path_to_vegvault)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(
      base::file.exists(
        stringr::str_c(path_to_vegvault, vec_sibling_suffix)
      )
    )
) {
  cli::cli_abort(
    c(
      "The database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}


#----------------------------------------------------------#
# 2. Run the checks -----
#----------------------------------------------------------#

con_v1 <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_to_vegvault,
    flags = RSQLite::SQLITE_RO
  )

data_step_seconds <-
  base::tryCatch(
    expr = {
      DBI::dbExecute(
        con_v1,
        stringr::str_c("PRAGMA cache_size = ", value_cache_size_kib)
      )

      # Each step runs one statement: a `CREATE TEMP TABLE`, or a query
      #   whose result is saved as <step>.csv
      data_steps <-
        tibble::tribble(
          ~step, ~sql,
          "sample_positions",
          stringr::str_c(
            "CREATE TEMP TABLE tmp_sample_position AS ",
            "SELECT s.sample_id, d.coord_long, d.coord_lat, s.age, ",
            "d.data_source_type_id ",
            "FROM Samples AS s ",
            "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
            "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
            "WHERE d.dataset_type_id != ", sql_gridpoint_type, " ",
            "AND d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL ",
            "AND s.age IS NOT NULL"
          ),
          "positions",
          stringr::str_c(
            "CREATE TEMP TABLE tmp_position AS ",
            "SELECT coord_long, coord_lat, age, ",
            "min(sample_id) AS sample_id, count(*) AS n_samples ",
            "FROM temp.tmp_sample_position ",
            "GROUP BY coord_long, coord_lat, age"
          ),
          "position_link_counts",
          stringr::str_c(
            "SELECT n_links, count(*) AS n_positions FROM (",
            "SELECT p.sample_id, (SELECT count(*) FROM AbioticDataReference ",
            "AS l WHERE l.sample_id = p.sample_id) AS n_links ",
            "FROM temp.tmp_position AS p) GROUP BY n_links ORDER BY n_links"
          ),
          "position_sizes",
          stringr::str_c(
            "SELECT n_samples, count(*) AS n_positions ",
            "FROM temp.tmp_position GROUP BY n_samples ORDER BY n_samples"
          ),
          "key_duplicates",
          sql_key_duplicates,
          "sample_taxa_duplicates_by_source",
          stringr::str_c(
            "SELECT d.data_source_type_id, count(*) AS n_dup_keys, ",
            "sum(k.n) AS n_dup_rows, ",
            "sum(k.n_values) AS n_distinct_values ",
            "FROM (SELECT sample_id, taxon_id, count(*) AS n, ",
            "count(DISTINCT value) AS n_values FROM SampleTaxa ",
            "GROUP BY sample_id, taxon_id HAVING count(*) > 1) AS k ",
            "JOIN DatasetSample AS ds ON ds.sample_id = k.sample_id ",
            "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
            "GROUP BY d.data_source_type_id"
          ),
          "ages_by_dataset_type",
          stringr::str_c(
            "SELECT d.dataset_type_id, typeof(s.age) AS age_type, ",
            "count(*) AS n_samples, ",
            "sum(s.age != CAST(s.age AS INTEGER)) AS n_fractional, ",
            "min(s.age) AS age_min, max(s.age) AS age_max ",
            "FROM Samples AS s ",
            "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
            "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
            "GROUP BY d.dataset_type_id, typeof(s.age)"
          ),
          "coordinates_out_of_range",
          stringr::str_c(
            "SELECT data_source_type_id, count(*) AS n_datasets, ",
            "sum(coord_long IS NULL OR coord_lat IS NULL) AS n_missing, ",
            "sum(coord_long NOT BETWEEN -180 AND 180 OR ",
            "coord_lat NOT BETWEEN -90 AND 90) AS n_out_of_range ",
            "FROM Datasets GROUP BY data_source_type_id"
          ),
          "mandatory_values",
          stringr::str_c(
            "SELECT typeof(mandatory) AS value_type, mandatory, ",
            "count(*) AS n FROM \"References\" GROUP BY 1, 2"
          ),
          "gridpoint_references",
          stringr::str_c(
            "SELECT 'SampleReference' AS table_name, ",
            "count(*) AS n_gridpoint_rows, ",
            "count(DISTINCT reference_id) AS n_references, ",
            "(SELECT count(*) FROM SampleReference) AS n_rows ",
            "FROM SampleReference WHERE sample_id IN (",
            "SELECT ds.sample_id FROM DatasetSample AS ds ",
            "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
            "WHERE d.dataset_type_id = ", sql_gridpoint_type, ") ",
            "UNION ALL ",
            "SELECT 'DatasetReferences', count(*), ",
            "count(DISTINCT reference_id), ",
            "(SELECT count(*) FROM DatasetReferences) ",
            "FROM DatasetReferences WHERE dataset_id IN (",
            "SELECT dataset_id FROM Datasets ",
            "WHERE dataset_type_id = ", sql_gridpoint_type, ")"
          ),
          "gridpoint_columns",
          stringr::str_c(
            "SELECT d.data_source_id, d.data_source_type_id, ",
            "d.sampling_method_id, s.sample_details IS NULL AS details_null, ",
            "s.sample_size_id, count(*) AS n_samples, ",
            "count(DISTINCT d.dataset_id) AS n_datasets, ",
            "sum(d.dataset_name != 'geo_' || d.coord_long || '_' || ",
            "d.coord_lat) AS n_dataset_name_not_derivable, ",
            "sum(s.sample_name != d.dataset_name || '_' || ",
            "CAST(s.age AS INTEGER)) AS n_sample_name_not_derivable, ",
            "sum(s.age != CAST(s.age AS INTEGER)) AS n_fractional_age ",
            "FROM Samples AS s ",
            "JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id ",
            "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id ",
            "WHERE d.dataset_type_id = ", sql_gridpoint_type, " ",
            "GROUP BY 1, 2, 3, 4, 5"
          )
        )

      data_step_seconds_now <-
        data_steps |>
        dplyr::mutate(
          seconds = purrr::map2_dbl(
            .x = step,
            .y = sql,
            .f = ~ {
              # cli templates cannot start with a dot
              name_step <- .x

              cli::cli_inform("Running {name_step}.")

              time_step_start <-
                base::Sys.time()

              if (
                stringr::str_detect(.y, "^CREATE TEMP TABLE")
              ) {
                DBI::dbExecute(con_v1, .y)
              } else {
                DBI::dbGetQuery(con_v1, .y) |>
                  tibble::as_tibble() |>
                  readr::write_csv(
                    file = base::file.path(
                      path_output,
                      stringr::str_c(.x, ".csv")
                    )
                  )
              }

              base::difftime(
                base::Sys.time(),
                time_step_start,
                units = "secs"
              ) |>
                base::as.numeric()
            }
          )
        ) |>
        dplyr::select(step, seconds)

      # Link sets of drawn positions with two or more samples
      cli::cli_inform("Drawing positions to compare link sets.")

      time_draw_start <-
        base::Sys.time()

      data_multi_positions <-
        DBI::dbGetQuery(
          con_v1,
          stringr::str_c(
            "SELECT coord_long, coord_lat, age, n_samples ",
            "FROM temp.tmp_position WHERE n_samples >= 2 ",
            "ORDER BY coord_long, coord_lat, age"
          )
        ) |>
        tibble::as_tibble()

      base::set.seed(purrr::chuck(list_settings_checks, "seed"))

      data_draw_positions <-
        data_multi_positions |>
        dplyr::slice_sample(
          n = base::min(
            purrr::chuck(list_settings_checks, "n_draw_positions"),
            base::nrow(data_multi_positions)
          )
        ) |>
        dplyr::mutate(position = dplyr::row_number())

      DBI::dbWriteTable(
        conn = con_v1,
        name = "tmp_draw_position",
        value = data_draw_positions,
        temporary = TRUE
      )

      data_draw_samples <-
        DBI::dbGetQuery(
          con_v1,
          stringr::str_c(
            "SELECT d.position, t.sample_id, t.data_source_type_id ",
            "FROM temp.tmp_sample_position AS t ",
            "JOIN temp.tmp_draw_position AS d ",
            "ON d.coord_long = t.coord_long AND d.coord_lat = t.coord_lat ",
            "AND d.age = t.age ORDER BY d.position, t.sample_id"
          )
        ) |>
        tibble::as_tibble() |>
        dplyr::slice_sample(
          n = purrr::chuck(list_settings_checks, "n_draw_samples"),
          by = position
        )

      DBI::dbWriteTable(
        conn = con_v1,
        name = "tmp_draw_sample",
        value = data_draw_samples,
        temporary = TRUE
      )

      data_draw_links <-
        DBI::dbGetQuery(
          con_v1,
          stringr::str_c(
            "SELECT s.position, s.sample_id, l.sample_ref_id, ",
            "l.distance_in_km, l.distance_in_years ",
            "FROM temp.tmp_draw_sample AS s ",
            "LEFT JOIN AbioticDataReference AS l ",
            "ON l.sample_id = s.sample_id"
          )
        ) |>
        tibble::as_tibble()

      # One fingerprint per sample of its sorted links; a sample without
      #   links has the fingerprint of an empty set
      data_draw_result <-
        data_draw_links |>
        dplyr::arrange(position, sample_id, sample_ref_id) |>
        dplyr::summarise(
          n_links = base::sum(!base::is.na(sample_ref_id)),
          text_links = stringr::str_c(
            sample_ref_id, distance_in_km, distance_in_years,
            sep = ":", collapse = ";"
          ),
          .by = c(position, sample_id)
        ) |>
        dplyr::summarise(
          n_samples_compared = dplyr::n(),
          n_link_sets = dplyr::n_distinct(text_links),
          n_links_min = base::min(n_links),
          n_links_max = base::max(n_links),
          .by = position
        ) |>
        dplyr::left_join(
          data_draw_samples |>
            dplyr::distinct(position, data_source_type_id),
          by = "position",
          relationship = "one-to-many"
        )

      readr::write_csv(
        x = data_draw_result,
        file = base::file.path(path_output, "link_set_draw.csv")
      )

      readr::write_csv(
        x = data_draw_result |>
          dplyr::distinct(
            position, n_samples_compared, n_link_sets
          ) |>
          dplyr::summarise(
            n_positions_drawn = dplyr::n(),
            n_positions_multi = base::nrow(data_multi_positions),
            n_samples_compared = base::sum(n_samples_compared),
            n_positions_one_link_set = base::sum(n_link_sets == 1L)
          ),
        file = base::file.path(path_output, "link_set_draw_summary.csv")
      )

      data_step_seconds_now |>
        dplyr::bind_rows(
          tibble::tibble(
            step = "link_set_draw",
            seconds = base::difftime(
              base::Sys.time(),
              time_draw_start,
              units = "secs"
            ) |>
              base::as.numeric()
          )
        )
    },
    finally = DBI::dbDisconnect(con_v1)
  )

readr::write_csv(
  x = data_step_seconds,
  file = base::file.path(path_output, "step_seconds.csv")
)


#----------------------------------------------------------#
# 3. Check that the file was not changed -----
#----------------------------------------------------------#

flag_file_unchanged <-
  base::isTRUE(
    base::file.size(path_to_vegvault) == size_bytes_before &&
      base::file.mtime(path_to_vegvault) == mtime_before &&
      base::identical(
        vec_header_raw_before,
        base::readBin(con = path_to_vegvault, what = "raw", n = 100L)
      ) &&
      !base::any(
        base::file.exists(
          stringr::str_c(path_to_vegvault, vec_sibling_suffix)
        )
      )
  )

readr::write_csv(
  x = tibble::tibble(
    script = "15_check_v1_schema_candidates.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    connection_flags = "RSQLite SQLITE_RO; temporary tables only",
    seed = purrr::chuck(list_settings_checks, "seed"),
    file_unchanged = flag_file_unchanged
  ),
  file = base::file.path(path_output, "run_info.csv")
)

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort(
    "The database file differs after the read-only session."
  )
}

cli::cli_inform(
  c(
    "v" = "Read-only checks finished; the file is unchanged.",
    "i" = "Results saved to {.path {path_output}}."
  )
)
