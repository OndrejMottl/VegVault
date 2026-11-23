#' @title Diagnose the differences of a comparison with v1.0.0
#' @description
#' Mark each scope of a comparison summary as equal, explained by an
#' expected difference, or unexplained, so that the comparison passes only
#' when every difference has a documented reason.
#' @param data_summary
#' A data frame as returned by `compute_comparison_summary()`, with at
#' least `unit`, `scope`, `n_only_v1` and `n_only_v2`; several units may be
#' bound together.
#' @param list_expected
#' A list of expected differences, each a list with `units` (character),
#' `directions` (character: `"only_v1"`, `"only_v2"` or both), `reason`
#' (a text scalar) and optionally `scopes` (character; when it is missing,
#' the record covers every scope of its units).
#' @return
#' `data_summary` with two more columns: `status` (`"equal"`,
#' `"explained"` or `"unexplained"`) and `reason` (the reasons of the
#' records that cover the scope, joined with `"; "`, or `NA`).
#' @details
#' A scope with no row on one side only is `"equal"`. Otherwise it is
#' `"explained"` when each direction with rows (`n_only_v1 > 0`,
#' `n_only_v2 > 0`) is allowed by a record that covers the unit and scope,
#' and `"unexplained"` when one is not, so that, for example, a record
#' that allows rows only in 2.0.0 never explains a v1.0.0 row that 2.0.0
#' lost. Aborts when a record lacks a field or names an unknown direction.
#' @seealso [compute_comparison_summary()]
#' @examples
#' \dontrun{
#' diagnose_comparison_summary(
#'   data_summary = data_summary,
#'   list_expected = base::list(
#'     base::list(
#'       units = "sample_links",
#'       directions = "only_v2",
#'       reason = "Links that v1.0.0 missed above 63.3 degrees."
#'     )
#'   )
#' )
#' }
diagnose_comparison_summary <- function(
  data_summary,
  list_expected
) {
  assertthat::assert_that(
    base::is.data.frame(data_summary),
    base::all(
      c("unit", "scope", "n_only_v1", "n_only_v2") %in%
        base::names(data_summary)
    ),
    msg = stringr::str_c(
      "`data_summary` must be a data frame with `unit`, `scope`, ",
      "`n_only_v1` and `n_only_v2`."
    )
  )

  assertthat::assert_that(
    base::is.list(list_expected),
    msg = "`list_expected` must be a list of expected differences."
  )

  vec_directions <-
    c("only_v1", "only_v2")

  purrr::iwalk(
    .x = list_expected,
    .f = ~ {
      if (
        !base::is.list(.x) ||
          !base::is.character(purrr::pluck(.x, "units")) ||
          base::length(purrr::pluck(.x, "units")) == 0L ||
          !rlang::is_string(purrr::pluck(.x, "reason"))
      ) {
        cli::cli_abort(
          "Expected difference {.y} needs {.field units} and a
          {.field reason}."
        )
      }

      vec_record_directions <-
        purrr::pluck(.x, "directions")

      if (
        !base::is.character(vec_record_directions) ||
          base::length(vec_record_directions) == 0L ||
          !base::all(vec_record_directions %in% vec_directions)
      ) {
        cli::cli_abort(
          "The {.field directions} of expected difference {.y} must be
          {.val only_v1}, {.val only_v2} or both."
        )
      }
    }
  )

  # One row per unit, scope (NA for every scope) and direction of a record
  data_rules <-
    list_expected |>
    purrr::imap(
      .f = ~ tidyr::expand_grid(
        unit = purrr::chuck(.x, "units"),
        rule_scope = purrr::pluck(.x, "scopes", .default = NA_character_),
        direction = purrr::chuck(.x, "directions")
      ) |>
        dplyr::mutate(
          id_record = .y,
          reason = purrr::chuck(.x, "reason")
        )
    ) |>
    purrr::list_rbind(
      ptype = tibble::tibble(
        unit = base::character(0),
        rule_scope = base::character(0),
        direction = base::character(0),
        id_record = base::integer(0),
        reason = base::character(0)
      )
    )

  data_rows <-
    data_summary |>
    dplyr::select(unit, scope) |>
    dplyr::mutate(id_row = dplyr::row_number())

  data_matches <-
    data_rows |>
    dplyr::inner_join(
      data_rules,
      by = dplyr::join_by(unit),
      relationship = "many-to-many"
    ) |>
    dplyr::filter(base::is.na(rule_scope) | rule_scope == scope) |>
    dplyr::arrange(id_row, id_record) |>
    dplyr::summarise(
      reason = stringr::str_c(base::unique(reason), collapse = "; "),
      is_allowed_v1 = base::any(direction == "only_v1"),
      is_allowed_v2 = base::any(direction == "only_v2"),
      .by = id_row
    )

  data_status <-
    data_rows |>
    dplyr::left_join(data_matches, by = dplyr::join_by(id_row)) |>
    dplyr::mutate(
      n_only_v1 = dplyr::pull(data_summary, n_only_v1),
      n_only_v2 = dplyr::pull(data_summary, n_only_v2),
      is_allowed_v1 = dplyr::coalesce(is_allowed_v1, FALSE),
      is_allowed_v2 = dplyr::coalesce(is_allowed_v2, FALSE),
      status = dplyr::case_when(
        n_only_v1 == 0 & n_only_v2 == 0 ~ "equal",
        (n_only_v1 == 0 | is_allowed_v1) &
          (n_only_v2 == 0 | is_allowed_v2) ~ "explained",
        .default = "unexplained"
      )
    )

  res <-
    data_summary |>
    dplyr::mutate(
      status = dplyr::pull(data_status, status),
      reason = dplyr::pull(data_status, reason)
    )

  return(res)
}
