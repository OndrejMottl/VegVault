#' @title Diagnose the elements of a producer-artefact list-column
#' @description
#' Check every element of one list-column against the `element` entry of
#' its contract column: missing elements, element class, and, depending on
#' the class, the nested columns of data frames, the values of matrices or
#' the values of atomic vectors.
#' @param list_values
#' The list-column to check: a list with one element per row.
#' @param list_element
#' The `element` entry of the contract column, as described in
#' `diagnose_producer_element_spec()`.
#' @param contract_id
#' Character scalar. Identifier of the contract, for the findings.
#' @param column
#' Character scalar. Path of the list-column, for example `"taxa"`. Nested
#' columns are reported as `"<column>[].<nested column>"` and the elements
#' themselves as `"<column>[]"`.
#' @param file_name
#' Character scalar. File the list-column comes from, or `NA`.
#' @return
#' A findings tibble as built by `build_producer_findings()`. Zero rows
#' when every element satisfies the entry.
#' @details
#' An element counts as missing when it is `NULL` or a single `NA`;
#' missing elements are a violation (`element_missing`) unless `nullable`
#' is `TRUE`. Elements of the wrong class are counted once
#' (`class_mismatch` on `"<column>[]"`) and left out of the checks below.
#' For `"data.frame"` elements: elements with a duplicated column name
#' (`column_duplicate`, counted in elements); a listed column absent from
#' an element (`column_missing`, counted in elements) or of the wrong class
#' (`class_mismatch`), where a logical column holding only missing values
#' is accepted for a nullable atomic class; values of each listed column
#' gathered over all elements and checked with `diagnose_producer_values()`
#' (nested list-columns are checked recursively with this function);
#' columns not listed are checked against `other_columns` (class, values
#' and `forbidden_names`, reported as `column_forbidden`) or, without that
#' rule and with `extra_columns: error`, reported as `column_extra`;
#' `keys` must be unique within each element (`key_duplicate`, counted in
#' elements); and elements with fewer rows than `min_rows` are reported as
#' `element_rows`.
#' For `"matrix"` elements: `value_class` of the values, column names when
#' `require_column_names` is `TRUE` (`element_column_names`), `min_rows`,
#' and the values gathered over all elements, where `nullable` also
#' governs missing values inside the matrices.
#' For atomic elements: the values gathered over all elements, where
#' `nullable` also governs missing values inside the vectors.
diagnose_producer_elements <- function(
  list_values,
  list_element,
  contract_id,
  column,
  file_name = NA_character_
) {
  # Nested list-columns recurse through this handle rather than through the
  #   function name: {targets} reads a self-reference by name as a cycle
  #   and refuses every pipeline that loads this function
  fn_diagnose_nested <-
    base::sys.function()

  assertthat::assert_that(
    base::is.list(list_values),
    !base::is.data.frame(list_values),
    msg = "'list_values' must be a list-column (a list)."
  )

  assertthat::assert_that(
    base::is.list(list_element),
    msg = "'list_element' must be an element entry (a list)."
  )

  assertthat::assert_that(
    base::is.character(column),
    base::length(column) == 1L,
    !base::is.na(column),
    msg = "'column' must be a single character value."
  )

  vec_atomic_classes <-
    c(
      "character", "numeric", "double", "integer", "logical", "Date",
      "factor"
    )

  path_elements <-
    stringr::str_c(column, "[]")

  element_class <-
    purrr::chuck(list_element, "class")

  flag_nullable <-
    purrr::chuck(list_element, "nullable")

  value_min_rows <-
    purrr::pluck(list_element, "min_rows")

  #--------------------------------------------------#
  ## Missing elements and element class -----
  #--------------------------------------------------#

  is_missing <-
    purrr::map_lgl(
      .x = list_values,
      .f = ~ base::is.null(.x) ||
        (base::is.atomic(.x) && base::length(.x) == 1L && base::is.na(.x))
    )

  n_missing <-
    base::sum(is_missing)

  list_present <-
    list_values[!is_missing]

  is_class_ok <-
    purrr::map_lgl(
      .x = list_present,
      .f = ~ is_producer_class(x = .x, class_name = element_class)
    )

  n_class_bad <-
    base::sum(!is_class_ok)

  list_ok <-
    list_present[is_class_ok]

  vec_flags_basic <-
    c(!flag_nullable && n_missing > 0L, n_class_bad > 0L)

  data_findings_basic <-
    build_producer_findings(
      contract_id = contract_id,
      check = c("element_missing", "class_mismatch")[vec_flags_basic],
      message = c(
        stringr::str_c(
          n_missing, " missing element(s) (NULL or NA) where every row ",
          "needs one."
        ),
        stringr::str_c(
          n_class_bad, " element(s) are not of class '", element_class, "'."
        )
      )[vec_flags_basic],
      file_name = file_name,
      column = path_elements,
      n_violations = c(n_missing, n_class_bad)[vec_flags_basic]
    )

  #--------------------------------------------------#
  ## Data-frame elements -----
  #--------------------------------------------------#

  data_findings_frame <-
    if (
      element_class == "data.frame"
    ) {
      list_columns <-
        purrr::pluck(list_element, "columns", .default = base::list())

      vec_listed <-
        purrr::map_chr(
          .x = list_columns,
          .f = ~ purrr::chuck(.x, "name")
        )

      n_elements_duplicated <-
        list_ok |>
        purrr::map_lgl(.f = ~ base::anyDuplicated(base::names(.x)) > 0L) |>
        base::sum()

      data_findings_duplicated <-
        build_producer_findings(
          contract_id = contract_id,
          check = base::rep("column_duplicate", n_elements_duplicated > 0L),
          message = base::rep(
            stringr::str_c(
              n_elements_duplicated,
              " element(s) have a column name more than once."
            ),
            n_elements_duplicated > 0L
          ),
          file_name = file_name,
          column = path_elements,
          n_violations = n_elements_duplicated
        )

      data_findings_listed <-
        purrr::map(
          .x = list_columns,
          .f = ~ {
            list_spec <- .x

            name_column <-
              purrr::chuck(list_spec, "name")

            class_column <-
              purrr::chuck(list_spec, "class")

            flag_column_nullable <-
              purrr::chuck(list_spec, "nullable")

            path_column <-
              stringr::str_c(path_elements, ".", name_column)

            is_present <-
              purrr::map_lgl(
                .x = list_ok,
                .f = ~ name_column %in% base::names(.x)
              )

            list_with_column <-
              list_ok[is_present]

            # A logical column holding only missing values stands for an
            #   empty column of a nullable atomic class
            is_empty_nullable <-
              purrr::map_lgl(
                .x = list_with_column,
                .f = ~ flag_column_nullable &&
                  class_column %in% vec_atomic_classes &&
                  base::is.logical(.x[[name_column]]) &&
                  base::all(base::is.na(.x[[name_column]]))
              )

            is_column_class_ok <-
              is_empty_nullable |
              purrr::map_lgl(
                .x = list_with_column,
                .f = ~ is_producer_class(
                  x = .x[[name_column]],
                  class_name = class_column
                )
              )

            list_good <-
              list_with_column[is_column_class_ok & !is_empty_nullable]

            vec_flags_shape <-
              c(base::any(!is_present), base::any(!is_column_class_ok))

            data_findings_shape <-
              build_producer_findings(
                contract_id = contract_id,
                check = c("column_missing", "class_mismatch")[vec_flags_shape],
                message = c(
                  stringr::str_c(
                    base::sum(!is_present), " of ", base::length(list_ok),
                    " element(s) lack the column."
                  ),
                  stringr::str_c(
                    base::sum(!is_column_class_ok),
                    " element(s) hold the column with a class other than '",
                    class_column, "'."
                  )
                )[vec_flags_shape],
                file_name = file_name,
                column = path_column,
                n_violations = c(
                  base::sum(!is_present),
                  base::sum(!is_column_class_ok)
                )[vec_flags_shape]
              )

            list_column_values <-
              purrr::map(
                .x = list_good,
                .f = ~ .x[[name_column]]
              )

            data_findings_values <-
              if (
                base::length(list_good) == 0L
              ) {
                NULL
              } else if (
                class_column == "list"
              ) {
                fn_diagnose_nested(
                  list_values = purrr::list_c(list_column_values),
                  list_element = purrr::chuck(list_spec, "element"),
                  contract_id = contract_id,
                  column = path_column,
                  file_name = file_name
                )
              } else {
                diagnose_producer_values(
                  vec_values = purrr::list_c(list_column_values),
                  list_checks = purrr::pluck(list_spec, "checks"),
                  nullable = flag_column_nullable,
                  contract_id = contract_id,
                  column = path_column,
                  file_name = file_name
                )
              }

            dplyr::bind_rows(data_findings_shape, data_findings_values)
          }
        ) |>
        dplyr::bind_rows()

      list_unlisted_names <-
        purrr::map(
          .x = list_ok,
          .f = ~ base::setdiff(base::names(.x), vec_listed)
        )

      list_other <-
        purrr::pluck(list_element, "other_columns")

      value_extra <-
        purrr::pluck(list_element, "extra_columns", .default = "allow")

      data_findings_unlisted <-
        if (
          !base::is.null(list_other)
        ) {
          path_other <-
            stringr::str_c(path_elements, ".<other columns>")

          vec_forbidden <-
            purrr::pluck(
              list_other,
              "forbidden_names",
              .default = base::character(0)
            )

          class_other <-
            purrr::chuck(list_other, "class")

          flag_other_nullable <-
            purrr::chuck(list_other, "nullable")

          vec_names_forbidden <-
            list_unlisted_names |>
            purrr::map(.f = ~ base::intersect(.x, vec_forbidden)) |>
            base::unlist(use.names = FALSE) |>
            base::unique()

          n_elements_forbidden <-
            list_unlisted_names |>
            purrr::map_lgl(.f = ~ base::any(.x %in% vec_forbidden)) |>
            base::sum()

          # Every unlisted column of every element is checked for its
          #   class; the values of columns with the right class are pooled
          list_other_checked <-
            purrr::map2(
              .x = list_ok,
              .y = list_unlisted_names,
              .f = ~ {
                data_element <- .x

                vec_names_other <-
                  base::setdiff(.y, vec_forbidden)

                is_other_empty <-
                  purrr::map_lgl(
                    .x = vec_names_other,
                    .f = ~ flag_other_nullable &&
                      base::is.logical(data_element[[.x]]) &&
                      base::all(base::is.na(data_element[[.x]]))
                  )

                is_other_ok <-
                  is_other_empty |
                  purrr::map_lgl(
                    .x = vec_names_other,
                    .f = ~ is_producer_class(
                      x = data_element[[.x]],
                      class_name = class_other
                    )
                  )

                vec_names_pooled <-
                  vec_names_other[is_other_ok & !is_other_empty]

                base::list(
                  n_bad = base::sum(!is_other_ok),
                  values = purrr::list_c(
                    base::unname(base::as.list(
                      data_element[vec_names_pooled]
                    ))
                  )
                )
              }
            )

          n_other_bad <-
            list_other_checked |>
            purrr::map_int(
              .f = ~ base::as.integer(purrr::chuck(.x, "n_bad"))
            ) |>
            base::sum()

          vec_other_values <-
            list_other_checked |>
            purrr::map(.f = ~ purrr::pluck(.x, "values")) |>
            purrr::list_c()

          vec_flags_other <-
            c(n_elements_forbidden > 0L, n_other_bad > 0L)

          dplyr::bind_rows(
            build_producer_findings(
              contract_id = contract_id,
              check = c("column_forbidden", "class_mismatch")[
                vec_flags_other
              ],
              message = c(
                stringr::str_c(
                  n_elements_forbidden, " element(s) have a column with a ",
                  "reserved name: ",
                  stringr::str_c(vec_names_forbidden, collapse = ", "), "."
                ),
                stringr::str_c(
                  n_other_bad, " unlisted column(s) are not of class '",
                  class_other, "'."
                )
              )[vec_flags_other],
              file_name = file_name,
              column = path_other,
              n_violations = c(n_elements_forbidden, n_other_bad)[
                vec_flags_other
              ]
            ),
            if (
              !base::is.null(vec_other_values)
            ) {
              diagnose_producer_values(
                vec_values = vec_other_values,
                list_checks = purrr::pluck(list_other, "checks"),
                nullable = flag_other_nullable,
                contract_id = contract_id,
                column = path_other,
                file_name = file_name
              )
            }
          )
        } else if (
          value_extra == "error"
        ) {
          vec_names_extra <-
            list_unlisted_names |>
            base::unlist(use.names = FALSE) |>
            base::unique()

          n_elements_extra <-
            base::sum(base::lengths(list_unlisted_names) > 0L)

          build_producer_findings(
            contract_id = contract_id,
            check = base::rep("column_extra", n_elements_extra > 0L),
            message = base::rep(
              stringr::str_c(
                n_elements_extra, " element(s) have unlisted column(s): ",
                stringr::str_c(
                  utils::head(vec_names_extra, 10L),
                  collapse = ", "
                ),
                "."
              ),
              n_elements_extra > 0L
            ),
            file_name = file_name,
            column = path_elements,
            n_violations = n_elements_extra
          )
        } else {
          NULL
        }

      # YAML reads single-column keys as a vector, so each element of the
      #   vector is one key
      list_keys <-
        purrr::pluck(list_element, "keys", .default = base::list()) |>
        base::as.list()

      data_findings_keys <-
        purrr::map(
          .x = list_keys,
          .f = ~ {
            vec_key <-
              base::as.character(.x)

            n_elements_repeated <-
              list_ok |>
              purrr::map_lgl(
                .f = ~ base::all(vec_key %in% base::names(.x)) &&
                  vctrs::vec_duplicate_any(.x[vec_key])
              ) |>
              base::sum()

            build_producer_findings(
              contract_id = contract_id,
              check = base::rep("key_duplicate", n_elements_repeated > 0L),
              message = base::rep(
                stringr::str_c(
                  n_elements_repeated, " element(s) repeat a value of the ",
                  "key (", stringr::str_c(vec_key, collapse = ", "), ")."
                ),
                n_elements_repeated > 0L
              ),
              file_name = file_name,
              column = stringr::str_c(
                path_elements, ".", stringr::str_c(vec_key, collapse = "+")
              ),
              n_violations = n_elements_repeated
            )
          }
        ) |>
        dplyr::bind_rows()

      vec_rows <-
        purrr::map_int(
          .x = list_ok,
          .f = base::nrow
        )

      n_short <-
        if (
          base::is.null(value_min_rows)
        ) {
          0L
        } else {
          base::sum(vec_rows < value_min_rows)
        }

      dplyr::bind_rows(
        data_findings_duplicated,
        data_findings_listed,
        data_findings_unlisted,
        data_findings_keys,
        build_producer_findings(
          contract_id = contract_id,
          check = base::rep("element_rows", n_short > 0L),
          message = base::rep(
            stringr::str_c(
              n_short, " element(s) have fewer than ", value_min_rows,
              " row(s)."
            ),
            n_short > 0L
          ),
          file_name = file_name,
          column = path_elements,
          n_violations = n_short
        )
      )
    }

  #--------------------------------------------------#
  ## Matrix elements -----
  #--------------------------------------------------#

  data_findings_matrix <-
    if (
      element_class == "matrix"
    ) {
      value_class <-
        purrr::pluck(list_element, "value_class")

      is_value_class_ok <-
        if (
          base::is.null(value_class)
        ) {
          base::rep(TRUE, base::length(list_ok))
        } else {
          purrr::map_lgl(
            .x = list_ok,
            .f = ~ is_producer_class(
              x = base::as.vector(.x),
              class_name = value_class
            )
          )
        }

      list_matrix_good <-
        list_ok[is_value_class_ok]

      n_unnamed <-
        if (
          base::isTRUE(purrr::pluck(list_element, "require_column_names"))
        ) {
          list_matrix_good |>
            purrr::map_lgl(
              .f = ~ {
                vec_names <- base::colnames(.x)

                base::is.null(vec_names) ||
                  base::anyNA(vec_names) ||
                  base::any(vec_names == "")
              }
            ) |>
            base::sum()
        } else {
          0L
        }

      vec_matrix_rows <-
        purrr::map_int(
          .x = list_matrix_good,
          .f = base::nrow
        )

      n_matrix_short <-
        if (
          base::is.null(value_min_rows)
        ) {
          0L
        } else {
          base::sum(vec_matrix_rows < value_min_rows)
        }

      vec_matrix_values <-
        list_matrix_good |>
        purrr::map(.f = base::as.vector) |>
        purrr::list_c()

      vec_flags_matrix <-
        c(
          base::sum(!is_value_class_ok) > 0L,
          n_unnamed > 0L,
          n_matrix_short > 0L
        )

      dplyr::bind_rows(
        build_producer_findings(
          contract_id = contract_id,
          check = c(
            "class_mismatch", "element_column_names", "element_rows"
          )[vec_flags_matrix],
          message = c(
            stringr::str_c(
              base::sum(!is_value_class_ok),
              " matrix element(s) do not hold values of class '",
              value_class, "'."
            ),
            stringr::str_c(
              n_unnamed, " matrix element(s) lack complete column names."
            ),
            stringr::str_c(
              n_matrix_short, " matrix element(s) have fewer than ",
              value_min_rows, " row(s)."
            )
          )[vec_flags_matrix],
          file_name = file_name,
          column = path_elements,
          n_violations = c(
            base::sum(!is_value_class_ok), n_unnamed, n_matrix_short
          )[vec_flags_matrix]
        ),
        if (
          !base::is.null(vec_matrix_values)
        ) {
          diagnose_producer_values(
            vec_values = vec_matrix_values,
            list_checks = purrr::pluck(list_element, "checks"),
            nullable = flag_nullable,
            contract_id = contract_id,
            column = path_elements,
            file_name = file_name
          )
        }
      )
    }

  #--------------------------------------------------#
  ## Atomic elements -----
  #--------------------------------------------------#

  vec_atomic_values <-
    if (
      element_class %in% vec_atomic_classes
    ) {
      purrr::list_c(list_ok)
    }

  data_findings_atomic <-
    if (
      !base::is.null(vec_atomic_values)
    ) {
      diagnose_producer_values(
        vec_values = vec_atomic_values,
        list_checks = purrr::pluck(list_element, "checks"),
        nullable = flag_nullable,
        contract_id = contract_id,
        column = path_elements,
        file_name = file_name
      )
    }

  res <-
    dplyr::bind_rows(
      data_findings_basic,
      data_findings_frame,
      data_findings_matrix,
      data_findings_atomic
    )

  return(res)
}
