#' @title Prepare a foreign key from the ids of the parent table
#' @description
#' Add the id of the parent row to every row of a child table, matched by
#' the natural key of the parent, so that foreign keys are resolved in
#' memory and no table is read back from the database.
#' @param data_child
#' A data frame holding the natural-key columns of the parent
#' (`vec_key_columns`).
#' @param data_parent
#' A data frame with the id column `name_id` and the natural-key columns
#' `vec_key_columns`, one row per key, as returned by
#' `prepare_table_ids()`.
#' @param vec_key_columns
#' Character vector. The natural-key columns that both tables hold.
#' @param name_id
#' Character scalar. The integer id column of `data_parent` to add to
#' `data_child`. It must not be a column of `data_child`.
#' @param name_table
#' Character scalar. Name of the child table, used in error messages.
#' @param flag_allow_missing
#' Logical scalar. If `TRUE`, a child row whose key is missing in every
#' key column gets a missing id (an optional foreign key). If `FALSE`
#' (default), such a row aborts.
#' @return
#' A tibble: the rows of `data_child` in their original order, with the
#' integer column `name_id` added as the last column.
#' @details
#' Aborts, naming the child table, the id and up to five keys, when a
#' child key has no parent row, when a child key is missing in some but
#' not all key columns, or when a key is missing and `flag_allow_missing`
#' is `FALSE`. Aborts when `data_parent` repeats a key or misses an id,
#' because the join would then multiply or lose child rows. Keys are
#' compared exactly, so text must match in case and spaces.
#' @seealso [prepare_table_ids()], [save_vegvault_database()]
#' @examples
#' \dontrun{
#' data_samples_with_size <-
#'   prepare_table_foreign_key(
#'     data_child = data_samples,
#'     data_parent = data_sample_sizes,
#'     vec_key_columns = c("sample_size", "description"),
#'     name_id = "sample_size_id",
#'     name_table = "Samples",
#'     flag_allow_missing = TRUE
#'   )
#' }
prepare_table_foreign_key <- function(
  data_child,
  data_parent,
  vec_key_columns,
  name_id,
  name_table,
  flag_allow_missing = FALSE
) {
  assertthat::assert_that(
    base::is.data.frame(data_child),
    msg = "`data_child` must be a data frame."
  )

  assertthat::assert_that(
    base::is.character(name_id),
    base::length(name_id) == 1L,
    !base::is.na(name_id),
    base::nzchar(name_id),
    msg = "`name_id` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.data.frame(data_parent),
    name_id %in% base::names(data_parent),
    msg = "`data_parent` must be a data frame holding the column `name_id`."
  )

  assertthat::assert_that(
    base::is.character(vec_key_columns),
    base::length(vec_key_columns) >= 1L,
    !base::anyNA(vec_key_columns),
    base::all(vec_key_columns %in% base::names(data_child)),
    base::all(vec_key_columns %in% base::names(data_parent)),
    !(name_id %in% vec_key_columns),
    msg = stringr::str_c(
      "`vec_key_columns` must name key columns of both `data_child` and ",
      "`data_parent`."
    )
  )

  assertthat::assert_that(
    !(name_id %in% base::names(data_child)),
    msg = "`name_id` must not be a column of `data_child`."
  )

  assertthat::assert_that(
    base::is.character(name_table),
    base::length(name_table) == 1L,
    !base::is.na(name_table),
    base::nzchar(name_table),
    msg = "`name_table` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.logical(flag_allow_missing),
    base::length(flag_allow_missing) == 1L,
    !base::is.na(flag_allow_missing),
    msg = "`flag_allow_missing` must be TRUE or FALSE."
  )

  data_parent_keys <-
    dplyr::select(
      data_parent,
      dplyr::all_of(c(vec_key_columns, name_id))
    )

  if (
    base::anyNA(dplyr::pull(data_parent_keys, dplyr::all_of(name_id)))
  ) {
    cli::cli_abort(
      "The parent of table {.val {name_table}} has missing ids in
      {.field {name_id}}."
    )
  }

  n_parent_keys <-
    data_parent_keys |>
    dplyr::distinct(dplyr::pick(dplyr::all_of(vec_key_columns))) |>
    base::nrow()

  if (
    n_parent_keys < base::nrow(data_parent_keys)
  ) {
    cli::cli_abort(
      c(
        "The parent of table {.val {name_table}} has keys that repeat in
        {.field {vec_key_columns}}.",
        "i" = "Each key must have one {.field {name_id}}."
      )
    )
  }

  vec_n_missing <-
    data_child |>
    dplyr::select(dplyr::all_of(vec_key_columns)) |>
    purrr::map(.f = ~ base::as.integer(base::is.na(.x))) |>
    purrr::reduce(.f = ~ .x + .y)

  vec_partly_missing <-
    vec_n_missing > 0L &
    vec_n_missing < base::length(vec_key_columns)

  if (
    base::any(vec_partly_missing)
  ) {
    cli::cli_abort(
      c(
        "Table {.val {name_table}}: {base::sum(vec_partly_missing)} row{?s}
        with a partly missing key in {.field {vec_key_columns}}.",
        "i" = "A key is either complete or missing in every column."
      )
    )
  }

  vec_all_missing <-
    vec_n_missing == base::length(vec_key_columns)

  if (
    base::any(vec_all_missing) &&
      !base::isTRUE(flag_allow_missing)
  ) {
    cli::cli_abort(
      c(
        "Table {.val {name_table}}: {base::sum(vec_all_missing)} row{?s}
        with a missing key for {.field {name_id}}.",
        "i" = "Set {.arg flag_allow_missing} for an optional foreign key."
      )
    )
  }

  data_joined <-
    dplyr::left_join(
      data_child,
      data_parent_keys,
      by = dplyr::join_by(!!!rlang::syms(vec_key_columns)),
      relationship = "many-to-one",
      na_matches = "never"
    )

  vec_unmatched <-
    base::is.na(dplyr::pull(data_joined, dplyr::all_of(name_id))) &
    !vec_all_missing

  if (
    base::any(vec_unmatched)
  ) {
    vec_examples <-
      data_joined |>
      dplyr::filter(vec_unmatched) |>
      dplyr::distinct(dplyr::pick(dplyr::all_of(vec_key_columns))) |>
      dplyr::slice_head(n = 5L) |>
      tidyr::unite(
        col = "key_text",
        dplyr::all_of(vec_key_columns),
        sep = " | "
      ) |>
      dplyr::pull(key_text)

    cli::cli_abort(
      c(
        "Table {.val {name_table}}: {base::sum(vec_unmatched)} row{?s}
        without a parent for {.field {name_id}}.",
        "x" = "First {base::length(vec_examples)} unmatched key{?s} in
        {.field {vec_key_columns}}: {.val {vec_examples}}."
      )
    )
  }

  res <-
    data_joined |>
    dplyr::mutate(
      "{name_id}" := base::as.integer(.data[[name_id]])
    ) |>
    tibble::as_tibble()

  return(res)
}
