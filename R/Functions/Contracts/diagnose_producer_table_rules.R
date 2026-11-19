#' @title Diagnose the keys and dependencies of a producer artefact
#' @description
#' Check that the key columns of a producer artefact identify every row,
#' also after rounding where the contract asks for it, and that its
#' functional dependencies hold, for example one unit per trait.
#' @param data_source
#' A data frame: one file, or the rows of all files that the keys span
#' (all partitions of one variable, for example).
#' @param list_keys
#' List of character vectors, one per key, as in the `keys` field returned
#' by `load_producer_contract()`.
#' @param list_dependencies
#' List of dependencies, each a list with the character vectors
#' `determinant` and `dependent`.
#' @param contract_id
#' Character scalar. Identifier of the contract, for the findings.
#' @param scope_label
#' Character scalar. What `data_source` covers, used in messages, for
#' example `"the artefact"` or `"variable bio12"`.
#' @param list_rounded_keys
#' List of rounded keys as in the `rounded_keys` field returned by
#' `load_producer_contract()`: each a list with the character vector
#' `columns` and the whole number `digits`.
#' @return
#' A findings tibble as built by `build_producer_findings()`, with
#' `file_name` set to `NA` and `column` to the key or dependency columns
#' joined by `"+"`. Zero rows when every rule holds.
#' @details
#' `key_duplicate` counts the rows whose key values occur more than once;
#' missing values count as equal. `key_duplicate_rounded` does the same
#' after rounding the numeric key columns to `digits` decimals, for keys
#' that the import turns into names with rounded coordinates.
#' `dependency_violation` counts the combinations of `determinant` values
#' that occur with more than one combination of `dependent` values. A rule
#' whose columns are not all in `data_source` is skipped, because the
#' missing column is reported by `diagnose_producer_columns()`.
diagnose_producer_table_rules <- function(
  data_source,
  list_keys,
  list_dependencies,
  contract_id,
  scope_label = "the artefact",
  list_rounded_keys = base::list()
) {
  assertthat::assert_that(
    base::is.data.frame(data_source),
    msg = "'data_source' must be a data frame."
  )

  assertthat::assert_that(
    base::is.list(list_keys),
    msg = "'list_keys' must be a list of character vectors."
  )

  assertthat::assert_that(
    base::is.list(list_dependencies),
    msg = "'list_dependencies' must be a list."
  )

  assertthat::assert_that(
    base::is.list(list_rounded_keys),
    msg = "'list_rounded_keys' must be a list."
  )

  assertthat::assert_that(
    base::is.character(scope_label),
    base::length(scope_label) == 1L,
    msg = "'scope_label' must be a single character value."
  )

  vec_names <-
    base::names(data_source)

  # Plain keys and rounded keys share one description: the columns, the
  #   number of decimals (NA for plain keys) and the check name
  data_key_rules <-
    dplyr::bind_rows(
      tibble::tibble(
        columns = purrr::map(.x = list_keys, .f = base::as.character),
        digits = NA_integer_,
        check = "key_duplicate"
      ),
      tibble::tibble(
        columns = purrr::map(
          .x = list_rounded_keys,
          .f = ~ base::as.character(purrr::chuck(.x, "columns"))
        ),
        digits = purrr::map_int(
          .x = list_rounded_keys,
          .f = ~ base::as.integer(purrr::chuck(.x, "digits"))
        ),
        check = base::rep(
          "key_duplicate_rounded",
          base::length(list_rounded_keys)
        )
      )
    )

  data_findings_keys <-
    purrr::pmap(
      .l = data_key_rules,
      .f = ~ {
        vec_key <- ..1

        value_digits <- ..2

        n_duplicated <-
          if (
            base::all(vec_key %in% vec_names)
          ) {
            data_source[vec_key] |>
              dplyr::mutate(
                dplyr::across(
                  .cols = tidyselect::where(base::is.numeric),
                  .fns = ~ if (
                    base::is.na(value_digits)
                  ) {
                    .x
                  } else {
                    base::round(.x, digits = value_digits)
                  }
                )
              ) |>
              vctrs::vec_duplicate_detect() |>
              base::sum()
          } else {
            0L
          }

        build_producer_findings(
          contract_id = contract_id,
          check = base::rep(..3, n_duplicated > 0L),
          message = base::rep(
            stringr::str_c(
              n_duplicated, " row(s) share their key (",
              stringr::str_c(vec_key, collapse = ", "), ")",
              base::ifelse(
                base::is.na(value_digits),
                "",
                stringr::str_c(
                  " rounded to ", value_digits, " decimal(s)"
                )
              ),
              " with another row in ", scope_label, "."
            ),
            n_duplicated > 0L
          ),
          column = stringr::str_c(vec_key, collapse = "+"),
          n_violations = n_duplicated
        )
      }
    ) |>
    dplyr::bind_rows()

  data_findings_dependencies <-
    purrr::map(
      .x = list_dependencies,
      .f = ~ {
        vec_determinant <-
          base::as.character(purrr::chuck(.x, "determinant"))

        vec_dependent <-
          base::as.character(purrr::chuck(.x, "dependent"))

        flag_columns_present <-
          base::all(c(vec_determinant, vec_dependent) %in% vec_names)

        # A determinant value that appears more than once among the
        #   distinct (determinant, dependent) pairs has several dependents
        n_conflicts <-
          if (
            flag_columns_present
          ) {
            data_determinants <-
              data_source[c(vec_determinant, vec_dependent)] |>
              vctrs::vec_unique() |>
              dplyr::select(dplyr::all_of(vec_determinant))

            is_repeated <-
              vctrs::vec_duplicate_detect(data_determinants)

            vctrs::vec_unique_count(
              dplyr::filter(data_determinants, is_repeated)
            )
          } else {
            0L
          }

        build_producer_findings(
          contract_id = contract_id,
          check = base::rep("dependency_violation", n_conflicts > 0L),
          message = base::rep(
            stringr::str_c(
              "In ", scope_label, ", some values of (",
              stringr::str_c(vec_determinant, collapse = ", "),
              ") occur with more than one value of (",
              stringr::str_c(vec_dependent, collapse = ", "), ")."
            ),
            n_conflicts > 0L
          ),
          column = stringr::str_c(
            c(vec_determinant, vec_dependent),
            collapse = "+"
          ),
          n_violations = n_conflicts
        )
      }
    ) |>
    dplyr::bind_rows()

  res <-
    dplyr::bind_rows(
      build_producer_findings(
        contract_id = contract_id,
        check = base::character(0),
        message = base::character(0)
      ),
      data_findings_keys,
      data_findings_dependencies
    )

  return(res)
}
