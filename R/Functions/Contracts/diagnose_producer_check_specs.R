#' @title Diagnose the value checks of a producer-contract entry
#' @description
#' Check that the `checks` field of a column, a nested column or a
#' variable in a producer contract uses only the documented check names
#' with well-formed arguments.
#' @param list_checks
#' The parsed `checks` field: a named list, or `NULL` when the entry has
#' no checks.
#' @param field_path
#' Character scalar. Location of the field in the contract, used at the
#' start of every message, for example `"columns[3].checks"`.
#' @return
#' Character vector of problem descriptions, each starting with
#' `field_path`. Empty when the checks are well formed or `NULL`.
#' @details
#' The known checks are:
#' `range`, a map with optional numeric `min` and `max` (at least one of
#' them, and `min` not above `max`) and optional logical `min_inclusive`
#' and `max_inclusive`; `finite`, `whole_number` and `not_empty`, each a
#' logical scalar; `allowed_values` and `forbidden_values`, each a
#' non-empty vector without missing values; and `pattern`, a valid regular
#' expression. Any other name is a problem.
diagnose_producer_check_specs <- function(
  list_checks,
  field_path
) {
  assertthat::assert_that(
    base::is.character(field_path),
    base::length(field_path) == 1L,
    !base::is.na(field_path),
    msg = "'field_path' must be a single character value."
  )

  if (
    base::is.null(list_checks)
  ) {
    return(base::character(0))
  }

  vec_names <-
    base::names(list_checks)

  if (
    !base::is.list(list_checks) ||
      base::is.null(vec_names) ||
      base::any(vec_names == "")
  ) {
    res_unnamed <-
      stringr::str_c(field_path, ": checks must be a named map.")

    return(res_unnamed)
  }

  vec_known <-
    c(
      "range", "finite", "whole_number", "not_empty", "allowed_values",
      "forbidden_values", "pattern"
    )

  vec_unknown <-
    base::setdiff(vec_names, vec_known)

  vec_problems_unknown <-
    stringr::str_c(
      field_path, ": unknown check '", vec_unknown, "'."
    )

  vec_problems_range <-
    if (
      "range" %in% vec_names
    ) {
      list_range <-
        purrr::chuck(list_checks, "range")

      vec_range_fields <-
        base::names(list_range)

      # stringr::str_c() drops NULL arguments, so set results are kept as
      #   character vectors
      vec_range_unknown <-
        base::setdiff(
          vec_range_fields,
          c("min", "max", "min_inclusive", "max_inclusive")
        ) |>
        base::as.character()

      is_number <-
        purrr::map_lgl(
          .x = list_range[
            base::intersect(vec_range_fields, c("min", "max"))
          ],
          .f = ~ base::is.numeric(.x) && base::length(.x) == 1L &&
            !base::is.na(.x)
        )

      is_flag <-
        purrr::map_lgl(
          .x = list_range[
            base::intersect(
              vec_range_fields,
              c("min_inclusive", "max_inclusive")
            )
          ],
          .f = ~ base::is.logical(.x) && base::length(.x) == 1L &&
            !base::is.na(.x)
        )

      flag_has_bound <-
        base::any(c("min", "max") %in% vec_range_fields)

      flag_reversed <-
        base::all(is_number) &&
        base::all(c("min", "max") %in% vec_range_fields) &&
        purrr::chuck(list_range, "min") > purrr::chuck(list_range, "max")

      c(
        stringr::str_c(
          field_path, ".range: unknown field '", vec_range_unknown, "'."
        ),
        base::ifelse(
          flag_has_bound,
          NA_character_,
          stringr::str_c(field_path, ".range: needs 'min' or 'max'.")
        ),
        base::ifelse(
          base::all(is_number),
          NA_character_,
          stringr::str_c(field_path, ".range: 'min' and 'max' must be numbers.")
        ),
        base::ifelse(
          base::all(is_flag),
          NA_character_,
          stringr::str_c(
            field_path,
            ".range: 'min_inclusive' and 'max_inclusive' must be true or false."
          )
        ),
        base::ifelse(
          flag_reversed,
          stringr::str_c(field_path, ".range: 'min' is above 'max'."),
          NA_character_
        )
      ) |>
        stats::na.omit() |>
        base::as.character()
    } else {
      base::character(0)
    }

  vec_flag_checks <-
    base::intersect(vec_names, c("finite", "whole_number", "not_empty"))

  is_flag_valid <-
    purrr::map_lgl(
      .x = list_checks[vec_flag_checks],
      .f = ~ base::is.logical(.x) && base::length(.x) == 1L &&
        !base::is.na(.x)
    )

  vec_problems_flags <-
    stringr::str_c(
      field_path, ".", vec_flag_checks[!is_flag_valid],
      ": must be true or false."
    )

  vec_value_checks <-
    base::intersect(vec_names, c("allowed_values", "forbidden_values"))

  is_values_valid <-
    purrr::map_lgl(
      .x = list_checks[vec_value_checks],
      .f = ~ base::is.atomic(.x) && base::length(.x) > 0L &&
        !base::anyNA(.x)
    )

  vec_problems_values <-
    stringr::str_c(
      field_path, ".", vec_value_checks[!is_values_valid],
      ": must be a non-empty list of values without missing values."
    )

  pattern_value <-
    purrr::pluck(list_checks, "pattern")

  # A pattern is valid when it is one text value that compiles
  flag_pattern_valid <-
    base::is.null(pattern_value) ||
    (
      base::is.character(pattern_value) &&
        base::length(pattern_value) == 1L &&
        !base::is.na(pattern_value) &&
        base::tryCatch(
          expr = {
            stringr::str_detect(string = "", pattern = pattern_value)
            TRUE
          },
          error = function(error) FALSE
        )
    )

  vec_problems_pattern <-
    if (
      flag_pattern_valid
    ) {
      base::character(0)
    } else {
      stringr::str_c(
        field_path, ".pattern: must be a valid regular expression."
      )
    }

  res <-
    c(
      vec_problems_unknown,
      vec_problems_range,
      vec_problems_flags,
      vec_problems_values,
      vec_problems_pattern
    )

  return(res)
}
