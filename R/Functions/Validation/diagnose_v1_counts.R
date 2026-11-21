#' @title Diagnose the changes of the counts against v1.0.0
#' @description
#' Summarise the changes of the counts of a build against v1.0.0 into the
#' rows of the validation report: one per metric.
#' @param data_deltas
#' A tibble of changes, as returned by `compute_v1_count_deltas()`.
#' @param list_build_manifest
#' Named list. The build manifest of the database; `subset: enabled`
#' tells whether the build covers only part of the data.
#' @param tolerance
#' Number, at least 0. The tolerance the changes were judged with, for the
#' messages.
#' @return
#' A tibble in the format of `build_check_result()`, check `v1_counts`,
#' with one row per metric in the order of `data_deltas`. A metric passes
#' when every count passes, and is a `flag` otherwise, with the number of
#' flagged counts as the observed value, the tolerance as the threshold,
#' and the first flagged counts in the message, each with its expected
#' reason. A subset build gives one `pass` row, scope `all`, saying that
#' nothing was compared, because a subset covers only part of v1.0.0.
#' @details
#' The full table of changes is saved by `save_v1_count_deltas()`; this
#' function only summarises it. Never fails a check.
#' @seealso [compute_v1_count_deltas()], [save_v1_count_deltas()]
#' @examples
#' \dontrun{
#' diagnose_v1_counts(
#'   data_deltas = data_v1_deltas,
#'   list_build_manifest = list_build_manifest,
#'   tolerance = 0.05
#' )
#' }
diagnose_v1_counts <- function(
  data_deltas,
  list_build_manifest,
  tolerance
) {
  vec_columns <-
    c(
      "metric", "scope", "n_v1", "n_v2", "delta", "relative_change",
      "status", "expected_reason"
    )

  assertthat::assert_that(
    base::is.data.frame(data_deltas),
    base::all(vec_columns %in% base::names(data_deltas)),
    msg = "'data_deltas' must be a table of compute_v1_count_deltas()."
  )

  assertthat::assert_that(
    base::is.numeric(tolerance),
    base::length(tolerance) == 1L,
    base::isTRUE(tolerance >= 0),
    msg = "'tolerance' must be a number of at least 0."
  )

  if (
    base::isTRUE(purrr::pluck(list_build_manifest, "subset", "enabled"))
  ) {
    res <-
      build_check_result(
        check_id = "v1_counts",
        scope = "all",
        status = "pass",
        message = stringr::str_c(
          "Not compared: a subset build covers only part of v1.0.0."
        )
      )

    return(res)
  }

  text_tolerance <-
    stringr::str_c(base::sprintf("%g", tolerance * 100), "%")

  # One text per count: both values and the change, or the one version
  #   that has it, and the reason when the change is expected
  data_texts <-
    data_deltas |>
    dplyr::mutate(
      text_v1 = base::sprintf("%.15g", n_v1),
      text_v2 = base::sprintf("%.15g", n_v2),
      text_change = dplyr::case_when(
        base::is.na(n_v1) ~ stringr::str_c(
          scope, ": new in 2.0.0, ", text_v2
        ),
        base::is.na(n_v2) ~ stringr::str_c(
          scope, ": not in 2.0.0, ", text_v1, " in v1.0.0"
        ),
        n_v1 == 0 ~ stringr::str_c(scope, ": 0 to ", text_v2),
        .default = stringr::str_c(
          scope, ": ", text_v1, " to ", text_v2, " (",
          base::sprintf("%+g", base::round(relative_change * 100, 1)), "%)"
        )
      ),
      text_count = dplyr::if_else(
        base::is.na(expected_reason),
        text_change,
        stringr::str_c(text_change, "; expected: ", expected_reason)
      )
    )

  vec_metrics <-
    base::unique(dplyr::pull(data_deltas, metric))

  data_summary <-
    data_texts |>
    dplyr::group_by(metric) |>
    dplyr::summarise(
      n_counts = dplyr::n(),
      n_flagged = base::sum(status == "flag"),
      text_flagged = stringr::str_c(
        utils::head(text_count[status == "flag"], 5L),
        collapse = " | "
      ),
      .groups = "drop"
    ) |>
    dplyr::arrange(base::match(metric, vec_metrics)) |>
    dplyr::mutate(
      message = dplyr::if_else(
        n_flagged == 0L,
        stringr::str_c(
          "All counts within ", text_tolerance, " of v1.0.0 (",
          n_counts, " of ", n_counts, ")."
        ),
        stringr::str_c(
          "Changed by more than ", text_tolerance,
          " or in one version only: ", n_flagged, " of ", n_counts,
          " counts. ", text_flagged,
          dplyr::if_else(
            n_flagged > 5L,
            stringr::str_c(" | and ", n_flagged - 5L, " more"),
            ""
          )
        )
      )
    )

  res <-
    build_check_result(
      check_id = "v1_counts",
      scope = dplyr::pull(data_summary, metric),
      status = dplyr::if_else(
        dplyr::pull(data_summary, n_flagged) == 0L,
        "pass",
        "flag"
      ),
      observed = dplyr::pull(data_summary, n_flagged),
      threshold = base::sprintf("%g", tolerance),
      message = dplyr::pull(data_summary, message)
    )

  return(res)
}
