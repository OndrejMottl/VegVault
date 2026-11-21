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

  # Gridpoint samples, as a subquery; SQLite builds it once per statement
  sql_gridpoint_samples <-
    base::paste(
      "SELECT ds.sample_id FROM DatasetSample AS ds",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      "JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
      "WHERE t.dataset_type = 'gridpoints'"
    )

  data_scopes <-
    tibble::tribble(
      ~scope, ~status_found, ~statement, ~description,
      "datasets_without_samples", "fail",
      base::paste(
        "SELECT COUNT(*) FROM Datasets WHERE dataset_id NOT IN",
        "(SELECT dataset_id FROM DatasetSample)"
      ),
      "Datasets without a sample",
      "samples_without_dataset", "fail",
      base::paste(
        "SELECT COUNT(*) FROM Samples WHERE sample_id NOT IN",
        "(SELECT sample_id FROM DatasetSample)"
      ),
      "Samples without a dataset",
      "positions_without_samples", "fail",
      base::paste(
        "SELECT COUNT(*) FROM Positions WHERE position_id NOT IN",
        "(SELECT position_id FROM SamplePosition)"
      ),
      "Positions without a sample",
      "gridpoints_with_position", "fail",
      base::paste(
        "SELECT COUNT(*) FROM SamplePosition WHERE sample_id IN (",
        sql_gridpoint_samples, ")"
      ),
      "Gridpoint samples with a position of their own",
      "links_to_other_samples", "fail",
      base::paste(
        "SELECT COUNT(*) FROM PositionLink WHERE sample_ref_id NOT IN (",
        sql_gridpoint_samples, ")"
      ),
      "Position links to a sample that is not a gridpoint",
      "linked_gridpoints_without_values", "flag",
      base::paste(
        "SELECT COUNT(*) FROM (SELECT DISTINCT sample_ref_id FROM",
        "PositionLink) WHERE sample_ref_id NOT IN",
        "(SELECT sample_id FROM AbioticData) AND sample_ref_id IN (",
        sql_gridpoint_samples, ")"
      ),
      "Linked gridpoint samples without an abiotic value",
      "taxa_without_use", "flag",
      base::paste(
        "SELECT COUNT(*) FROM Taxa WHERE",
        "taxon_id NOT IN (SELECT taxon_id FROM SampleTaxa",
        "WHERE taxon_id IS NOT NULL) AND",
        "taxon_id NOT IN (SELECT taxon_id FROM TraitsValue) AND",
        "taxon_id NOT IN (SELECT taxon_id FROM TaxonClassification) AND",
        "taxon_id NOT IN (SELECT taxon_species FROM TaxonClassification",
        "WHERE taxon_species IS NOT NULL) AND",
        "taxon_id NOT IN (SELECT taxon_genus FROM TaxonClassification",
        "WHERE taxon_genus IS NOT NULL) AND",
        "taxon_id NOT IN (SELECT taxon_family FROM TaxonClassification",
        "WHERE taxon_family IS NOT NULL)"
      ),
      "Taxa used by no sample, trait value or classification",
      "abiotic_variables_without_values", "flag",
      base::paste(
        "SELECT COUNT(*) FROM AbioticVariable WHERE abiotic_variable_id",
        "NOT IN (SELECT abiotic_variable_id FROM AbioticData)"
      ),
      "Abiotic variables without a value"
    )

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
