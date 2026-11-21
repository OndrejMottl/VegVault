#' @title Prepare the ids of a lookup table from the values of all sources
#' @description
#' Collect the distinct values of a lookup table (such as the dataset types
#' or the taxa) from the tables of all sources and number them: first by
#' the first source that uses a value, then by the value itself.
#' @param data_values
#' A data frame with the integer column `source_order` (the position of
#' the source in the build) and the key columns `vec_key_columns`, one row
#' per use of a value.
#' @param vec_key_columns
#' Character vector. The columns that form the value, for example
#' `"taxon_name"` or `c("sample_size", "sample_size_description")`.
#' @param name_id
#' Character scalar. Name of the id column, for example `"taxon_id"`.
#' @param name_table
#' Character scalar. Name of the lookup table, used in error messages.
#' @return
#' A tibble with the id column (integers from 1) and `vec_key_columns`, one
#' row per distinct value, sorted by id.
#' @details
#' Rows whose key is missing in every key column are not values and are
#' dropped; a key missing in some columns only aborts (see
#' `prepare_table_ids()`). Because ids follow the first source of a value,
#' a source added at the end of the build does not shift the ids of the
#' values that earlier sources already use; the dataset types of v1.0.0
#' get their v1.0.0 ids this way.
#' @seealso [prepare_table_ids()], [build_database_tables()]
#' @examples
#' \dontrun{
#' data_taxa <-
#'   prepare_lookup_ids(
#'     data_values = data_taxon_uses,
#'     vec_key_columns = "taxon_name",
#'     name_id = "taxon_id",
#'     name_table = "Taxa"
#'   )
#' }
prepare_lookup_ids <- function(
  data_values,
  vec_key_columns,
  name_id,
  name_table
) {
  assertthat::assert_that(
    base::is.data.frame(data_values),
    "source_order" %in% base::names(data_values),
    msg = "`data_values` must be a data frame with the column `source_order`."
  )

  assertthat::assert_that(
    base::is.character(vec_key_columns),
    base::length(vec_key_columns) >= 1L,
    base::all(vec_key_columns %in% base::names(data_values)),
    !("source_order" %in% vec_key_columns),
    msg = "`vec_key_columns` must name key columns of `data_values`."
  )

  vec_all_missing <-
    data_values |>
    dplyr::select(dplyr::all_of(vec_key_columns)) |>
    purrr::map(.f = base::is.na) |>
    purrr::reduce(.f = ~ .x & .y)

  # The first use of each value, by the order of the sources
  data_first_use <-
    data_values |>
    dplyr::filter(!vec_all_missing) |>
    dplyr::select(dplyr::all_of(c("source_order", vec_key_columns))) |>
    dplyr::arrange(source_order) |>
    dplyr::distinct(
      dplyr::pick(dplyr::all_of(vec_key_columns)),
      .keep_all = TRUE
    )

  res <-
    prepare_table_ids(
      data_table = data_first_use,
      vec_sort_columns = c("source_order", vec_key_columns),
      name_id = name_id,
      name_table = name_table
    ) |>
    dplyr::select(dplyr::all_of(c(name_id, vec_key_columns)))

  return(res)
}
