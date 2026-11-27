#' @title Compute the changes of the counts against v1.0.0
#' @description
#' Join the counts of a build with the reference counts of v1.0.0, compute
#' each change, and mark the changes beyond the tolerance, with the reason
#' of the changes that decisions of the release expect.
#' @param data_counts
#' A tibble of counts, as returned by `compute_database_counts()`.
#' @param data_reference
#' A tibble of reference counts, as returned by
#' `build_v1_reference_counts()` or read from its committed file.
#' @param list_comparison
#' Named list, the section `validation: v1_comparison` of `config.yml`:
#' `tolerance` (number, at least 0: the largest relative change that
#' passes), and optionally `metric_map` (entries with `v1_metric`,
#' `v1_scope`, `metric`, `scope` and `note`: a v1.0.0 count compared with
#' a differently counted 2.0.0 count) and `expected_changes` (entries with
#' `metrics`, `scopes` and `reason`).
#' @return
#' A tibble with one row per metric and scope of either version, in the
#' order of the reference and then the counts: `metric`, `scope`, `n_v1`,
#' `n_v2`, `delta` (`n_v2 - n_v1`), `relative_change` (`delta / n_v1`),
#' `status` (`pass` or `flag`), `expected_reason` and `note` (from
#' `metric_map`), the last two missing where none applies.
#' @details
#' A count passes when it exists in both versions and its relative change
#' is at most `tolerance` in either direction; a change of a count of 0 in
#' v1.0.0 is infinite unless the build also has 0. Every other count is
#' flagged for review, never failed: a flag asks for a judgement, and an
#' expected reason explains it without hiding it (VegVault issue 96).
#' Aborts when `tolerance` is not a number of at least 0 or a map entry is
#' incomplete.
#' @seealso [diagnose_v1_counts()], [save_v1_count_deltas()]
#' @examples
#' \dontrun{
#' compute_v1_count_deltas(
#'   data_counts = data_counts,
#'   data_reference = data_reference,
#'   list_comparison = load_config_value(
#'     value = c("validation", "v1_comparison")
#'   )
#' )
#' }
compute_v1_count_deltas <- function(
  data_counts,
  data_reference,
  list_comparison
) {
  assertthat::assert_that(
    base::is.data.frame(data_counts),
    base::all(c("metric", "scope", "n_v2") %in% base::names(data_counts)),
    base::is.data.frame(data_reference),
    base::all(c("metric", "scope", "n_v1") %in% base::names(data_reference)),
    msg = stringr::str_c(
      "'data_counts' needs the columns metric, scope and n_v2, and ",
      "'data_reference' the columns metric, scope and n_v1."
    )
  )

  tolerance <-
    purrr::pluck(list_comparison, "tolerance")

  assertthat::assert_that(
    base::is.numeric(tolerance),
    base::length(tolerance) == 1L,
    base::isTRUE(tolerance >= 0),
    base::is.finite(tolerance),
    msg = "The 'tolerance' of the comparison must be a number of at least 0."
  )

  list_map <-
    purrr::pluck(list_comparison, "metric_map", .default = base::list())

  list_expected <-
    purrr::pluck(list_comparison, "expected_changes", .default = base::list())

  vec_map_fields <-
    c("v1_metric", "v1_scope", "metric", "scope", "note")

  vec_expected_fields <-
    c("metrics", "scopes", "reason")

  if (
    !base::all(
      purrr::map_lgl(
        .x = list_map,
        .f = ~ base::all(vec_map_fields %in% base::names(.x))
      )
    )
  ) {
    cli::cli_abort(
      "Each entry of {.field metric_map} needs {.field {vec_map_fields}}."
    )
  }

  if (
    !base::all(
      purrr::map_lgl(
        .x = list_expected,
        .f = ~ base::all(vec_expected_fields %in% base::names(.x))
      )
    )
  ) {
    cli::cli_abort(
      "Each entry of {.field expected_changes} needs
      {.field {vec_expected_fields}}."
    )
  }

  data_map <-
    dplyr::bind_rows(
      tibble::tibble(
        metric = base::character(0),
        scope = base::character(0),
        metric_v2 = base::character(0),
        scope_v2 = base::character(0),
        note = base::character(0)
      ),
      purrr::map(
        .x = list_map,
        .f = ~ tibble::tibble(
          metric = purrr::chuck(.x, "v1_metric"),
          scope = purrr::chuck(.x, "v1_scope"),
          metric_v2 = purrr::chuck(.x, "metric"),
          scope_v2 = purrr::chuck(.x, "scope"),
          note = purrr::chuck(.x, "note")
        )
      )
    )

  data_expected <-
    dplyr::bind_rows(
      tibble::tibble(
        metric = base::character(0),
        scope = base::character(0),
        expected_reason = base::character(0)
      ),
      purrr::map(
        .x = list_expected,
        .f = ~ tidyr::expand_grid(
          metric = base::unlist(purrr::chuck(.x, "metrics")),
          scope = base::unlist(purrr::chuck(.x, "scopes")),
          expected_reason = purrr::chuck(.x, "reason")
        )
      )
    ) |>
    dplyr::distinct(metric, scope, .keep_all = TRUE)

  # A v1.0.0 count that 2.0.0 counts differently takes its 2.0.0 name
  data_reference_mapped <-
    data_reference |>
    dplyr::select(metric, scope, n_v1) |>
    dplyr::left_join(data_map, by = dplyr::join_by(metric, scope)) |>
    dplyr::mutate(
      metric = dplyr::coalesce(metric_v2, metric),
      scope = dplyr::coalesce(scope_v2, scope),
      order_v1 = dplyr::row_number()
    ) |>
    dplyr::select(metric, scope, n_v1, note, order_v1)

  res <-
    data_reference_mapped |>
    dplyr::full_join(
      data_counts |>
        dplyr::select(metric, scope, n_v2) |>
        dplyr::mutate(order_v2 = dplyr::row_number()),
      by = dplyr::join_by(metric, scope)
    ) |>
    dplyr::arrange(base::is.na(order_v1), order_v1, order_v2) |>
    dplyr::left_join(data_expected, by = dplyr::join_by(metric, scope)) |>
    dplyr::mutate(
      n_v1 = base::as.numeric(n_v1),
      n_v2 = base::as.numeric(n_v2),
      delta = n_v2 - n_v1,
      relative_change = dplyr::case_when(
        base::is.na(delta) ~ NA_real_,
        n_v1 == 0 & n_v2 == 0 ~ 0,
        n_v1 == 0 ~ base::sign(delta) * Inf,
        .default = delta / n_v1
      ),
      status = dplyr::if_else(
        !base::is.na(relative_change) &
          base::abs(relative_change) <= tolerance,
        "pass",
        "flag"
      )
    ) |>
    dplyr::select(
      metric, scope, n_v1, n_v2, delta, relative_change, status,
      expected_reason, note
    )

  return(res)
}
