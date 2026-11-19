#' @title Build producer contract findings
#' @description
#' Build the table in which every producer-contract check reports its
#' violations, so that all checks return the same columns.
#' @param contract_id
#' Character scalar. Identifier of the contract that was checked.
#' @param check
#' Character vector. Short name of each violated rule, for example
#' `"column_missing"` or `"key_duplicate"`. May be empty.
#' @param message
#' Character vector of the same length as `check`. Human-readable
#' description of each violation.
#' @param file_name
#' Character vector of length 1 or `length(check)`. Base name of the file
#' the violation was found in; `NA` when the violation concerns the whole
#' artefact or an object that was not read from a file.
#' @param column
#' Character vector of length 1 or `length(check)`. Path of the column, for
#' example `"taxa[].Species"` for a column of the data frames nested in the
#' list-column `taxa`; `NA` when the violation is not about a column.
#' @param n_violations
#' Integer vector of length 1 or `length(check)`. Number of offending rows,
#' values or files.
#' @return
#' A tibble with the character columns `contract_id`, `file_name`,
#' `column`, `check` and `message` and the integer column `n_violations`,
#' one row per violation, in the order `contract_id`, `file_name`,
#' `column`, `check`, `n_violations`, `message`. It has zero rows when
#' `check` is empty.
#' @details
#' Aborts when the arguments have incompatible lengths or types.
build_producer_findings <- function(
  contract_id,
  check,
  message,
  file_name = NA_character_,
  column = NA_character_,
  n_violations = 1L
) {
  assertthat::assert_that(
    base::is.character(contract_id),
    base::length(contract_id) == 1L,
    msg = "'contract_id' must be a single character value."
  )

  assertthat::assert_that(
    base::is.character(check),
    msg = "'check' must be a character vector."
  )

  n_findings <-
    base::length(check)

  assertthat::assert_that(
    base::is.character(message),
    base::length(message) == n_findings,
    msg = "'message' must be a character vector as long as 'check'."
  )

  assertthat::assert_that(
    base::is.character(file_name),
    base::length(file_name) %in% c(1L, n_findings),
    msg = "'file_name' must be character, of length 1 or as 'check'."
  )

  assertthat::assert_that(
    base::is.character(column),
    base::length(column) %in% c(1L, n_findings),
    msg = "'column' must be character, of length 1 or as 'check'."
  )

  assertthat::assert_that(
    base::is.numeric(n_violations),
    base::length(n_violations) %in% c(1L, n_findings),
    base::all(n_violations == base::round(n_violations), na.rm = TRUE),
    msg = "'n_violations' must be whole numbers, of length 1 or as 'check'."
  )

  n_violations_integer <-
    base::as.integer(n_violations)

  res <-
    tibble::tibble(
      contract_id = contract_id,
      file_name = file_name,
      column = column,
      check = check,
      n_violations = n_violations_integer,
      message = message
    )

  return(res)
}
