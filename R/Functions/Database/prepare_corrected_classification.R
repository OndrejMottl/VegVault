#' @title Prepare the classification with the corrections set by hand
#' @description
#' Replace the classification of the taxon names listed in
#' `build: classification: corrections` of `config.yml` by the ranks given
#' there, so that a name the matching service places wrongly gets a
#' classification chosen by hand. For example, the FOSSILPOL pollen type
#' "Pinus Picea" (pollen of pine or spruce) is matched to Abies alba,
#' because GBIF lists Pinus picea as a synonym of Abies alba; corrected, it
#' is classified in the family Pinaceae only.
#' @param data_classification
#' A data frame with the columns `taxon_name`, `species_name`,
#' `genus_name` and `family_name`, one row per taxon name, as returned by
#' `classify_taxa()` for every batch.
#' @param list_corrections
#' A list of corrections as read from `config.yml`, each a named list with
#' `taxon_name` and any of `species_name`, `genus_name` and `family_name`,
#' each a single text. An empty list or `NULL` corrects nothing.
#' @param verbose
#' Logical. If `TRUE` (default), the number of corrected names and the
#' corrected names that `data_classification` does not hold are printed
#' via `cli`.
#' @return
#' `data_classification` with the same rows, order and columns. Each name
#' with a correction has the ranks of its correction; a rank the
#' correction does not give is missing.
#' @details
#' A correction of a name that `data_classification` does not hold changes
#' nothing, because a profile such as `subset` keeps only part of the
#' names. The corrections apply after the classification batches, so a
#' change of the corrections classifies no name again. Aborts when
#' `data_classification` lacks one of the four columns or holds a name
#' twice, and when a correction lacks `taxon_name`, has another field,
#' gives a value that is not a single text, or repeats a name.
#' @seealso [classify_taxa()], [prepare_classification_tables()]
#' @examples
#' \dontrun{
#' data_classification_corrected <-
#'   prepare_corrected_classification(
#'     data_classification = data_classification,
#'     list_corrections = list(
#'       list(taxon_name = "Pinus Picea", family_name = "Pinaceae")
#'     ),
#'     verbose = FALSE
#'   )
#' }
prepare_corrected_classification <- function(
  data_classification,
  list_corrections = NULL,
  verbose = TRUE
) {
  vec_columns <-
    c("taxon_name", "species_name", "genus_name", "family_name")

  assertthat::assert_that(
    base::is.data.frame(data_classification),
    base::all(vec_columns %in% base::names(data_classification)),
    msg = stringr::str_c(
      "`data_classification` must be a data frame with the columns ",
      "`taxon_name`, `species_name`, `genus_name` and `family_name`."
    )
  )

  assertthat::assert_that(
    base::is.null(list_corrections) ||
      (
        base::is.list(list_corrections) &&
          !base::is.data.frame(list_corrections)
      ),
    msg = "`list_corrections` must be a list of corrections or NULL."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  vec_names_classified <-
    dplyr::pull(data_classification, taxon_name)

  vec_names_repeated <-
    vec_names_classified[base::duplicated(vec_names_classified)] |>
    base::unique()

  if (
    base::length(vec_names_repeated) > 0L
  ) {
    cli::cli_abort(
      c(
        "The classification holds a name more than once.",
        "i" = "Repeated: {.val {vec_names_repeated}}."
      )
    )
  }

  if (
    base::length(list_corrections) == 0L
  ) {
    res <- data_classification

    return(res)
  }

  vec_lacking_name <-
    list_corrections |>
    purrr::map_lgl(.f = ~ !"taxon_name" %in% base::names(.x))

  if (
    base::any(vec_lacking_name)
  ) {
    cli::cli_abort(
      "A correction lacks `taxon_name`."
    )
  }

  vec_fields_unknown <-
    list_corrections |>
    purrr::map(.f = ~ base::setdiff(base::names(.x), vec_columns)) |>
    purrr::list_c(ptype = base::character(0)) |>
    base::unique()

  if (
    base::length(vec_fields_unknown) > 0L
  ) {
    cli::cli_abort(
      c(
        "A correction has a field other than the four classification columns.",
        "i" = "Unknown: {.field {vec_fields_unknown}}."
      )
    )
  }

  vec_values_valid <-
    list_corrections |>
    purrr::map_lgl(
      .f = ~ purrr::every(
        .x = .x,
        .p = ~ base::is.character(.x) &&
          base::length(.x) == 1L &&
          !base::is.na(.x)
      )
    )

  if (
    !base::all(vec_values_valid)
  ) {
    cli::cli_abort(
      "Every value of a correction must be a single text."
    )
  }

  data_corrections <-
    list_corrections |>
    purrr::map(.f = ~ tibble::as_tibble(.x)) |>
    purrr::list_rbind()

  data_corrections_complete <-
    tibble::tibble(
      taxon_name = base::character(0),
      species_name = base::character(0),
      genus_name = base::character(0),
      family_name = base::character(0)
    ) |>
    dplyr::bind_rows(data_corrections)

  vec_names_to_correct <-
    dplyr::pull(data_corrections_complete, taxon_name)

  vec_corrections_repeated <-
    vec_names_to_correct[base::duplicated(vec_names_to_correct)] |>
    base::unique()

  if (
    base::length(vec_corrections_repeated) > 0L
  ) {
    cli::cli_abort(
      c(
        "The corrections name a taxon more than once.",
        "i" = "Repeated: {.val {vec_corrections_repeated}}."
      )
    )
  }

  vec_names_corrected <-
    base::intersect(vec_names_to_correct, vec_names_classified)

  vec_names_absent <-
    base::setdiff(vec_names_to_correct, vec_names_corrected)

  data_classification_corrected <-
    dplyr::rows_update(
      x = data_classification,
      y = data_corrections_complete,
      by = "taxon_name",
      unmatched = "ignore"
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      "Corrected the classification of {base::length(vec_names_corrected)}
      name{?s}."
    )
  }

  if (
    base::isTRUE(verbose) &&
      base::length(vec_names_absent) > 0L
  ) {
    cli::cli_inform(
      "Not among the names, so not corrected: {.val {vec_names_absent}}."
    )
  }

  res <- data_classification_corrected

  return(res)
}
