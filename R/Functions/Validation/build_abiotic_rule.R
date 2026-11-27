#' @title Build one value rule of an abiotic variable
#' @description
#' Turn the contract checks of one abiotic variable into one row of the
#' value-rule table of `build_abiotic_value_rules()`.
#' @param artefact_id
#' Character scalar. The contract the rule comes from.
#' @param variable
#' Character scalar. The variable name stored in the database.
#' @param unit
#' Character scalar. The unit the import writes.
#' @param details
#' Character scalar or `NA`. The description the import writes; `NA` when
#' the contract gives none.
#' @param age_min,age_max
#' Numeric scalars. The youngest and oldest sample age, in years before
#' 1950, whose values the rule covers.
#' @param list_checks
#' Named list. The contract checks of the values: optional `range` (with
#' `min`, `max`, `min_inclusive` and `max_inclusive`), `forbidden_values`,
#' `allowed_values` and `whole_number`. Other checks are ignored.
#' @return
#' A one-row tibble with the columns described in
#' `build_abiotic_value_rules()`. A missing range bound is `-Inf` or `Inf`,
#' bounds are inclusive unless the contract says otherwise, and missing
#' value lists are empty numeric vectors.
#' @examples
#' build_abiotic_rule(
#'   artefact_id = "chelsa_neoclimate",
#'   variable = "bio4",
#'   unit = "C/100 (hundredths of a degree Celsius)",
#'   details = "temperature seasonality",
#'   age_min = 0,
#'   age_max = 0,
#'   list_checks = list(range = list(min = 0, min_inclusive = FALSE))
#' )
build_abiotic_rule <- function(
  artefact_id,
  variable,
  unit,
  details,
  age_min,
  age_max,
  list_checks
) {
  assertthat::assert_that(
    assertthat::is.string(artefact_id),
    assertthat::is.string(variable),
    assertthat::is.string(unit),
    base::is.character(details) || base::all(base::is.na(details)),
    base::length(details) == 1L,
    msg = stringr::str_c(
      "'artefact_id', 'variable' and 'unit' must be character scalars and ",
      "'details' a character scalar or NA."
    )
  )

  assertthat::assert_that(
    base::is.numeric(age_min),
    base::is.numeric(age_max),
    base::length(age_min) == 1L,
    base::length(age_max) == 1L,
    !base::is.na(age_min),
    !base::is.na(age_max),
    age_min <= age_max,
    msg = "'age_min' and 'age_max' must be numbers, 'age_min' not above."
  )

  assertthat::assert_that(
    base::is.list(list_checks),
    msg = "'list_checks' must be a list."
  )

  list_range <-
    purrr::pluck(list_checks, "range", .default = base::list())

  res <-
    tibble::tibble(
      artefact_id = artefact_id,
      variable = variable,
      unit = unit,
      details = base::as.character(details),
      age_min = base::as.numeric(age_min),
      age_max = base::as.numeric(age_max),
      range_min = base::as.numeric(
        purrr::pluck(list_range, "min", .default = -Inf)
      ),
      range_max = base::as.numeric(
        purrr::pluck(list_range, "max", .default = Inf)
      ),
      flag_min_inclusive = base::isTRUE(
        purrr::pluck(list_range, "min_inclusive", .default = TRUE)
      ),
      flag_max_inclusive = base::isTRUE(
        purrr::pluck(list_range, "max_inclusive", .default = TRUE)
      ),
      list_forbidden = base::list(
        base::as.numeric(
          base::unlist(purrr::pluck(list_checks, "forbidden_values"))
        )
      ),
      list_allowed = base::list(
        base::as.numeric(
          base::unlist(purrr::pluck(list_checks, "allowed_values"))
        )
      ),
      flag_whole_number = base::isTRUE(
        purrr::pluck(list_checks, "whole_number", .default = FALSE)
      )
    )

  return(res)
}
