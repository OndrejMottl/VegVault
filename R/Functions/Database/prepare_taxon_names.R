#' @title Prepare the taxon names of the sources
#' @description
#' Collect every taxon name that the sample and trait sources use, once
#' each, as the names to classify (see `prepare_taxon_batches()` and
#' `classify_taxa()`).
#' @param list_source_tables
#' A list of source tables, each a named list with the elements of
#' `build_source_table_template()`.
#' @return
#' A character vector of the distinct taxon names, sorted in the C locale;
#' empty when the sources hold no name.
#' @details
#' The names come from the four elements that give `Taxa` its rows in
#' `build_database_tables()`: `taxa`, `taxon_references`, `sample_taxa` and
#' `trait_values`. A missing name is left out, because no taxon row without
#' a name is stored. Aborts when a source lacks one of the four elements or
#' an element lacks the column `taxon_name`.
#' @seealso [prepare_taxon_batches()], [build_database_tables()]
#' @examples
#' \dontrun{
#' vec_taxon_names <-
#'   prepare_taxon_names(
#'     list_source_tables = list(list_tables_splot, list_tables_try)
#'   )
#' }
prepare_taxon_names <- function(list_source_tables) {
  assertthat::assert_that(
    base::is.list(list_source_tables),
    !base::is.data.frame(list_source_tables),
    msg = "`list_source_tables` must be a list of source tables."
  )

  vec_elements <-
    c("taxa", "taxon_references", "sample_taxa", "trait_values")

  vec_missing_elements <-
    list_source_tables |>
    purrr::map(.f = ~ base::setdiff(vec_elements, base::names(.x))) |>
    purrr::list_c(ptype = base::character(0)) |>
    base::unique()

  if (
    base::length(vec_missing_elements) > 0L
  ) {
    cli::cli_abort(
      "A source lacks the element{?s} {.field {vec_missing_elements}}."
    )
  }

  list_name_tables <-
    list_source_tables |>
    purrr::map(.f = ~ purrr::keep_at(.x, vec_elements)) |>
    purrr::list_flatten()

  vec_tables_without_names <-
    list_name_tables |>
    purrr::discard(.p = ~ "taxon_name" %in% base::names(.x)) |>
    base::names()

  if (
    base::length(list_name_tables) > 0L &&
      base::length(vec_tables_without_names) > 0L
  ) {
    cli::cli_abort(
      "{base::length(vec_tables_without_names)} source table{?s} without
      the column {.field taxon_name}: {.val {vec_tables_without_names}}."
    )
  }

  vec_names <-
    list_name_tables |>
    purrr::map(.f = ~ base::as.character(dplyr::pull(.x, taxon_name))) |>
    purrr::list_c(ptype = base::character(0)) |>
    base::unique()

  # Radix sorting orders text in the C locale, as the ids of the build
  res <-
    base::sort(
      vec_names[!base::is.na(vec_names)],
      method = "radix"
    )

  return(res)
}
