#' @title Build the statements of the orphan-row checks
#' @description
#' Return the SQL statement of each scope of `diagnose_orphan_rows()`,
#' with the status a found row gets and a description, so that the
#' statements can be checked without running them.
#' @return
#' A tibble with one row per scope, in the order of
#' `diagnose_orphan_rows()`: `scope` (character), `status_found`
#' (character, `"fail"` or `"flag"`), `statement` (character, one SQLite
#' statement that returns one row with one count) and `description`
#' (character).
#' @details
#' A gridpoint sample belongs to a dataset of type `gridpoints`. The first
#' five scopes fail when a row is found, the last three are flagged (see
#' `diagnose_orphan_rows()`).
#' Every statement reads `PositionLink`, the largest table, at most once
#' and never searches it row by row, so that the checks finish on the
#' full-size database. For `linked_gridpoints_without_values` the distinct
#' linked samples are therefore built first, as a materialised common
#' table expression: with the planner statistics of the full-size 2.0.0
#' database, SQLite would otherwise search `PositionLink` through its
#' primary key once per gridpoint sample, with a skip-scan over all
#' positions.
#' @examples
#' \dontrun{
#' data_statements <-
#'   build_orphan_statements()
#' }
build_orphan_statements <- function() {
  # Gridpoint samples, as a subquery; SQLite builds it once per statement
  sql_gridpoint_samples <-
    base::paste(
      "SELECT ds.sample_id FROM DatasetSample AS ds",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      "JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
      "WHERE t.dataset_type = 'gridpoints'"
    )

  res <-
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
      # The distinct linked samples come first, from one scan of
      #   PositionLink; materialised, so that the conditions are not moved
      #   into that scan as a search per gridpoint sample
      "linked_gridpoints_without_values", "flag",
      base::paste(
        "WITH linked AS MATERIALIZED (SELECT DISTINCT sample_ref_id",
        "FROM PositionLink)",
        "SELECT COUNT(*) FROM linked WHERE sample_ref_id NOT IN",
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

  return(res)
}
