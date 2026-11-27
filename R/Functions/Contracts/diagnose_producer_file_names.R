#' @title Diagnose the file names of a producer artefact
#' @description
#' Check the names of the files that make up one producer artefact against
#' its contract: every name matches the contract's pattern, partitions are
#' neither duplicated nor missing, and every expected variable has files.
#' @param vec_file_names
#' Character vector of file base names: all files of the artefact, that
#' is every partition and, for contracts with variables, every variable
#' (or every variable in `vec_variables`).
#' @param contract
#' A contract as returned by `load_producer_contract()`.
#' @param vec_variables
#' Character vector of the variables that must have files, for checking
#' one or some variables at a time; `NULL` (default) expects every
#' variable of the contract. Only for contracts with `variables`.
#' @return
#' A findings tibble as built by `build_producer_findings()`, with `column`
#' set to `NA`. Zero rows when the names satisfy the contract.
#' @details
#' The checks, named in the `check` column, are:
#' `no_files` (no names given); `file_name_pattern` (a name matches no
#' pattern; such files are left out of the other checks);
#' `file_duplicate` (more than one file for the same partition, or, for
#' the scheme `"none"`, more than one file per variable or artefact, for
#' example two dates of the same output; integer partitions are compared
#' as numbers, so `1` and `01` are the same); `partition_gap` (a
#' partition between `partitioning$first` and the last partition present
#' is missing, when `partitioning$contiguous` is `TRUE`);
#' `partition_unexpected` (a partition before `partitioning$first`);
#' `partition_count` (the number of distinct partitions differs from
#' `partitioning$count`, when it is given); and `variable_missing` (an
#' expected variable has no file). Partitions are counted separately for
#' every variable. Aborts when `vec_variables` names a variable the
#' contract does not have.
diagnose_producer_file_names <- function(
  vec_file_names,
  contract,
  vec_variables = NULL
) {
  contract_id <-
    purrr::chuck(contract, "contract_id")

  vec_table_variables <-
    purrr::pluck(contract, "variables", "table", .default = base::list()) |>
    purrr::map_chr(.f = ~ base::as.character(purrr::chuck(.x, "variable")))

  assertthat::assert_that(
    base::is.null(vec_variables) ||
      (
        base::is.character(vec_variables) &&
          base::length(vec_variables) > 0L &&
          base::all(vec_variables %in% vec_table_variables)
      ),
    msg = "'vec_variables' must be NULL or variables of the contract."
  )

  if (
    base::length(vec_file_names) == 0L
  ) {
    res_empty <-
      build_producer_findings(
        contract_id = contract_id,
        check = "no_files",
        message = "No files were given for the artefact."
      )

    return(res_empty)
  }

  data_files <-
    build_producer_file_table(
      vec_file_names = vec_file_names,
      contract = contract
    )

  vec_templates <-
    purrr::chuck(contract, "file", "name_templates")

  scheme <-
    purrr::chuck(contract, "partitioning", "scheme")

  flag_contiguous <-
    purrr::chuck(contract, "partitioning", "contiguous")

  # NA when the contract does not fix the number of partitions
  value_count <-
    purrr::pluck(
      contract, "partitioning", "count",
      .default = NA_integer_
    ) |>
    base::as.integer()

  vec_files_unmatched <-
    data_files |>
    dplyr::filter(!.data[["is_match"]]) |>
    dplyr::pull("file_name")

  data_findings_pattern <-
    build_producer_findings(
      contract_id = contract_id,
      check = base::rep("file_name_pattern", base::length(vec_files_unmatched)),
      message = base::rep(
        stringr::str_c(
          "File name does not match ",
          stringr::str_c("'", vec_templates, "'", collapse = " or "),
          "."
        ),
        base::length(vec_files_unmatched)
      ),
      file_name = vec_files_unmatched
    )

  # Files of a contract without variables form one group with an empty
  #   variable label. Partitions are compared by position: the number
  #   itself, or the position of the letter in the alphabet
  data_matched <-
    data_files |>
    dplyr::filter(.data[["is_match"]]) |>
    dplyr::mutate(
      group = dplyr::coalesce(.data[["variable"]], ""),
      group_label = dplyr::if_else(
        .data[["group"]] == "",
        "the artefact",
        stringr::str_c("variable ", .data[["group"]])
      ),
      position = base::switch(
        scheme,
        "none" = NA_integer_,
        "integer" = base::as.integer(.data[["partition"]]),
        "letter" = base::match(.data[["partition"]], base::LETTERS)
      ),
      partition_label = base::switch(
        scheme,
        "none" = NA_character_,
        "integer" = base::as.character(.data[["position"]]),
        "letter" = .data[["partition"]]
      )
    )

  data_duplicates <-
    data_matched |>
    dplyr::summarise(
      n_files = dplyr::n(),
      files = stringr::str_c(.data[["file_name"]], collapse = ", "),
      .by = c("group_label", "position", "partition_label")
    ) |>
    dplyr::filter(.data[["n_files"]] > 1L)

  data_findings_duplicate <-
    build_producer_findings(
      contract_id = contract_id,
      check = base::rep("file_duplicate", base::nrow(data_duplicates)),
      message = stringr::str_c(
        dplyr::pull(data_duplicates, "n_files"),
        " files for ",
        dplyr::pull(data_duplicates, "group_label"),
        dplyr::if_else(
          base::is.na(dplyr::pull(data_duplicates, "partition_label")),
          "",
          stringr::str_c(
            ", partition ",
            dplyr::pull(data_duplicates, "partition_label")
          )
        ),
        "; select exactly one: ",
        dplyr::pull(data_duplicates, "files"),
        "."
      ),
      n_violations = dplyr::pull(data_duplicates, "n_files")
    )

  data_findings_partitions <-
    if (
      scheme == "none"
    ) {
      NULL
    } else {
      value_first <-
        purrr::chuck(contract, "partitioning", "first")

      position_first <-
        base::switch(
          scheme,
          "integer" = base::as.integer(value_first),
          "letter" = base::match(value_first, base::LETTERS)
        )

      data_positions <-
        dplyr::distinct(
          data_matched,
          .data[["group_label"]],
          .data[["position"]],
          .data[["partition_label"]]
        )

      data_unexpected <-
        data_positions |>
        dplyr::filter(.data[["position"]] < position_first) |>
        dplyr::summarise(
          n_partitions = dplyr::n(),
          partitions = stringr::str_c(
            .data[["partition_label"]],
            collapse = ", "
          ),
          .by = "group_label"
        )

      data_gaps <-
        data_positions |>
        dplyr::filter(.data[["position"]] >= position_first) |>
        dplyr::summarise(
          missing = base::list(
            base::setdiff(
              base::seq(
                from = position_first,
                to = base::max(.data[["position"]])
              ),
              .data[["position"]]
            )
          ),
          .by = "group_label"
        ) |>
        dplyr::mutate(
          n_missing = purrr::map_int(.data[["missing"]], base::length),
          missing_labels = purrr::map_chr(
            .x = .data[["missing"]],
            .f = ~ {
              vec_labels <-
                base::switch(
                  scheme,
                  "integer" = base::as.character(.x),
                  "letter" = base::LETTERS[.x]
                )

              stringr::str_c(vec_labels, collapse = ", ")
            }
          )
        ) |>
        dplyr::filter(
          flag_contiguous,
          .data[["n_missing"]] > 0L
        )

      data_counts <-
        data_positions |>
        dplyr::count(.data[["group_label"]], name = "n_partitions") |>
        dplyr::filter(
          !base::is.na(value_count),
          .data[["n_partitions"]] != value_count
        )

      dplyr::bind_rows(
        build_producer_findings(
          contract_id = contract_id,
          check = base::rep("partition_gap", base::nrow(data_gaps)),
          message = stringr::str_c(
            "Partition(s) ", dplyr::pull(data_gaps, "missing_labels"),
            " missing for ", dplyr::pull(data_gaps, "group_label"),
            "; partitions start at ", value_first,
            " and must be contiguous."
          ),
          n_violations = dplyr::pull(data_gaps, "n_missing")
        ),
        build_producer_findings(
          contract_id = contract_id,
          check = base::rep(
            "partition_unexpected",
            base::nrow(data_unexpected)
          ),
          message = stringr::str_c(
            "Partition(s) ",
            dplyr::pull(data_unexpected, "partitions"),
            " of ", dplyr::pull(data_unexpected, "group_label"),
            " come before the first partition ", value_first, "."
          ),
          n_violations = dplyr::pull(data_unexpected, "n_partitions")
        ),
        build_producer_findings(
          contract_id = contract_id,
          check = base::rep("partition_count", base::nrow(data_counts)),
          message = stringr::str_c(
            dplyr::pull(data_counts, "n_partitions"),
            " partition(s) for ", dplyr::pull(data_counts, "group_label"),
            "; the contract expects ", value_count, "."
          ),
          n_violations = dplyr::pull(data_counts, "n_partitions")
        )
      )
    }

  vec_variables_expected <-
    if (
      base::is.null(vec_variables)
    ) {
      vec_table_variables
    } else {
      vec_variables
    }

  vec_variables_missing <-
    base::setdiff(
      vec_variables_expected,
      dplyr::pull(data_matched, "variable")
    ) |>
    base::as.character()

  data_findings_variables <-
    build_producer_findings(
      contract_id = contract_id,
      check = base::rep(
        "variable_missing",
        base::length(vec_variables_missing)
      ),
      message = stringr::str_c(
        "No file for variable ", vec_variables_missing, "."
      )
    )

  res <-
    dplyr::bind_rows(
      data_findings_pattern,
      data_findings_duplicate,
      data_findings_partitions,
      data_findings_variables
    )

  return(res)
}
