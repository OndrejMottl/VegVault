#' @title Diagnose rows that nothing uses or that are linked wrongly
#' @description
#' Count the semantic orphans of a built VegVault database, read-only: rows
#' that satisfy every foreign key but are left without the rows that give
#' them meaning, and links to the wrong kind of sample.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check `orphans`, with
#' one row per scope, in this order. These fail when any row is found:
#' \itemize{
#'   \item `datasets_without_samples`: datasets with no `DatasetSample`
#'     row;
#'   \item `samples_without_dataset`: samples with no `DatasetSample` row;
#'   \item `positions_without_samples`: positions that no sample has;
#'   \item `gridpoints_with_position`: gridpoint samples in
#'     `SamplePosition` (gridpoints are linked to, never linked
#'     themselves);
#'   \item `links_to_other_samples`: position links whose reference sample
#'     is not a gridpoint sample.
#' }
#' These are flagged when any row is found:
#' \itemize{
#'   \item `linked_gridpoints_without_values`: gridpoint samples that a
#'     position links to but that have no abiotic value;
#'   \item `taxa_without_use`: taxa used by no sample, trait value or taxon
#'     classification;
#'   \item `abiotic_variables_without_values`: abiotic variables without
#'     a value.
#' }
#' Each row has the count as the observed value and 0 as the threshold.
#' @details
#' A gridpoint sample belongs to a dataset of type `gridpoints`. The first
#' five scopes describe the structure the assembly writes, so a row found
#' there is a build error. The last three can come from the producer data,
#' for example a masked cell, so they ask a reviewer for a judgement.
#' The statements are those of `build_orphan_statements()`; each reads
#' `PositionLink` at most once.
#' Opens the database read-only, once per scope. Aborts only when the
#' database is not the one of the manifest.
#' @examples
#' \dontrun{
#' diagnose_orphan_rows(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_orphan_rows <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_scopes <-
    build_orphan_statements()

  vec_counts <-
    purrr::map_int(
      .x = dplyr::pull(data_scopes, statement),
      .f = ~ run_with_database(
        path_database = path_database,
        fn = DBI::dbGetQuery,
        statement = .x,
        flag_read_only = TRUE
      ) |>
        dplyr::pull(1L) |>
        base::as.integer()
    )

  data_result <-
    data_scopes |>
    dplyr::mutate(
      n_found = vec_counts,
      status = dplyr::if_else(n_found == 0L, "pass", status_found),
      message = stringr::str_c(description, ": ", n_found, ".")
    )

  res <-
    build_check_result(
      check_id = "orphans",
      scope = dplyr::pull(data_result, scope),
      status = dplyr::pull(data_result, status),
      observed = dplyr::pull(data_result, n_found),
      threshold = 0L,
      message = dplyr::pull(data_result, message)
    )

  return(res)
}
