#' @title Load the number of taxa per classification level
#' @description
#' Count the taxa of the database and the distinct species, genera and
#' families they are classified to, for the taxa-classification figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with five rows and the columns `taxon_level` (character:
#' `total taxa`, `species`, `genus`, `family` and `not classified`, in
#' this order) and `n_taxa` (integer).
#' @details
#' `species`, `genus` and `family` count the distinct non-missing values of
#' `TaxonClassification` (v1 also counted a missing value as one level).
#' `not classified` counts the taxa without species, genus and family,
#' including taxa without a classification row. The database is opened
#' read-only.
#' @examples
#' \dontrun{
#' data_taxa_classification_counts <-
#'   load_taxa_classification_counts(
#'     path_database = path_database,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_taxa_classification_counts <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  list_counts <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        # COUNT(DISTINCT ...) ignores missing values
        data_levels <-
          dplyr::tbl(src = con, from = "TaxonClassification") |>
          dplyr::summarise(
            n_species = dplyr::n_distinct(taxon_species, na.rm = TRUE),
            n_genus = dplyr::n_distinct(taxon_genus, na.rm = TRUE),
            n_family = dplyr::n_distinct(taxon_family, na.rm = TRUE)
          ) |>
          dplyr::collect()

        n_total <-
          dplyr::tbl(src = con, from = "Taxa") |>
          dplyr::count() |>
          dplyr::pull(n)

        n_not_classified <-
          dplyr::tbl(src = con, from = "Taxa") |>
          dplyr::left_join(
            dplyr::tbl(src = con, from = "TaxonClassification"),
            by = "taxon_id"
          ) |>
          dplyr::filter(
            base::is.na(taxon_species) &
              base::is.na(taxon_genus) &
              base::is.na(taxon_family)
          ) |>
          dplyr::count() |>
          dplyr::pull(n)

        res_counts <-
          c(
            n_total,
            dplyr::pull(data_levels, n_species),
            dplyr::pull(data_levels, n_genus),
            dplyr::pull(data_levels, n_family),
            n_not_classified
          )

        return(res_counts)
      },
      flag_read_only = TRUE
    )

  res <-
    tibble::tibble(
      taxon_level = c(
        "total taxa", "species", "genus", "family", "not classified"
      ),
      n_taxa = base::as.integer(list_counts)
    )

  return(res)
}
