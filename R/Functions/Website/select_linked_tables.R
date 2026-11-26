#' @title Select tables and the tables linked to them
#' @description
#' Choose the tables that a schema diagram of some tables shows: the
#' tables themselves and every table that refers to one of them or that
#' one of them refers to.
#' @param list_dbml_structure
#' Named list. The structure of a DBML file, as returned by
#' `load_dbml_structure()`, with the tibbles `columns` (with
#' `table_name`) and `references` (with `table_name` and
#' `ref_table_name`).
#' @param vec_tables
#' Character vector. Names of the tables the diagram is about; at least
#' one, each a table of `list_dbml_structure`.
#' @return
#' Character vector of unique table names: `vec_tables` in the given
#' order, then the linked tables in alphabetical order (radix sorting, the
#' same in every locale).
#' @details
#' Only direct links count: a table linked to a linked table is not
#' added. A reference of a table to itself adds nothing. Aborts when
#' `vec_tables` is empty, holds a missing or repeated name, or names a
#' table that `list_dbml_structure` does not have.
#' @seealso [load_dbml_structure()], [build_dbml_text()]
#' @examples
#' \dontrun{
#' vec_tables_diagram <-
#'   select_linked_tables(
#'     list_dbml_structure = load_dbml_structure(
#'       path_dbml = here::here("Data", "SQL", "database_structure.dbml")
#'     ),
#'     vec_tables = "TraitsValue"
#'   )
#' }
select_linked_tables <- function(
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

  vec_tables_known <-
    list_dbml_structure |>
    purrr::chuck("columns") |>
    dplyr::pull(table_name) |>
    base::unique()

  vec_tables_unknown <-
    base::setdiff(vec_tables, vec_tables_known)

  if (
    base::length(vec_tables_unknown) > 0L
  ) {
    cli::cli_abort(
      "The DBML structure has no table {.val {vec_tables_unknown}}."
    )
  }

  data_references <-
    purrr::chuck(list_dbml_structure, "references")

  # Tables at the other end of a reference from or to one of the tables
  vec_tables_linked <-
    c(
      data_references |>
        dplyr::filter(table_name %in% vec_tables) |>
        dplyr::pull(ref_table_name),
      data_references |>
        dplyr::filter(ref_table_name %in% vec_tables) |>
        dplyr::pull(table_name)
    ) |>
    base::unique() |>
    base::setdiff(vec_tables) |>
    base::sort(method = "radix")

  res <-
    c(vec_tables, vec_tables_linked)

  return(res)
}
