#' @title Diagnose the column entries of a producer contract
#' @description
#' Check that the column entries of a producer contract, including the
#' entries nested inside list-columns, follow the contract format.
#' @param list_columns
#' The parsed `columns` field: an unnamed, non-empty list in which every
#' element is a named list describing one column.
#' @param field_path
#' Character scalar. Location of the entries in the contract, used at the
#' start of every message, for example `"columns"` or
#' `"columns[12].element.columns"`.
#' @return
#' Character vector of problem descriptions, each starting with a field
#' path. Empty when every entry is well formed.
#' @details
#' Every entry needs `name`, `class`, `nullable`, `description` and
#' `evidence`, and may have `unit`, `checks` and `element`; any other
#' field is a problem, as are duplicated names. `class` must be a class
#' accepted by `is_producer_class()` and `nullable` a logical scalar. An
#' entry of class `"list"` needs an `element` describing the elements of
#' the list-column, diagnosed with `diagnose_producer_element_spec()`, and
#' no other class may have one. Checks are diagnosed with
#' `diagnose_producer_check_specs()`.
diagnose_producer_column_specs <- function(
  list_columns,
  field_path = "columns"
) {
  # Element entries recurse back into this function through this handle,
  #   because {targets} reads two functions that call each other by name as
  #   a cycle
  fn_diagnose_columns <-
    base::sys.function()

  assertthat::assert_that(
    base::is.character(field_path),
    base::length(field_path) == 1L,
    !base::is.na(field_path),
    msg = "'field_path' must be a single character value."
  )

  if (
    !base::is.list(list_columns) ||
      base::length(list_columns) == 0L ||
      !base::is.null(base::names(list_columns))
  ) {
    res_shape <-
      stringr::str_c(
        field_path, ": must be a non-empty list of column entries."
      )

    return(res_shape)
  }

  vec_required <-
    c("name", "class", "nullable", "description", "evidence")

  vec_allowed <-
    c(vec_required, "unit", "checks", "element")

  vec_classes <-
    c(
      "character", "numeric", "double", "integer", "logical", "Date",
      "factor", "list", "data.frame", "matrix"
    )

  vec_problems_entries <-
    purrr::imap(
      .x = list_columns,
      .f = ~ {
        list_column <- .x

        path_entry <-
          stringr::str_c(field_path, "[", .y, "]")

        if (
          !base::is.list(list_column) ||
            base::is.null(base::names(list_column))
        ) {
          return(stringr::str_c(path_entry, ": must be a map."))
        }

        vec_fields <-
          base::names(list_column)

        is_text <-
          purrr::map_lgl(
            .x = list_column[
              base::intersect(
                vec_fields,
                c("name", "description", "evidence", "class")
              )
            ],
            .f = ~ base::is.character(.x) && base::length(.x) == 1L &&
              !base::is.na(.x) && .x != ""
          )

        value_class <-
          purrr::pluck(list_column, "class", .default = NA_character_)

        value_nullable <-
          purrr::pluck(list_column, "nullable", .default = NA)

        value_unit <-
          purrr::pluck(list_column, "unit")

        flag_list <-
          base::identical(value_class, "list")

        flag_has_element <- "element" %in% vec_fields

        vec_problems_element <-
          if (
            flag_list && flag_has_element
          ) {
            diagnose_producer_element_spec(
              list_element = purrr::chuck(list_column, "element"),
              field_path = stringr::str_c(path_entry, ".element"),
              fn_diagnose_columns = fn_diagnose_columns
            )
          }

        c(
          stringr::str_c(
            path_entry, ": missing field '",
            base::setdiff(vec_required, vec_fields), "'."
          ),
          stringr::str_c(
            path_entry, ": unknown field '",
            base::setdiff(vec_fields, vec_allowed), "'."
          ),
          # stringr::str_c() drops NULL arguments, so the names are kept as
          #   a character vector
          stringr::str_c(
            path_entry, ".",
            base::as.character(base::names(is_text)[!is_text]),
            ": must be a non-empty text value."
          ),
          if (
            base::is.character(value_class) &&
              base::length(value_class) == 1L &&
              !base::is.na(value_class) &&
              !value_class %in% vec_classes
          ) {
            stringr::str_c(
              path_entry, ".class: unknown class '", value_class, "'."
            )
          },
          if (
            "nullable" %in% vec_fields &&
              !(
                base::is.logical(value_nullable) &&
                  base::length(value_nullable) == 1L &&
                  !base::is.na(value_nullable)
              )
          ) {
            stringr::str_c(path_entry, ".nullable: must be true or false.")
          },
          if (
            !base::is.null(value_unit) &&
              !(
                base::is.character(value_unit) &&
                  base::length(value_unit) == 1L
              )
          ) {
            stringr::str_c(path_entry, ".unit: must be a text value.")
          },
          if (
            flag_list && !flag_has_element
          ) {
            stringr::str_c(path_entry, ": class 'list' needs an 'element'.")
          },
          if (
            !flag_list && flag_has_element
          ) {
            stringr::str_c(
              path_entry, ": only class 'list' may have an 'element'."
            )
          },
          vec_problems_element,
          diagnose_producer_check_specs(
            list_checks = purrr::pluck(list_column, "checks"),
            field_path = stringr::str_c(path_entry, ".checks")
          )
        )
      }
    ) |>
    base::unlist(use.names = FALSE)

  vec_names <-
    purrr::map_chr(
      .x = list_columns,
      .f = ~ {
        value_name <-
          purrr::pluck(.x, "name", .default = NA_character_)

        if (
          base::is.character(value_name) && base::length(value_name) == 1L
        ) {
          value_name
        } else {
          NA_character_
        }
      }
    )

  vec_duplicated <-
    vec_names[base::duplicated(vec_names) & !base::is.na(vec_names)] |>
    base::unique()

  vec_problems_duplicated <-
    stringr::str_c(
      field_path, ": duplicated column name '", vec_duplicated, "'."
    )

  # Starting from an empty character vector keeps the type when every
  #   part is NULL
  res <-
    c(
      base::character(0),
      vec_problems_entries,
      vec_problems_duplicated
    )

  return(res)
}
