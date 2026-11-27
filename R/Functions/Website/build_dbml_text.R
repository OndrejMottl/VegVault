#' @title Build the DBML text of some tables
#' @description
#' Write a DBML description of selected tables of a DBML structure, with
#' their columns and the references among them, for a schema diagram of
#' part of the database.
#' @param list_dbml_structure
#' Named list. The structure of a DBML file, as returned by
#' `load_dbml_structure()`, with the tibbles `columns` (`table_name`,
#' `column_name`, `column_type`, `flag_primary_key`, `flag_not_null`)
#' and `references` (`table_name`, `column_name`, `ref_table_name`,
#' `ref_column_name`).
#' @param vec_tables
#' Character vector. Names of the tables to write; at least one, each a
#' table of `list_dbml_structure`.
#' @return
#' Character scalar: the DBML text, with lines separated by `"\n"` and a
#' final line break.
#' @details
#' The tables are written in the order of `vec_tables`, separated by an
#' empty line, each column on its own line in the order of the structure,
#' as `<name> <type>`, followed by its settings in brackets: `pk` for the
#' column of a single-column primary key and `not null` for a column that
#' may not be empty (`[pk, not null]` when both apply). A primary key of
#' several columns is written as an `indexes` block with a `[pk]` entry
#' after the columns. After an empty line follows one
#' `Ref: <table>.<column> > <table>.<column>` line per reference whose two
#' tables are both written, in the order of the structure; without such a
#' reference, the text ends after the last table. Reading the text with
#' `load_dbml_structure()` gives the same columns and references for these
#' tables. Aborts when `vec_tables` is empty, holds a missing or
#' repeated name, or names a table that `list_dbml_structure` does not
#' have.
#' @seealso [load_dbml_structure()], [select_linked_tables()]
#' @examples
#' \dontrun{
#' text_dbml <-
#'   build_dbml_text(
#'     list_dbml_structure = list_dbml_structure,
#'     vec_tables = c("TraitsValue", "Traits")
#'   )
#' }
build_dbml_text <- function(
  list_dbml_structure,
  vec_tables
) {
  assertthat::assert_that(
    base::is.character(vec_tables),
    base::length(vec_tables) > 0L,
    !base::anyNA(vec_tables),
    !base::anyDuplicated(vec_tables),
    msg = "`vec_tables` must be one or more distinct table names."
  )

  data_columns <-
    purrr::chuck(list_dbml_structure, "columns")

  vec_tables_unknown <-
    base::setdiff(vec_tables, dplyr::pull(data_columns, table_name))

  if (
    base::length(vec_tables_unknown) > 0L
  ) {
    cli::cli_abort(
      "The DBML structure has no table {.val {vec_tables_unknown}}."
    )
  }

  # One line per column; a key of several columns is written as an
  #   indexes block instead of a setting of its columns
  data_column_lines <-
    data_columns |>
    dplyr::filter(table_name %in% vec_tables) |>
    dplyr::group_by(table_name) |>
    dplyr::mutate(
      flag_composite_key = base::sum(flag_primary_key) > 1L
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      text_settings = dplyr::case_when(
        flag_primary_key & !flag_composite_key & flag_not_null ~
          " [pk, not null]",
        flag_primary_key & !flag_composite_key ~ " [pk]",
        flag_not_null ~ " [not null]",
        .default = ""
      ),
      text_line = stringr::str_c(
        "  ", column_name, " ", column_type, text_settings
      )
    )

  vec_table_blocks <-
    data_column_lines |>
    dplyr::group_by(table_name) |>
    dplyr::summarise(
      text_columns = stringr::str_c(text_line, collapse = "\n"),
      text_key = dplyr::if_else(
        dplyr::first(flag_composite_key),
        stringr::str_c(
          "\n  indexes {\n    (",
          stringr::str_c(column_name[flag_primary_key], collapse = ", "),
          ") [pk]\n  }"
        ),
        ""
      ),
      .groups = "drop"
    ) |>
    dplyr::arrange(base::match(table_name, vec_tables)) |>
    dplyr::mutate(
      text_block = stringr::str_c(
        "Table ", table_name, " {\n", text_columns, text_key, "\n}\n"
      )
    ) |>
    dplyr::pull(text_block)

  vec_reference_lines <-
    list_dbml_structure |>
    purrr::chuck("references") |>
    dplyr::filter(
      table_name %in% vec_tables,
      ref_table_name %in% vec_tables
    ) |>
    dplyr::mutate(
      text_line = stringr::str_c(
        "Ref: ", table_name, ".", column_name, " > ",
        ref_table_name, ".", ref_column_name, "\n"
      )
    ) |>
    dplyr::pull(text_line)

  text_tables <-
    stringr::str_c(vec_table_blocks, collapse = "\n")

  res <-
    if (
      base::length(vec_reference_lines) > 0L
    ) {
      stringr::str_c(
        text_tables,
        "\n",
        stringr::str_c(vec_reference_lines, collapse = "")
      )
    } else {
      text_tables
    }

  return(res)
}
