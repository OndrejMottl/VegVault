#' @title Build the file table of a producer artefact
#' @description
#' Parse the names of the files of one producer artefact with the
#' file-name patterns of its contract, giving one row per file with the
#' parts encoded in the name.
#' @param vec_file_names
#' Character vector of file base names (without directories).
#' @param contract
#' A contract as returned by `load_producer_contract()`.
#' @return
#' A tibble with one row per element of `vec_file_names`, in the same
#' order, and the columns `file_name`, `is_match` (logical: the name
#' matches one of the contract's patterns), `template_index` (integer:
#' the first matching template, `NA` when none matches), `extension`
#' (the text after the last dot), `date`, `hash`, `partition`,
#' `variable_token` and `variable` (all character; `NA` when the name
#' does not match or the template has no such part). `variable` is the
#' variable of the contract's `variables$table` whose `file_token` is
#' `variable_token`.
#' @details
#' Aborts when `vec_file_names` is not a character vector without
#' missing values or contains directory separators.
build_producer_file_table <- function(
  vec_file_names,
  contract
) {
  assertthat::assert_that(
    base::is.character(vec_file_names),
    !base::anyNA(vec_file_names),
    !base::any(stringr::str_detect(vec_file_names, "[/\\\\]")),
    msg = "'vec_file_names' must be file base names without missing values."
  )

  assertthat::assert_that(
    base::is.list(contract),
    base::is.character(
      purrr::pluck(contract, "file", "name_patterns")
    ),
    msg = "'contract' must be a contract from load_producer_contract()."
  )

  vec_patterns <-
    purrr::chuck(contract, "file", "name_patterns")

  n_files <-
    base::length(vec_file_names)

  list_matches <-
    purrr::map(
      .x = vec_patterns,
      .f = ~ stringr::str_match(string = vec_file_names, pattern = .x)
    )

  # The first template that matches a name wins
  vec_template_index <-
    list_matches |>
    purrr::imap(
      .f = ~ dplyr::if_else(
        condition = !base::is.na(.x[, 1]),
        true = base::as.integer(.y),
        false = NA_integer_
      )
    ) |>
    purrr::reduce(.f = dplyr::coalesce)

  vec_groups <-
    c(
      date = "date",
      hash = "hash",
      partition = "partition",
      variable_token = "variable"
    )

  list_parts <-
    purrr::map(
      .x = vec_groups,
      .f = ~ {
        name_group <- .x

        list_part_by_template <-
          purrr::map(
            .x = list_matches,
            .f = ~ {
              if (
                name_group %in% base::colnames(.x)
              ) {
                base::unname(.x[, name_group])
              } else {
                base::rep(NA_character_, n_files)
              }
            }
          )

        purrr::map_chr(
          .x = base::seq_len(n_files),
          .f = ~ {
            index_template <- vec_template_index[.x]

            if (
              base::is.na(index_template)
            ) {
              NA_character_
            } else {
              list_part_by_template[[index_template]][.x]
            }
          }
        )
      }
    )

  list_table <-
    purrr::pluck(contract, "variables", "table", .default = base::list())

  vec_table_tokens <-
    purrr::map_chr(
      .x = list_table,
      .f = ~ base::as.character(purrr::chuck(.x, "file_token"))
    )

  vec_table_variables <-
    purrr::map_chr(
      .x = list_table,
      .f = ~ base::as.character(purrr::chuck(.x, "variable"))
    )

  vec_variable <-
    vec_table_variables[
      base::match(
        purrr::chuck(list_parts, "variable_token"),
        vec_table_tokens
      )
    ]

  res <-
    tibble::tibble(
      file_name = vec_file_names,
      is_match = !base::is.na(vec_template_index),
      template_index = vec_template_index,
      extension = stringr::str_extract(vec_file_names, "(?<=[.])[^.]+$"),
      date = purrr::chuck(list_parts, "date"),
      hash = purrr::chuck(list_parts, "hash"),
      partition = purrr::chuck(list_parts, "partition"),
      variable_token = purrr::chuck(list_parts, "variable_token"),
      variable = base::as.character(vec_variable)
    )

  return(res)
}
