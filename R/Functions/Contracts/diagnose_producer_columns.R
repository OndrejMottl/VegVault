#' @title Diagnose the columns of one producer-artefact data frame
#' @description
#' Check the columns of one data frame (one file, or one in-memory object)
#' against the column entries of its contract: presence, duplicated names,
#' class, values and the elements of list-columns.
#' @param data_source
#' A data frame.
#' @param list_columns
#' The `columns` field of the contract, as returned by
#' `load_producer_contract()`.
#' @param extra_columns
#' Character scalar. `"allow"` or `"error"`: whether columns that the
#' contract does not list are accepted.
#' @param contract_id
#' Character scalar. Identifier of the contract, for the findings.
#' @param file_name
#' Character scalar. File the data frame comes from, or `NA`.
#' @return
#' A findings tibble as built by `build_producer_findings()`. Zero rows
#' when the data frame satisfies the column entries.
#' @details
#' The checks, named in the `check` column, are `column_duplicate` (a
#' column name occurs more than once), `column_missing` (a listed column
#' is absent), `column_extra` (an unlisted column while `extra_columns` is
#' `"error"`, one finding per column) and `class_mismatch` (the column
#' does not have its listed class, checked with `is_producer_class()`; its
#' values are then not checked). A logical column holding only missing
#' values is accepted for any nullable atomic class, because a column
#' without values is often stored that way. Values of other columns are
#' checked with `diagnose_producer_values()` and the elements of
#' list-columns with `diagnose_producer_elements()`.
diagnose_producer_columns <- function(
  data_source,
  list_columns,
  extra_columns,
  contract_id,
  file_name = NA_character_
) {
  assertthat::assert_that(
    base::is.data.frame(data_source),
    msg = "'data_source' must be a data frame."
  )

  assertthat::assert_that(
    base::is.character(extra_columns),
    base::length(extra_columns) == 1L,
    extra_columns %in% c("allow", "error"),
    msg = "'extra_columns' must be 'allow' or 'error'."
  )

  vec_atomic_classes <-
    c(
      "character", "numeric", "double", "integer", "logical", "Date",
      "factor"
    )

  vec_listed <-
    purrr::map_chr(
      .x = list_columns,
      .f = ~ purrr::chuck(.x, "name")
    )

  vec_present <-
    base::names(data_source)

  vec_duplicated <-
    vec_present[base::duplicated(vec_present)] |>
    base::unique()

  vec_missing <-
    base::setdiff(vec_listed, vec_present) |>
    base::as.character()

  vec_extra <-
    if (
      extra_columns == "error"
    ) {
      base::as.character(base::setdiff(vec_present, vec_listed))
    } else {
      base::character(0)
    }

  data_findings_presence <-
    build_producer_findings(
      contract_id = contract_id,
      check = c(
        base::rep("column_duplicate", base::length(vec_duplicated)),
        base::rep("column_missing", base::length(vec_missing)),
        base::rep("column_extra", base::length(vec_extra))
      ),
      message = c(
        base::rep(
          "Column name occurs more than once.",
          base::length(vec_duplicated)
        ),
        base::rep("Column is missing.", base::length(vec_missing)),
        base::rep(
          "Column is not part of the contract.",
          base::length(vec_extra)
        )
      ),
      file_name = file_name,
      column = c(vec_duplicated, vec_missing, vec_extra)
    )

  # Duplicated names are reported above; their columns are not checked
  #   further because it is unclear which one the import would read
  list_columns_present <-
    list_columns[vec_listed %in% vec_present & !vec_listed %in% vec_duplicated]

  data_findings_content <-
    purrr::map(
      .x = list_columns_present,
      .f = ~ {
        list_spec <- .x

        name_column <-
          purrr::chuck(list_spec, "name")

        class_column <-
          purrr::chuck(list_spec, "class")

        vec_column <-
          data_source[[name_column]]

        flag_empty_nullable <-
          purrr::chuck(list_spec, "nullable") &&
          class_column %in% vec_atomic_classes &&
          base::is.logical(vec_column) &&
          base::all(base::is.na(vec_column))

        flag_class_ok <-
          flag_empty_nullable ||
          is_producer_class(x = vec_column, class_name = class_column)

        if (
          !flag_class_ok
        ) {
          build_producer_findings(
            contract_id = contract_id,
            check = "class_mismatch",
            message = stringr::str_c(
              "Column has class '",
              stringr::str_c(base::class(vec_column), collapse = "/"),
              "', expected '", class_column, "'."
            ),
            file_name = file_name,
            column = name_column
          )
        } else if (
          flag_empty_nullable
        ) {
          NULL
        } else if (
          class_column == "list"
        ) {
          diagnose_producer_elements(
            list_values = vec_column,
            list_element = purrr::chuck(list_spec, "element"),
            contract_id = contract_id,
            column = name_column,
            file_name = file_name
          )
        } else if (
          base::is.atomic(vec_column)
        ) {
          diagnose_producer_values(
            vec_values = vec_column,
            list_checks = purrr::pluck(list_spec, "checks"),
            nullable = purrr::chuck(list_spec, "nullable"),
            contract_id = contract_id,
            column = name_column,
            file_name = file_name
          )
        }
      }
    ) |>
    dplyr::bind_rows()

  res <-
    dplyr::bind_rows(
      data_findings_presence,
      data_findings_content
    )

  return(res)
}
