#' @title Compute the summary of a comparison of two sets of rows
#' @description
#' Compare the rows of one kind from v1.0.0 and from a 2.0.0 build (see
#' `load_comparison_rows()`) scope by scope: how many rows each side has,
#' how many both have, how many only one has, and a checksum of each side.
#' @param data_v1
#' A data frame with the column `scope` and the key columns: the rows of
#' v1.0.0.
#' @param data_v2
#' A data frame with the same columns, in any order: the rows of the 2.0.0
#' build.
#' @param sel_unit
#' Character scalar. The kind of rows, written into the column `unit`.
#' @return
#' A tibble with one row per scope of either side, sorted by scope in the
#' C locale, and the columns `unit`, `scope`, `n_v1`, `n_v2`, `n_both`,
#' `n_only_v1`, `n_only_v2` (doubles), `checksum_v1` and `checksum_v2`
#' (`NA` for a side without rows in the scope) and `is_equal`.
#' @details
#' The rows are compared as multisets: a row that v1.0.0 holds twice and
#' 2.0.0 once counts once in `n_both` and once in `n_only_v1`. A checksum
#' is the hash of the rows of the scope sorted in the C locale, so it does
#' not depend on the order of the rows. `is_equal` is `TRUE` when no row is
#' only on one side. Aborts when the two sides do not have the same
#' columns.
#' @seealso [load_comparison_rows()], [diagnose_comparison_summary()]
#' @examples
#' \dontrun{
#' compute_comparison_summary(
#'   data_v1 = data_v1_samples,
#'   data_v2 = data_v2_samples,
#'   sel_unit = "samples"
#' )
#' }
compute_comparison_summary <- function(
  data_v1,
  data_v2,
  sel_unit
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

  assertthat::assert_that(
    rlang::is_string(sel_unit),
    !base::is.na(sel_unit),
    msg = "`sel_unit` must be a text scalar."
  )

  # Checks that both sides have the same columns
  data_differences <-
    compute_comparison_differences(data_v1 = data_v1, data_v2 = data_v2)

  data_v2_ordered <-
    dplyr::select(data_v2, dplyr::all_of(base::names(data_v1)))

  data_only <-
    data_differences |>
    dplyr::summarise(
      n_only_v1 = base::sum(base::pmax(n_v1 - n_v2, 0)),
      n_only_v2 = base::sum(base::pmax(n_v2 - n_v1, 0)),
      .by = scope
    )

  # The checksum of each side, on its rows sorted in the C locale
  list_sides <-
    base::list(v1 = data_v1, v2 = data_v2_ordered)

  data_sides <-
    list_sides |>
    purrr::imap(
      .f = ~ .x |>
        dplyr::arrange(dplyr::across(dplyr::everything()), .locale = "C") |>
        tidyr::nest(.by = scope, .key = "data_rows") |>
        dplyr::mutate(
          side = .y,
          n = base::as.double(purrr::map_int(.x = data_rows, .f = base::nrow)),
          checksum = purrr::map_chr(.x = data_rows, .f = rlang::hash)
        ) |>
        dplyr::select(scope, side, n, checksum)
    ) |>
    purrr::list_rbind(
      ptype = tibble::tibble(
        scope = base::character(0),
        side = base::character(0),
        n = base::double(0),
        checksum = base::character(0)
      )
    ) |>
    tidyr::pivot_wider(
      names_from = side,
      values_from = c(n, checksum)
    )

  # Both sides as columns, even when one has no rows at all
  data_template <-
    tibble::tibble(
      scope = base::character(0),
      n_v1 = base::double(0),
      n_v2 = base::double(0),
      checksum_v1 = base::character(0),
      checksum_v2 = base::character(0)
    )

  res <-
    dplyr::bind_rows(data_template, data_sides) |>
    dplyr::left_join(data_only, by = dplyr::join_by(scope)) |>
    dplyr::mutate(
      unit = sel_unit,
      n_v1 = dplyr::coalesce(n_v1, 0),
      n_v2 = dplyr::coalesce(n_v2, 0),
      n_only_v1 = dplyr::coalesce(n_only_v1, 0),
      n_only_v2 = dplyr::coalesce(n_only_v2, 0),
      n_both = n_v1 - n_only_v1,
      is_equal = n_only_v1 == 0 & n_only_v2 == 0
    ) |>
    dplyr::select(
      unit, scope, n_v1, n_v2, n_both, n_only_v1, n_only_v2,
      checksum_v1, checksum_v2, is_equal
    ) |>
    dplyr::arrange(scope, .locale = "C")

  return(res)
}
