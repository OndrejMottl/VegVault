#' @title Diagnose the values of one producer-artefact column
#' @description
#' Check the values of one column (or of one nested column gathered over
#' all elements of a list-column) against the `nullable` flag and the
#' value checks of its contract entry.
#' @param vec_values
#' Atomic vector of the values to check.
#' @param list_checks
#' The `checks` field of the contract entry: a named list, or `NULL`.
#' @param nullable
#' Logical scalar. Whether missing values are allowed.
#' @param contract_id
#' Character scalar. Identifier of the contract, for the findings.
#' @param column
#' Character scalar. Column path, for the findings.
#' @param file_name
#' Character scalar. File the values come from, or `NA`.
#' @return
#' A findings tibble as built by `build_producer_findings()`, one row per
#' violated rule, with `n_violations` the number of offending values.
#' Zero rows when every value satisfies the entry.
#' @details
#' The checks, named in the `check` column, are:
#' `value_missing` (`NA` or `NaN` while `nullable` is `FALSE`);
#' `value_not_finite` (`Inf` or `-Inf` when `finite` is `TRUE`);
#' `value_out_of_range` (outside `range`; bounds are inclusive unless
#' `min_inclusive` or `max_inclusive` is `FALSE`);
#' `value_not_whole` (a fractional value when `whole_number` is `TRUE`);
#' `value_not_allowed` (a value not in `allowed_values`);
#' `value_forbidden` (a value in `forbidden_values`; numbers are compared
#' with a relative tolerance of 1e-9, so a stored type limit such as
#' 6553.5 is found even after floating-point scaling);
#' `value_pattern` (text not matching `pattern`); and `value_empty` (an
#' empty string when `not_empty` is `TRUE`).
#' Missing values, `NaN` included, are ignored by every check except
#' `value_missing`, so `NaN` passes a nullable column. Numeric checks are
#' skipped for non-numeric values and text checks for non-text values;
#' factors are treated as text.
diagnose_producer_values <- function(
  vec_values,
  list_checks,
  nullable,
  contract_id,
  column,
  file_name = NA_character_
) {
  assertthat::assert_that(
    base::is.atomic(vec_values),
    msg = "'vec_values' must be an atomic vector."
  )

  assertthat::assert_that(
    base::is.logical(nullable),
    base::length(nullable) == 1L,
    !base::is.na(nullable),
    msg = "'nullable' must be TRUE or FALSE."
  )

  assertthat::assert_that(
    base::is.character(column),
    base::length(column) == 1L,
    base::is.character(file_name),
    base::length(file_name) == 1L,
    msg = "'column' and 'file_name' must be single character values."
  )

  vec_compared <-
    if (
      base::is.factor(vec_values)
    ) {
      base::as.character(vec_values)
    } else {
      vec_values
    }

  flag_numeric <-
    base::is.numeric(vec_compared)

  flag_text <-
    base::is.character(vec_compared)

  is_missing <-
    base::is.na(vec_compared)

  vec_present <-
    vec_compared[!is_missing]

  list_range <-
    purrr::pluck(list_checks, "range")

  vec_allowed <-
    purrr::pluck(list_checks, "allowed_values")

  vec_forbidden <-
    purrr::pluck(list_checks, "forbidden_values")

  pattern_text <-
    purrr::pluck(list_checks, "pattern")

  value_min <-
    purrr::pluck(list_range, "min", .default = -Inf)

  value_max <-
    purrr::pluck(list_range, "max", .default = Inf)

  flag_min_inclusive <-
    purrr::pluck(list_range, "min_inclusive", .default = TRUE)

  flag_max_inclusive <-
    purrr::pluck(list_range, "max_inclusive", .default = TRUE)

  #--------------------------------------------------#
  ## Counts per check -----
  #--------------------------------------------------#

  n_missing <-
    if (
      nullable
    ) {
      0L
    } else {
      base::sum(is_missing)
    }

  n_not_finite <-
    if (
      flag_numeric && base::isTRUE(purrr::pluck(list_checks, "finite"))
    ) {
      base::sum(!base::is.finite(vec_present))
    } else {
      0L
    }

  n_out_of_range <-
    if (
      flag_numeric && !base::is.null(list_range)
    ) {
      is_below <-
        if (
          flag_min_inclusive
        ) {
          vec_present < value_min
        } else {
          vec_present <= value_min
        }

      is_above <-
        if (
          flag_max_inclusive
        ) {
          vec_present > value_max
        } else {
          vec_present >= value_max
        }

      base::sum(is_below | is_above)
    } else {
      0L
    }

  n_not_whole <-
    if (
      flag_numeric &&
        base::isTRUE(purrr::pluck(list_checks, "whole_number"))
    ) {
      base::sum(
        base::is.finite(vec_present) &
          vec_present != base::round(vec_present)
      )
    } else {
      0L
    }

  n_forbidden <-
    if (
      flag_numeric && base::is.numeric(vec_forbidden)
    ) {
      is_forbidden <-
        purrr::map(
          .x = vec_forbidden,
          .f = ~ base::abs(vec_present - .x) <=
            1e-9 * base::max(1, base::abs(.x))
        ) |>
        purrr::reduce(
          .f = `|`,
          .init = base::rep(FALSE, base::length(vec_present))
        )

      base::sum(is_forbidden, na.rm = TRUE)
    } else if (
      flag_text && base::is.character(vec_forbidden)
    ) {
      base::sum(vec_present %in% vec_forbidden)
    } else {
      0L
    }

  vec_not_allowed <-
    if (
      !base::is.null(vec_allowed) && (flag_numeric || flag_text)
    ) {
      vec_present[!vec_present %in% vec_allowed]
    } else {
      vec_present[0]
    }

  n_pattern <-
    if (
      flag_text && !base::is.null(pattern_text)
    ) {
      base::sum(!stringr::str_detect(vec_present, pattern_text))
    } else {
      0L
    }

  n_empty <-
    if (
      flag_text && base::isTRUE(purrr::pluck(list_checks, "not_empty"))
    ) {
      base::sum(vec_present == "")
    } else {
      0L
    }

  #--------------------------------------------------#
  ## Findings -----
  #--------------------------------------------------#

  text_range <-
    stringr::str_c(
      base::ifelse(flag_min_inclusive, "[", "("),
      base::format(value_min),
      ", ",
      base::format(value_max),
      base::ifelse(flag_max_inclusive, "]", ")")
    )

  data_candidates <-
    tibble::tibble(
      check = c(
        "value_missing", "value_not_finite", "value_out_of_range",
        "value_not_whole", "value_not_allowed", "value_forbidden",
        "value_pattern", "value_empty"
      ),
      n_violations = base::as.integer(
        c(
          n_missing, n_not_finite, n_out_of_range, n_not_whole,
          base::length(vec_not_allowed), n_forbidden, n_pattern, n_empty
        )
      ),
      message = c(
        "missing value(s) where none are allowed.",
        "infinite value(s).",
        stringr::str_c("value(s) outside ", text_range, "."),
        "fractional value(s) where whole numbers are required.",
        stringr::str_c(
          "value(s) not allowed: ",
          stringr::str_c(
            utils::head(base::unique(vec_not_allowed), 5L),
            collapse = ", "
          ),
          " (allowed: ",
          stringr::str_c(vec_allowed, collapse = ", "),
          ")."
        ),
        stringr::str_c(
          "value(s) equal to a forbidden value (",
          stringr::str_c(base::format(vec_forbidden), collapse = ", "),
          "), such as a storage-type limit."
        ),
        stringr::str_c(
          "value(s) not matching the pattern '",
          stringr::str_c(pattern_text, ""),
          "'."
        ),
        "empty text value(s)."
      )
    ) |>
    dplyr::filter(.data[["n_violations"]] > 0L)

  res <-
    build_producer_findings(
      contract_id = contract_id,
      check = dplyr::pull(data_candidates, "check"),
      message = stringr::str_c(
        dplyr::pull(data_candidates, "n_violations"),
        " ",
        dplyr::pull(data_candidates, "message")
      ),
      file_name = file_name,
      column = column,
      n_violations = dplyr::pull(data_candidates, "n_violations")
    )

  return(res)
}
