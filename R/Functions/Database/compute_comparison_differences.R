#' @title Compute the rows that differ between two sets of rows
#' @description
#' List the distinct rows of one kind that v1.0.0 and a 2.0.0 build do not
#' hold the same number of times, with the count on each side, so that a
#' difference found by `compute_comparison_summary()` can be inspected.
#' @param data_v1
#' A data frame with the column `scope` and the key columns: the rows of
#' v1.0.0.
#' @param data_v2
#' A data frame with the same columns, in any order: the rows of the 2.0.0
#' build.
#' @return
#' A tibble with the columns of `data_v1` and `n_v1` and `n_v2` (doubles),
#' one row per distinct row whose counts differ, sorted by its columns in
#' the C locale; no rows when the two sides are equal.
#' @details
#' Rows are compared as multisets, as in `compute_comparison_summary()`.
#' Aborts when the two sides do not have the same columns.
#' @seealso [compute_comparison_summary()]
#' @examples
#' \dontrun{
#' compute_comparison_differences(
#'   data_v1 = data_v1_samples,
#'   data_v2 = data_v2_samples
#' )
#' }
compute_comparison_differences <- function(
  data_v1,
  data_v2
) {
  assertthat::assert_that(
    base::is.data.frame(data_v1),
    "scope" %in% base::names(data_v1),
    msg = "`data_v1` must be a data frame with the column `scope`."
  )

  assertthat::assert_that(
    base::is.data.frame(data_v2),
    "scope" %in% base::names(data_v2),
    msg = "`data_v2` must be a data frame with the column `scope`."
  )

  vec_columns <-
    base::names(data_v1)

  if (
    !base::setequal(vec_columns, base::names(data_v2)) ||
      base::anyDuplicated(base::names(data_v2)) > 0L
  ) {
    cli::cli_abort(
      c(
        "The two sides must have the same columns.",
        "i" = "v1.0.0: {.field {vec_columns}}.",
        "i" = "2.0.0: {.field {base::names(data_v2)}}."
      )
    )
  }

  # Each distinct row with how many times each side holds it; missing
  #   values match each other
  data_counts <-
    dplyr::full_join(
      dplyr::count(data_v1, dplyr::across(dplyr::everything()), name = "n_v1"),
      dplyr::select(data_v2, dplyr::all_of(vec_columns)) |>
        dplyr::count(dplyr::across(dplyr::everything()), name = "n_v2"),
      by = vec_columns,
      na_matches = "na",
      relationship = "one-to-one"
    ) |>
    dplyr::mutate(
      n_v1 = dplyr::coalesce(base::as.double(n_v1), 0),
      n_v2 = dplyr::coalesce(base::as.double(n_v2), 0)
    )

  res <-
    data_counts |>
    dplyr::filter(n_v1 != n_v2) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(vec_columns)), .locale = "C")

  return(res)
}
