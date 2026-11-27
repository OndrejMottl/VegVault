#' @title Select one count of a VegVault release
#' @description
#' Return the count of one metric and scope from the saved counts of a
#' VegVault release, for a number that a page of the website prints.
#' @param data_counts
#' Data frame with the columns `metric` (character), `scope` (character)
#' and `n` (numeric), one row per count, such as
#' `Data/Versions/<version>/database_counts.csv` or the v1.0.0 reference
#' counts with `n_v1` renamed to `n`.
#' @param metric
#' Character scalar. The metric, such as `"table_rows"` or `"datasets"`.
#' @param scope
#' Character scalar. The scope of the metric, such as `"Samples"` or
#' `"traits / TRY"`.
#' @return
#' Numeric scalar: the value of `n` in the one row of `metric` and
#' `scope`. A missing value is returned as `NA`.
#' @details
#' Aborts when `data_counts` lacks one of the three columns, when `metric`
#' or `scope` is not a single non-missing string, and when no row or more
#' than one row has the metric and scope, so that a page never prints a
#' number that was not counted or is ambiguous.
#' @seealso [compute_database_counts()], [load_database_statistics()]
#' @examples
#' \dontrun{
#' select_version_count(
#'   data_counts = data_counts_2_0_0,
#'   metric = "table_rows",
#'   scope = "Samples"
#' )
#' }
select_version_count <- function(
  data_counts,
  metric,
  scope
) {
  assertthat::assert_that(
    base::is.data.frame(data_counts),
    base::all(c("metric", "scope", "n") %in% base::names(data_counts)),
    msg = "`data_counts` must be a data frame with columns metric, scope, n."
  )

  assertthat::assert_that(
    assertthat::is.string(metric),
    !base::is.na(metric),
    msg = "`metric` must be a single non-missing string."
  )

  assertthat::assert_that(
    assertthat::is.string(scope),
    !base::is.na(scope),
    msg = "`scope` must be a single non-missing string."
  )

  vec_n <-
    data_counts |>
    dplyr::filter(
      .data$metric == .env$metric,
      .data$scope == .env$scope
    ) |>
    dplyr::pull("n")

  if (
    base::length(vec_n) != 1L
  ) {
    cli::cli_abort(
      c(
        "There must be one count of metric {.val {metric}} and scope \\
        {.val {scope}}.",
        "x" = "Found {base::length(vec_n)}."
      )
    )
  }

  res <-
    base::as.numeric(vec_n)

  return(res)
}
