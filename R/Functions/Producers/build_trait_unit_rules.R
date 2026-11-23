#' @title Build the trait unit rules for the database
#' @description
#' Combine the validated trait unit registry of the trait producer into the
#' two tables the database stores: the unit conversions
#' (`TraitUnitConversion`) and the trait derivations (`TraitDerivation`).
#' @param list_conversions
#' Named list of data frames: the validated `trait_unit_conversions`
#' artefact, as returned by `load_producer_import()`.
#' @param list_derivations
#' Named list of data frames: the validated `trait_derivations` artefact.
#' @return
#' A named list of two tibbles, `unit_conversions` and `trait_derivations`,
#' with the columns of `TraitUnitConversion` and `TraitDerivation` in
#' `Data/SQL/make_tables.sql` without their id, in the schema's order.
#' @details
#' The tables of each artefact are bound by rows. Columns only the producer
#' uses (such as `verify_source_standardized`) are dropped. Aborts, naming
#' the column, when a column the schema needs is missing. The columns are
#' written here and checked against the schema by the test of this
#' function, so a schema change that this function misses fails the tests.
#' @seealso [validate_trait_rule_keys()]
#' @examples
#' \dontrun{
#' data_trait_unit_rules <-
#'   build_trait_unit_rules(
#'     list_conversions = data_trait_unit_conversions,
#'     list_derivations = data_trait_derivations
#'   )
#' }
build_trait_unit_rules <- function(
  list_conversions,
  list_derivations
) {
  assertthat::assert_that(
    base::is.list(list_conversions),
    !base::is.data.frame(list_conversions),
    base::length(list_conversions) > 0L,
    base::all(
      purrr::map_lgl(.x = list_conversions, .f = base::is.data.frame)
    ),
    msg = "`list_conversions` must be a non-empty list of data frames."
  )

  assertthat::assert_that(
    base::is.list(list_derivations),
    !base::is.data.frame(list_derivations),
    base::length(list_derivations) > 0L,
    base::all(
      purrr::map_lgl(.x = list_derivations, .f = base::is.data.frame)
    ),
    msg = "`list_derivations` must be a non-empty list of data frames."
  )

  vec_columns_conversions <-
    c(
      "conversion_rule_key", "rule_version", "source_provider",
      "source_trait_id", "source_dataset_key", "normalized_original_unit",
      "standardized_unit", "trait_dimension", "operation", "multiplier",
      "evidence"
    )

  vec_columns_derivations <-
    c(
      "derivation_rule_key", "rule_version", "input_unit", "output_unit",
      "trait_dimension", "operation", "multiplier", "evidence"
    )

  data_conversions <-
    list_conversions |>
    base::unname() |>
    dplyr::bind_rows()

  data_derivations <-
    list_derivations |>
    base::unname() |>
    dplyr::bind_rows()

  validate_data_columns(
    data_source = data_conversions,
    vec_columns_required = vec_columns_conversions,
    name_argument = "list_conversions"
  )

  validate_data_columns(
    data_source = data_derivations,
    vec_columns_required = vec_columns_derivations,
    name_argument = "list_derivations"
  )

  res <-
    list(
      unit_conversions = data_conversions |>
        dplyr::select(dplyr::all_of(vec_columns_conversions)) |>
        tibble::as_tibble(),
      trait_derivations = data_derivations |>
        dplyr::select(dplyr::all_of(vec_columns_derivations)) |>
        tibble::as_tibble()
    )

  return(res)
}
