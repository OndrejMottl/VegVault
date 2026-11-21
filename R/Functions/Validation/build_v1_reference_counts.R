#' @title Build the reference counts of VegVault v1.0.0
#' @description
#' Collect the counts of the released v1.0.0 database that the validation
#' stage compares a build with, from the saved results of the read-only
#' scans of v1.0.0, so that no run of the stage opens the 110 GB file.
#' @param dir_scans
#' Character scalar. Folder of the scan results of the 2.0.0 database
#' research. Default:
#' `Documentation/Database_design_2.0.0_tables/q1_v1_content`.
#' @param path_scan_per_source
#' Character scalar. Path of the per-source counts of `SampleTaxa` and
#' `TraitsValue` (`R/Validation/count_v1_per_source.R`). Default:
#' `Data/Validation/v1.0.0_scan_per_source.csv`.
#' @return
#' A tibble with one row per metric and scope, in the order of the metrics
#' below and sorted by scope within each: `metric`, `scope`, `n_v1` (the
#' count, a double) and `source` (the file it comes from). The metrics:
#' \itemize{
#'   \item `table_rows`: rows per table, scope the table name (the largest
#'     row id, which equals the exact count for every table counted
#'     exactly);
#'   \item `datasets`, `samples`: per dataset type and source type, scope
#'     `<dataset type> / <source type>`;
#'   \item `positions`: distinct (longitude, latitude, age) of the samples
#'     that are not gridpoints, per source and for `all` sources;
#'   \item `sample_taxa_rows`, `traits_value_rows`: rows of `SampleTaxa`
#'     and `TraitsValue` per source;
#'   \item `abiotic_values`: rows of `AbioticData` per variable, scope the
#'     variable name.
#' }
#' @details
#' Dataset types, source types and variables are named with the v1.0.0
#' lookup tables of the same folder; a row without a dataset is
#' `(none) / (none)`. Aborts when a file or a column is missing.
#' @seealso [compute_database_counts()], [compute_v1_count_deltas()]
#' @examples
#' \dontrun{
#' build_v1_reference_counts()
#' }
build_v1_reference_counts <- function(
  dir_scans = here::here(
    "Documentation", "Database_design_2.0.0_tables", "q1_v1_content"
  ),
  path_scan_per_source = here::here(
    "Data", "Validation", "v1.0.0_scan_per_source.csv"
  )
) {
  assertthat::assert_that(
    assertthat::is.string(dir_scans),
    assertthat::is.string(path_scan_per_source),
    msg = "'dir_scans' and 'path_scan_per_source' must be character scalars."
  )

  vec_files <-
    c(
      rowid = "V1_metadata__rowid_bounds.csv",
      types = "V1_metadata__dataset_type.csv",
      sources = "V1_metadata__dataset_source_type.csv",
      variables = "V1_metadata__abiotic_variable.csv",
      datasets = "V1_full_scans__dataset_composition.csv",
      samples = "V1_full_scans__sample_composition.csv",
      positions = "V1_full_scans__tuples_per_source.csv",
      positions_all = "V1_full_scans__tuples_all_sources.csv",
      abiotic = "V1_full_scans__abiotic_values_per_variable.csv"
    )

  vec_paths <-
    rlang::set_names(
      base::file.path(dir_scans, vec_files),
      base::names(vec_files)
    )

  vec_missing <-
    c(
      vec_files[!base::file.exists(vec_paths)],
      base::basename(path_scan_per_source)[
        !base::file.exists(path_scan_per_source)
      ]
    )

  if (
    base::length(vec_missing) > 0L
  ) {
    cli::cli_abort("Scan result{?s} missing: {.file {vec_missing}}.")
  }

  list_data <-
    purrr::map(
      .x = vec_paths,
      .f = ~ readr::read_csv(.x, show_col_types = FALSE)
    )

  data_scan <-
    readr::read_csv(path_scan_per_source, show_col_types = FALSE)

  data_table_rows <-
    purrr::chuck(list_data, "rowid") |>
    dplyr::transmute(
      metric = "table_rows",
      scope = table_name,
      n_v1 = base::as.numeric(max_rowid),
      source = vec_files[["rowid"]]
    )

  # Counts per dataset type and source type, named with the v1 lookups
  data_per_source <-
    dplyr::bind_rows(
      purrr::chuck(list_data, "datasets") |>
        dplyr::transmute(
          metric = "datasets",
          dataset_type_id, data_source_type_id,
          n_v1 = base::as.numeric(n_datasets),
          source = vec_files[["datasets"]]
        ),
      purrr::chuck(list_data, "samples") |>
        dplyr::transmute(
          metric = "samples",
          dataset_type_id, data_source_type_id,
          n_v1 = base::as.numeric(n_samples),
          source = vec_files[["samples"]]
        ),
      purrr::chuck(list_data, "positions") |>
        dplyr::transmute(
          metric = "positions",
          dataset_type_id, data_source_type_id,
          n_v1 = base::as.numeric(n_tuples),
          source = vec_files[["positions"]]
        ),
      data_scan |>
        dplyr::transmute(
          metric,
          dataset_type_id, data_source_type_id,
          n_v1 = base::as.numeric(n_rows),
          source = base::basename(path_scan_per_source)
        )
    ) |>
    dplyr::left_join(
      purrr::chuck(list_data, "types"),
      by = dplyr::join_by(dataset_type_id)
    ) |>
    dplyr::left_join(
      purrr::chuck(list_data, "sources"),
      by = dplyr::join_by(data_source_type_id)
    ) |>
    dplyr::transmute(
      metric,
      scope = stringr::str_c(
        dplyr::coalesce(dataset_type, "(none)"), " / ",
        dplyr::coalesce(dataset_source_type, "(none)")
      ),
      n_v1,
      source
    )

  data_positions_all <-
    purrr::chuck(list_data, "positions_all") |>
    dplyr::transmute(
      metric = "positions",
      scope = "all",
      n_v1 = base::as.numeric(n_tuples),
      source = vec_files[["positions_all"]]
    )

  data_abiotic <-
    purrr::chuck(list_data, "abiotic") |>
    dplyr::left_join(
      purrr::chuck(list_data, "variables"),
      by = dplyr::join_by(abiotic_variable_id)
    ) |>
    dplyr::transmute(
      metric = "abiotic_values",
      scope = abiotic_variable_name,
      n_v1 = base::as.numeric(n_values),
      source = vec_files[["abiotic"]]
    )

  vec_metrics <-
    c(
      "table_rows", "datasets", "samples", "positions", "sample_taxa_rows",
      "traits_value_rows", "abiotic_values"
    )

  res <-
    dplyr::bind_rows(
      data_table_rows, data_per_source, data_positions_all, data_abiotic
    ) |>
    dplyr::arrange(base::match(metric, vec_metrics), scope)

  return(res)
}
