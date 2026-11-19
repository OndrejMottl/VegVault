#' @title Diagnose the element entry of a producer-contract list-column
#' @description
#' Check that the `element` field of a list-column entry in a producer
#' contract, which describes every element of the list-column, follows the
#' contract format.
#' @param list_element
#' The parsed `element` field: a named list.
#' @param field_path
#' Character scalar. Location of the field in the contract, used at the
#' start of every message, for example `"columns[12].element"`.
#' @param fn_diagnose_columns
#' Function that diagnoses the `columns` of a `"data.frame"` element, with
#' the arguments `list_columns` and `field_path`: normally
#' `diagnose_producer_column_specs()`, which passes itself here.
#' @return
#' Character vector of problem descriptions, each starting with a field
#' path. Empty when the element entry is well formed.
#' @details
#' Every element needs `class` (any class accepted by
#' `is_producer_class()` except `"list"`) and `nullable` (whether an
#' element may be `NULL` or missing). The other allowed fields depend on
#' the class:
#' a `"data.frame"` element may have `columns` (column entries, diagnosed
#' recursively with `fn_diagnose_columns`), `other_columns`
#' (one rule for every column not listed in `columns`, with `class`,
#' `nullable` and `description`, and optionally `checks` and
#' `forbidden_names`; its class must be atomic), `extra_columns`
#' (`"allow"` or `"error"`), `keys` (sets of names from `columns` that are
#' unique within each element) and `min_rows`;
#' a `"matrix"` element may have `value_class` (an atomic class),
#' `checks`, `require_column_names` and `min_rows`;
#' any other element may have `checks`.
#' `min_rows` is a whole number of at least 0. Checks are diagnosed with
#' `diagnose_producer_check_specs()`. Any other field is a problem.
#' The column checker is an argument, not called by name, because the two
#' functions call each other and `{targets}` reads calls by name in both
#' directions as a cycle.
diagnose_producer_element_spec <- function(
  list_element,
  field_path,
  fn_diagnose_columns
) {
  assertthat::assert_that(
    base::is.character(field_path),
    base::length(field_path) == 1L,
    !base::is.na(field_path),
    msg = "'field_path' must be a single character value."
  )

  assertthat::assert_that(
    base::is.function(fn_diagnose_columns),
    msg = "'fn_diagnose_columns' must be a function."
  )

  if (
    !base::is.list(list_element) ||
      base::is.null(base::names(list_element))
  ) {
    res_shape <-
      stringr::str_c(field_path, ": must be a map.")

    return(res_shape)
  }

  vec_atomic_classes <-
    c(
      "character", "numeric", "double", "integer", "logical", "Date",
      "factor"
    )

  vec_fields <-
    base::names(list_element)

  value_class <-
    purrr::pluck(list_element, "class", .default = NA_character_)

  flag_class_valid <-
    base::is.character(value_class) &&
    base::length(value_class) == 1L &&
    value_class %in% c(vec_atomic_classes, "data.frame", "matrix")

  value_nullable <-
    purrr::pluck(list_element, "nullable", .default = NA)

  vec_allowed <-
    base::switch(
      base::ifelse(flag_class_valid, value_class, "unknown"),
      "data.frame" = c(
        "class", "nullable", "columns", "other_columns", "extra_columns",
        "keys", "min_rows"
      ),
      "matrix" = c(
        "class", "nullable", "value_class", "checks",
        "require_column_names", "min_rows"
      ),
      "unknown" = vec_fields,
      c("class", "nullable", "checks")
    )

  vec_problems_basic <-
    c(
      stringr::str_c(
        field_path, ": missing field '",
        base::setdiff(c("class", "nullable"), vec_fields), "'."
      ),
      if (
        "class" %in% vec_fields && !flag_class_valid
      ) {
        stringr::str_c(
          field_path, ".class: must be an atomic class, 'data.frame' or ",
          "'matrix'."
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
        stringr::str_c(field_path, ".nullable: must be true or false.")
      },
      stringr::str_c(
        field_path, ": field '", base::setdiff(vec_fields, vec_allowed),
        "' is not allowed for this class."
      )
    )

  value_min_rows <-
    purrr::pluck(list_element, "min_rows")

  vec_problems_rows <-
    if (
      !base::is.null(value_min_rows) &&
        !(
          base::is.numeric(value_min_rows) &&
            base::length(value_min_rows) == 1L &&
            !base::is.na(value_min_rows) &&
            value_min_rows >= 0 &&
            value_min_rows == base::round(value_min_rows)
        )
    ) {
      stringr::str_c(field_path, ".min_rows: must be a whole number >= 0.")
    }

  list_other <-
    purrr::pluck(list_element, "other_columns")

  path_other <-
    stringr::str_c(field_path, ".other_columns")

  vec_problems_other <-
    if (
      base::identical(value_class, "data.frame") &&
        !base::is.null(list_other)
    ) {
      vec_other_fields <-
        base::as.character(base::names(list_other))

      value_other_class <-
        purrr::pluck(list_other, "class", .default = NA_character_)

      value_forbidden <-
        purrr::pluck(list_other, "forbidden_names")

      c(
        stringr::str_c(
          path_other, ": missing field '",
          base::setdiff(
            c("class", "nullable", "description"),
            vec_other_fields
          ),
          "'."
        ),
        stringr::str_c(
          path_other, ": unknown field '",
          base::setdiff(
            vec_other_fields,
            c(
              "class", "nullable", "description", "checks",
              "forbidden_names"
            )
          ) |>
            base::as.character(),
          "'."
        ),
        if (
          !base::is.na(value_other_class) &&
            !value_other_class %in% vec_atomic_classes
        ) {
          stringr::str_c(path_other, ".class: must be an atomic class.")
        },
        if (
          !base::is.null(value_forbidden) &&
            !base::is.character(value_forbidden)
        ) {
          stringr::str_c(path_other, ".forbidden_names: must be text.")
        },
        diagnose_producer_check_specs(
          list_checks = purrr::pluck(list_other, "checks"),
          field_path = stringr::str_c(path_other, ".checks")
        )
      )
    }

  vec_problems_frame <-
    if (
      base::identical(value_class, "data.frame")
    ) {
      list_columns <-
        purrr::pluck(list_element, "columns")

      vec_column_names <-
        purrr::map_chr(
          .x = list_columns,
          .f = ~ purrr::pluck(.x, "name", .default = NA_character_)
        )

      vec_key_names <-
        purrr::pluck(list_element, "keys", .default = base::list()) |>
        base::unlist(use.names = FALSE)

      value_extra <-
        purrr::pluck(list_element, "extra_columns")

      c(
        if (
          !base::is.null(list_columns)
        ) {
          fn_diagnose_columns(
            list_columns = list_columns,
            field_path = stringr::str_c(field_path, ".columns")
          )
        },
        if (
          !base::is.null(value_extra) &&
            !base::identical(value_extra, "allow") &&
            !base::identical(value_extra, "error")
        ) {
          stringr::str_c(
            field_path, ".extra_columns: must be 'allow' or 'error'."
          )
        },
        # stringr::str_c() drops NULL arguments, so set results are kept
        #   as character vectors
        stringr::str_c(
          field_path, ".keys: '",
          base::as.character(base::setdiff(vec_key_names, vec_column_names)),
          "' is not a listed column."
        ),
        vec_problems_other
      )
    }

  vec_problems_matrix <-
    if (
      base::identical(value_class, "matrix")
    ) {
      value_value_class <-
        purrr::pluck(list_element, "value_class")

      value_require_names <-
        purrr::pluck(list_element, "require_column_names")

      c(
        if (
          !base::is.null(value_value_class) &&
            !(
              base::length(value_value_class) == 1L &&
                value_value_class %in% vec_atomic_classes
            )
        ) {
          stringr::str_c(
            field_path, ".value_class: must be an atomic class."
          )
        },
        if (
          !base::is.null(value_require_names) &&
            !(
              base::is.logical(value_require_names) &&
                base::length(value_require_names) == 1L &&
                !base::is.na(value_require_names)
            )
        ) {
          stringr::str_c(
            field_path, ".require_column_names: must be true or false."
          )
        }
      )
    }

  vec_problems_checks <-
    if (
      "checks" %in% vec_allowed
    ) {
      diagnose_producer_check_specs(
        list_checks = purrr::pluck(list_element, "checks"),
        field_path = stringr::str_c(field_path, ".checks")
      )
    }

  # Starting from an empty character vector keeps the type when every
  #   part is NULL
  res <-
    c(
      base::character(0),
      vec_problems_basic,
      vec_problems_rows,
      vec_problems_frame,
      vec_problems_matrix,
      vec_problems_checks
    )

  return(res)
}
