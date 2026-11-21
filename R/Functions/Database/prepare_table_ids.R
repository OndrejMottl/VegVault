#' @title Prepare deterministic ids for the rows of a database table
#' @description
#' Give every row of an in-memory table an integer id, numbered from 1 in
#' the order of its natural key, so that the same rows always get the same
#' ids, whatever order they arrive in.
#' @param data_table
#' A data frame with one row per future database row, holding the columns
#' named in `vec_sort_columns`.
#' @param vec_sort_columns
#' Character vector of column names of `data_table`. They order the rows
#' and together must identify every row: the natural key, optionally
#' preceded by a block column such as the order of the sources.
#' @param name_id
#' Character scalar. Name of the id column to add, for example
#' `"dataset_id"`. It must not be a column of `data_table`.
#' @param name_table
#' Character scalar. Name of the database table, used in error messages.
#' @return
#' A tibble with the id column first, as integers 1 to the number of rows,
#' followed by the columns of `data_table`, with the rows sorted by
#' `vec_sort_columns`.
#' @details
#' Rows are sorted with `dplyr::arrange()`, which compares text in the C
#' locale, so the order does not depend on the language settings of the
#' machine. Aborts, naming the table and up to five keys, when a value of
#' `vec_sort_columns` is missing or when two rows share the same values of
#' `vec_sort_columns`. A table with no rows gives a table with no rows and
#' an empty integer id column.
#' @seealso [prepare_table_foreign_key()], [save_vegvault_database()]
#' @examples
#' \dontrun{
#' data_datasets_with_ids <-
#'   prepare_table_ids(
#'     data_table = data_datasets,
#'     vec_sort_columns = c("source_order", "dataset_name"),
#'     name_id = "dataset_id",
#'     name_table = "Datasets"
#'   )
#' }
prepare_table_ids <- function(
  data_table,
  vec_sort_columns,
  name_id,
  name_table
) {
  assertthat::assert_that(
    base::is.data.frame(data_table),
    msg = "`data_table` must be a data frame."
  )

  assertthat::assert_that(
    base::is.character(vec_sort_columns),
    base::length(vec_sort_columns) >= 1L,
    !base::anyNA(vec_sort_columns),
    base::all(vec_sort_columns %in% base::names(data_table)),
    msg = "`vec_sort_columns` must name one or more columns of `data_table`."
  )

  assertthat::assert_that(
    base::is.character(name_id),
    base::length(name_id) == 1L,
    !base::is.na(name_id),
    base::nzchar(name_id),
    !(name_id %in% base::names(data_table)),
    msg = "`name_id` must be one name that is not a column of `data_table`."
  )

  assertthat::assert_that(
    base::is.character(name_table),
    base::length(name_table) == 1L,
    !base::is.na(name_table),
    base::nzchar(name_table),
    msg = "`name_table` must be a non-empty character scalar."
  )

  data_keys <-
    dplyr::select(
      data_table,
      dplyr::all_of(vec_sort_columns)
    )

  vec_missing_key <-
    data_keys |>
    purrr::map(.f = base::is.na) |>
    purrr::reduce(.f = ~ .x | .y)

  if (
    base::any(vec_missing_key)
  ) {
    n_missing_key <-
      base::sum(vec_missing_key)

    cli::cli_abort(
      c(
        "Table {.val {name_table}}: {n_missing_key} row{?s} with a missing
        value in {.field {vec_sort_columns}}.",
        "i" = "Every row needs its full natural key to get an id."
      )
    )
  }

  data_repeated <-
    data_keys |>
    dplyr::count(
      dplyr::pick(dplyr::everything()),
      name = "n_rows"
    ) |>
    dplyr::filter(n_rows > 1L)

  if (
    base::nrow(data_repeated) > 0L
  ) {
    vec_examples <-
      data_repeated |>
      dplyr::slice_head(n = 5L) |>
      tidyr::unite(
        col = "key_text",
        dplyr::all_of(vec_sort_columns),
        sep = " | "
      ) |>
      dplyr::pull(key_text)

    cli::cli_abort(
      c(
        "Table {.val {name_table}}: {base::nrow(data_repeated)} key{?s}
        repeat in {.field {vec_sort_columns}}.",
        "x" = "First repeated key{?s}: {.val {vec_examples}}."
      )
    )
  }

  res <-
    data_table |>
    dplyr::arrange(
      dplyr::pick(dplyr::all_of(vec_sort_columns)),
      .locale = "C"
    ) |>
    dplyr::mutate(
      "{name_id}" := base::seq_len(dplyr::n()),
      .before = 1L
    ) |>
    tibble::as_tibble()

  return(res)
}
