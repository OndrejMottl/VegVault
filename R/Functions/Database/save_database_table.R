#' @title Save the rows of one table into a database in key order
#' @description
#' Append the rows of an in-memory table to an existing table of a SQLite
#' database, sorted by the primary key of the table, in batches of one
#' transaction each. Nothing is read back from the table.
#' @param con
#' A valid read-write `DBI` connection to a SQLite database that holds the
#' table.
#' @param data_table
#' A data frame whose columns are all columns of the database table.
#' Columns of the table that it lacks get their default, normally a
#' missing value.
#' @param name_table
#' Character scalar. Name of the database table.
#' @param n_chunk_size
#' Whole number of at least 1. Rows per batch; each batch is written in
#' its own transaction.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' Invisibly, a tibble with one row: `table_name` (text), `n_rows` and
#' `n_chunks` (integers).
#' @details
#' The columns and the primary key are read from `PRAGMA table_info` and
#' the object type from `PRAGMA table_list`, never from the rows. Rows are
#' sorted by the primary key (a table without one by all of its columns,
#' in table order), because rows load fastest in key order into a
#' `WITHOUT ROWID` table and the order is then the same in every build.
#' Rows are written with plain `INSERT` statements through
#' `DBI::dbAppendTable()`, so the keys and the `UNIQUE`, `NOT NULL` and
#' `CHECK` constraints of the table reject a bad row. A failed batch is
#' rolled back and the function aborts with an error that names the
#' table, the batch and the message of the database; the batches before
#' it stay written, so the caller discards the file. A rollback needs a
#' journal: with `journal_mode = OFF` SQLite cannot undo a transaction.
#' Aborts before writing when the table does not exist or is a view, when
#' `data_table` has a column that the table lacks, or when it lacks a
#' `NOT NULL` column without a default. A table with no rows writes
#' nothing and counts no batch.
#' @seealso [run_database_load()]
#' @examples
#' \dontrun{
#' run_with_database(
#'   path_database = path_work,
#'   fn = save_database_table,
#'   data_table = data_datasets,
#'   name_table = "Datasets",
#'   n_chunk_size = 100000L
#' )
#' }
save_database_table <- function(
  con,
  data_table,
  name_table,
  n_chunk_size,
  verbose = TRUE
) {
  assertthat::assert_that(
    methods::is(con, "DBIConnection"),
    DBI::dbIsValid(con),
    msg = "`con` must be a valid DBI connection."
  )

  assertthat::assert_that(
    base::is.data.frame(data_table),
    msg = "`data_table` must be a data frame."
  )

  assertthat::assert_that(
    base::is.character(name_table),
    base::length(name_table) == 1L,
    !base::is.na(name_table),
    base::nzchar(name_table),
    msg = "`name_table` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.numeric(n_chunk_size),
    base::length(n_chunk_size) == 1L,
    !base::is.na(n_chunk_size),
    base::is.finite(n_chunk_size),
    n_chunk_size >= 1,
    n_chunk_size == base::round(n_chunk_size),
    msg = "`n_chunk_size` must be a whole number of at least 1."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # The object type comes from the schema list, never from the rows
  data_object <-
    DBI::dbGetQuery(
      conn = con,
      statement = "PRAGMA table_list"
    ) |>
    dplyr::filter(
      schema == "main",
      name == name_table
    )

  if (
    base::nrow(data_object) == 0L
  ) {
    cli::cli_abort(
      "Table {.val {name_table}} does not exist in the database."
    )
  }

  if (
    dplyr::pull(data_object, type) != "table"
  ) {
    cli::cli_abort(
      c(
        "{.val {name_table}} is a {dplyr::pull(data_object, type)}, not a
        table.",
        "i" = "Rows can only be written to tables."
      )
    )
  }

  data_columns <-
    DBI::dbGetQuery(
      conn = con,
      statement = stringr::str_c(
        "PRAGMA table_info(",
        DBI::dbQuoteIdentifier(conn = con, x = name_table),
        ")"
      )
    )

  vec_unknown_columns <-
    base::setdiff(
      base::names(data_table),
      dplyr::pull(data_columns, name)
    )

  if (
    base::length(vec_unknown_columns) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.arg data_table} has {base::length(vec_unknown_columns)}
        column{?s} that table {.val {name_table}} lacks:
        {.field {vec_unknown_columns}}."
      )
    )
  }

  vec_required_columns <-
    data_columns |>
    dplyr::filter(
      notnull == 1L,
      base::is.na(dflt_value)
    ) |>
    dplyr::pull(name)

  vec_absent_required <-
    base::setdiff(vec_required_columns, base::names(data_table))

  if (
    base::length(vec_absent_required) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.arg data_table} lacks {base::length(vec_absent_required)} NOT
        NULL column{?s} of table {.val {name_table}}:
        {.field {vec_absent_required}}."
      )
    )
  }

  vec_key_columns <-
    data_columns |>
    dplyr::filter(pk > 0L) |>
    dplyr::arrange(pk) |>
    dplyr::pull(name) |>
    base::intersect(base::names(data_table))

  # A table without a key is sorted by all of its columns, in table order
  vec_sort_columns <-
    if (
      base::length(vec_key_columns) > 0L
    ) {
      vec_key_columns
    } else {
      base::intersect(
        dplyr::pull(data_columns, name),
        base::names(data_table)
      )
    }

  data_sorted <-
    dplyr::arrange(
      data_table,
      dplyr::pick(dplyr::all_of(vec_sort_columns)),
      .locale = "C"
    )

  n_rows <-
    base::nrow(data_sorted)

  n_chunks <-
    base::as.integer(base::ceiling(n_rows / n_chunk_size))

  purrr::walk(
    .x = base::seq_len(n_chunks),
    .f = ~ {
      index_chunk <- .x

      vec_rows <-
        base::seq(
          from = (index_chunk - 1L) * n_chunk_size + 1L,
          to = base::min(index_chunk * n_chunk_size, n_rows)
        )

      data_chunk <-
        dplyr::slice(data_sorted, vec_rows)

      # A plain INSERT per row: the constraints of the table decide, and a
      #   failed batch is rolled back before the error is raised
      base::tryCatch(
        DBI::dbWithTransaction(
          conn = con,
          code = DBI::dbAppendTable(
            conn = con,
            name = name_table,
            value = data_chunk
          )
        ),
        error = function(error_write) {
          cli::cli_abort(
            c(
              "Writing table {.val {name_table}} failed in batch
              {index_chunk} of {n_chunks}.",
              "x" = "{base::conditionMessage(error_write)}",
              "i" = "The batch was rolled back; earlier batches stay
              written, so discard the file."
            )
          )
        }
      )
    }
  )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      "Saved {n_rows} row{?s} to {.val {name_table}} in {n_chunks}
      batch{?es}."
    )
  }

  res <-
    tibble::tibble(
      table_name = name_table,
      n_rows = base::as.integer(n_rows),
      n_chunks = n_chunks
    )

  return(invisible(res))
}
