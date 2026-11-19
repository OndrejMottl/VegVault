#' @title Diagnose a producer artefact against its contract
#' @description
#' Run every contract check on one producer artefact held in memory and
#' return all violations as one table, without stopping at the first one.
#' @param data_artefact
#' The artefact: a data frame for a contract without partitions or
#' variables, or a named list of data frames in which every name is the
#' base name of the file the data frame was (or will be) saved as, giving
#' every partition and every variable of the artefact (or of the variables
#' in `vec_variables`).
#' @param contract
#' A contract as returned by `load_producer_contract()`.
#' @param vec_variables
#' Character vector of the variables to check, for checking one or some
#' variables at a time; `NULL` (default) expects every variable of the
#' contract. Only for contracts with `variables`.
#' @return
#' A findings tibble as built by `build_producer_findings()`, ordered as
#' the checks run. Zero rows when the artefact satisfies its contract.
#' @details
#' The checks run in this order: the file names
#' (`diagnose_producer_file_names()`, skipped for a bare data frame); the
#' class of every object (`object_class` when it is not a data frame) and
#' its number of rows (`object_rows` when it has fewer than the contract's
#' `min_rows`); the columns of every object
#' (`diagnose_producer_columns()`); for contracts with `variables`, the
#' values of `variables$value_column` against the checks of the object's
#' variable (`diagnose_producer_values()`, with the column reported as
#' `"<value_column> [<variable>]"`); and the keys, rounded keys and
#' dependencies (`diagnose_producer_table_rules()`) over the rows of all
#' files of the same variable, or of the whole artefact for contracts
#' without variables. Objects whose names do not match the contract's file
#' pattern are still checked for columns but are left out of the variable
#' checks. The function reads no files and changes no data. Aborts when
#' `data_artefact` has neither form or `vec_variables` names a variable
#' the contract does not have.
diagnose_producer_artefact <- function(
  data_artefact,
  contract,
  vec_variables = NULL
) {
  assertthat::assert_that(
    base::is.list(contract),
    base::is.character(purrr::pluck(contract, "contract_id")),
    msg = "'contract' must be a contract from load_producer_contract()."
  )

  contract_id <-
    purrr::chuck(contract, "contract_id")

  list_variables <-
    purrr::pluck(contract, "variables")

  flag_simple_contract <-
    purrr::chuck(contract, "partitioning", "scheme") == "none" &&
    base::is.null(list_variables)

  flag_bare_frame <-
    base::is.data.frame(data_artefact)

  vec_object_names <-
    base::names(data_artefact)

  assertthat::assert_that(
    (flag_bare_frame && flag_simple_contract) ||
      (
        !flag_bare_frame &&
          base::is.list(data_artefact) &&
          base::length(data_artefact) > 0L &&
          !base::is.null(vec_object_names) &&
          !base::anyNA(vec_object_names) &&
          base::all(vec_object_names != "") &&
          !base::anyDuplicated(vec_object_names)
      ),
    msg = stringr::str_c(
      "'data_artefact' must be a list of data frames named by file base ",
      "names (a bare data frame only for contracts without partitions or ",
      "variables)."
    )
  )

  list_objects <-
    if (
      flag_bare_frame
    ) {
      base::list(data_artefact)
    } else {
      data_artefact
    }

  vec_file_names <-
    if (
      flag_bare_frame
    ) {
      NA_character_
    } else {
      vec_object_names
    }

  #--------------------------------------------------#
  ## File names, object classes and rows -----
  #--------------------------------------------------#

  data_findings_files <-
    if (
      !flag_bare_frame
    ) {
      diagnose_producer_file_names(
        vec_file_names = vec_file_names,
        contract = contract,
        vec_variables = vec_variables
      )
    }

  data_files <-
    if (
      flag_bare_frame
    ) {
      tibble::tibble(
        file_name = NA_character_,
        is_match = TRUE,
        variable = NA_character_
      )
    } else {
      build_producer_file_table(
        vec_file_names = vec_file_names,
        contract = contract
      )
    }

  is_frame <-
    purrr::map_lgl(
      .x = list_objects,
      .f = base::is.data.frame
    )

  vec_classes_bad <-
    purrr::map_chr(
      .x = list_objects[!is_frame],
      .f = ~ stringr::str_c(base::class(.x), collapse = "/")
    )

  value_min_rows <-
    purrr::pluck(contract, "min_rows", .default = 1L)

  vec_rows <-
    purrr::map_int(
      .x = list_objects[is_frame],
      .f = base::nrow
    )

  is_short <-
    vec_rows < value_min_rows

  data_findings_objects <-
    build_producer_findings(
      contract_id = contract_id,
      check = c(
        base::rep("object_class", base::sum(!is_frame)),
        base::rep("object_rows", base::sum(is_short))
      ),
      message = c(
        stringr::str_c(
          "Object is of class '", vec_classes_bad, "', not a data frame."
        ),
        stringr::str_c(
          "Object has ", vec_rows[is_short], " row(s); the contract needs ",
          "at least ", value_min_rows, "."
        )
      ),
      file_name = c(
        vec_file_names[!is_frame],
        vec_file_names[is_frame][is_short]
      ),
      n_violations = c(
        base::rep(1L, base::sum(!is_frame)),
        base::rep(1L, base::sum(is_short))
      )
    )

  #--------------------------------------------------#
  ## Columns -----
  #--------------------------------------------------#

  data_findings_columns <-
    purrr::map2(
      .x = list_objects[is_frame],
      .y = vec_file_names[is_frame],
      .f = ~ diagnose_producer_columns(
        data_source = .x,
        list_columns = purrr::chuck(contract, "columns"),
        extra_columns = purrr::chuck(contract, "extra_columns"),
        contract_id = contract_id,
        file_name = .y
      )
    ) |>
    dplyr::bind_rows()

  #--------------------------------------------------#
  ## Variable values -----
  #--------------------------------------------------#

  data_findings_variables <-
    if (
      !base::is.null(list_variables)
    ) {
      value_column <-
        purrr::chuck(list_variables, "value_column")

      list_table <-
        purrr::chuck(list_variables, "table")

      vec_table_variables <-
        purrr::map_chr(
          .x = list_table,
          .f = ~ base::as.character(purrr::chuck(.x, "variable"))
        )

      purrr::pmap(
        .l = base::list(
          list_objects,
          vec_file_names,
          dplyr::pull(data_files, "variable"),
          is_frame
        ),
        .f = ~ {
          data_object <- ..1

          sel_variable <- ..3

          flag_checkable <-
            ..4 &&
            !base::is.na(sel_variable) &&
            value_column %in% base::names(data_object) &&
            base::is.atomic(data_object[[value_column]])

          if (
            flag_checkable
          ) {
            list_variable <-
              list_table[[base::match(sel_variable, vec_table_variables)]]

            diagnose_producer_values(
              vec_values = data_object[[value_column]],
              list_checks = purrr::pluck(list_variable, "checks"),
              nullable = TRUE,
              contract_id = contract_id,
              column = stringr::str_c(value_column, " [", sel_variable, "]"),
              file_name = ..2
            )
          }
        }
      ) |>
        dplyr::bind_rows()
    }

  #--------------------------------------------------#
  ## Keys and dependencies over all files of a group -----
  #--------------------------------------------------#

  list_keys <-
    purrr::chuck(contract, "keys")

  list_rounded_keys <-
    purrr::pluck(contract, "rounded_keys", .default = base::list())

  list_dependencies <-
    purrr::chuck(contract, "dependencies")

  vec_rule_columns <-
    c(
      base::unlist(list_keys, use.names = FALSE),
      purrr::map(
        .x = list_rounded_keys,
        .f = ~ purrr::chuck(.x, "columns")
      ) |>
        base::unlist(use.names = FALSE),
      purrr::map(
        .x = list_dependencies,
        .f = ~ c(
          purrr::chuck(.x, "determinant"),
          purrr::chuck(.x, "dependent")
        )
      ) |>
        base::unlist(use.names = FALSE)
    ) |>
    base::as.character() |>
    base::unique()

  # Without variables all objects form one group; with variables, objects
  #   whose variable is unknown cannot be grouped and are left out
  vec_groups <-
    if (
      base::is.null(list_variables)
    ) {
      base::rep("", base::length(list_objects))
    } else {
      dplyr::pull(data_files, "variable")
    }

  vec_group_values <-
    base::unique(vec_groups[is_frame & !base::is.na(vec_groups)])

  data_findings_rules <-
    if (
      base::length(vec_rule_columns) > 0L
    ) {
      purrr::map(
        .x = vec_group_values,
        .f = ~ {
          sel_group <- .x

          is_in_group <-
            is_frame & !base::is.na(vec_groups) & vec_groups == sel_group

          # Objects whose key columns have clashing types cannot be bound;
          #   their class problems are already reported per column
          data_union <-
            base::tryCatch(
              expr = list_objects[is_in_group] |>
                purrr::map(
                  .f = ~ dplyr::select(.x, dplyr::any_of(vec_rule_columns))
                ) |>
                dplyr::bind_rows(),
              error = function(error) NULL
            )

          if (
            !base::is.null(data_union)
          ) {
            diagnose_producer_table_rules(
              data_source = data_union,
              list_keys = list_keys,
              list_dependencies = list_dependencies,
              contract_id = contract_id,
              scope_label = base::ifelse(
                sel_group == "",
                "the artefact",
                stringr::str_c("variable ", sel_group)
              ),
              list_rounded_keys = list_rounded_keys
            )
          }
        }
      ) |>
        dplyr::bind_rows()
    }

  res <-
    dplyr::bind_rows(
      build_producer_findings(
        contract_id = contract_id,
        check = base::character(0),
        message = base::character(0)
      ),
      data_findings_files,
      data_findings_objects,
      data_findings_columns,
      data_findings_variables,
      data_findings_rules
    )

  return(res)
}
