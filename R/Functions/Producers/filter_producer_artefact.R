#' @title Filter a producer artefact to the subset box
#' @description
#' Cut every table of a validated producer artefact to the regional box of
#' the `subset` profile, either by its coordinates or by the keys kept in
#' another artefact. Without an enabled subset the artefact is returned
#' unchanged.
#' @param list_artefact
#' Named list of data frames, as returned by `load_producer_artefact()`.
#' @param list_subset
#' Named list. The box of the `subset` section of `config.yml`: the logical
#' scalar `enabled` and, when enabled, `lon_min`, `lon_max`, `lat_min`,
#' `lat_max` and, for a filter with `flag_margin`, `margin_lon` and
#' `margin_lat`.
#' @param list_subset_filter
#' Named list. How the artefact is cut, its entry in
#' `producers: subset_filter` of `config.yml`: either `col_lon`, `col_lat`
#' and `flag_margin` (logical scalar: widen the box by the subset margins,
#' for gridded data around the box), or `col_key` and `reference` (the id of
#' the artefact whose kept rows decide), or `flag_keep_all` set to `TRUE`
#' (every row is kept: for tables without a place, such as rule
#' registries).
#' @param vec_keys_kept
#' Vector or `NULL` (default). The keys kept in the reference artefact named
#' in `list_subset_filter` (see `prepare_producer_keys()`); required for a
#' filter by `col_key` when the subset is enabled.
#' @return
#' `list_artefact` with only the rows inside the box, or with a key in
#' `vec_keys_kept`, in every table, or unchanged for `flag_keep_all`.
#' Names, columns and row order are kept.
#' @details
#' `list_subset_filter` is checked also when the subset is disabled, so a
#' broken setting is noticed in every build. Coordinates are filtered with
#' `filter_by_bounding_box()`, whose bounds are inclusive and which drops
#' rows without coordinates; a row without a key is dropped too. A table
#' may end up with no rows.
#' @examples
#' \dontrun{
#' filter_producer_artefact(
#'   list_artefact = list_splot,
#'   list_subset = load_config_value(value = "subset"),
#'   list_subset_filter = list(
#'     col_lon = "longitude",
#'     col_lat = "latitude",
#'     flag_margin = FALSE
#'   )
#' )
#' }
filter_producer_artefact <- function(
  list_artefact,
  list_subset,
  list_subset_filter,
  vec_keys_kept = NULL
) {
  assertthat::assert_that(
    base::is.list(list_artefact),
    !base::is.data.frame(list_artefact),
    !base::is.null(base::names(list_artefact)),
    base::all(purrr::map_lgl(.x = list_artefact, .f = base::is.data.frame)),
    msg = "`list_artefact` must be a named list of data frames."
  )

  flag_enabled <-
    purrr::pluck(list_subset, "enabled")

  assertthat::assert_that(
    base::is.list(list_subset),
    base::is.logical(flag_enabled),
    base::length(flag_enabled) == 1L,
    !base::is.na(flag_enabled),
    msg = "`list_subset` must have the logical scalar `enabled`."
  )

  vec_rule_fields <-
    base::sort(base::as.character(base::names(list_subset_filter)))

  # Every field of the rule must be one value; text except `flag_margin`
  vec_values_scalar <-
    purrr::map_lgl(
      .x = list_subset_filter,
      .f = ~ base::length(.x) == 1L && !base::is.na(.x)
    )

  flag_by_coordinates <-
    base::identical(
      vec_rule_fields,
      base::sort(c("col_lon", "col_lat", "flag_margin"))
    ) &&
    base::all(vec_values_scalar) &&
    base::is.character(purrr::chuck(list_subset_filter, "col_lon")) &&
    base::is.character(purrr::chuck(list_subset_filter, "col_lat")) &&
    base::is.logical(purrr::chuck(list_subset_filter, "flag_margin"))

  flag_by_key <-
    base::identical(vec_rule_fields, base::sort(c("col_key", "reference"))) &&
    base::all(vec_values_scalar) &&
    base::all(purrr::map_lgl(.x = list_subset_filter, .f = base::is.character))

  flag_keep_all <-
    base::identical(vec_rule_fields, "flag_keep_all") &&
    base::isTRUE(purrr::chuck(list_subset_filter, "flag_keep_all"))

  assertthat::assert_that(
    base::is.list(list_subset_filter),
    flag_by_coordinates || flag_by_key || flag_keep_all,
    msg = stringr::str_c(
      "`list_subset_filter` must have either `col_lon`, `col_lat` and ",
      "`flag_margin`, or `col_key` and `reference`, or `flag_keep_all` ",
      "set to TRUE."
    )
  )

  # The margins widen the box only for gridded data
  flag_margin <-
    flag_enabled &&
    base::isTRUE(purrr::pluck(list_subset_filter, "flag_margin"))

  flag_margins_valid <-
    purrr::map_lgl(
      .x = c("margin_lon", "margin_lat"),
      .f = ~ {
        value_margin <-
          purrr::pluck(list_subset, .x)

        base::is.numeric(value_margin) &&
          base::length(value_margin) == 1L &&
          base::is.finite(value_margin) &&
          value_margin >= 0
      }
    ) |>
    base::all()

  assertthat::assert_that(
    !flag_margin || flag_margins_valid,
    msg = stringr::str_c(
      "`list_subset` needs `margin_lon` and `margin_lat` (non-negative ",
      "numbers) to widen the box for gridded data."
    )
  )

  assertthat::assert_that(
    !flag_enabled ||
      !flag_by_key ||
      (base::is.atomic(vec_keys_kept) && !base::is.null(vec_keys_kept)),
    msg = stringr::str_c(
      "A filter by key needs the keys of the reference artefact in ",
      "`vec_keys_kept`."
    )
  )

  margin_lon <-
    if (
      flag_margin
    ) {
      purrr::chuck(list_subset, "margin_lon")
    } else {
      0
    }

  margin_lat <-
    if (
      flag_margin
    ) {
      purrr::chuck(list_subset, "margin_lat")
    } else {
      0
    }

  col_key <-
    purrr::pluck(list_subset_filter, "col_key")

  res <-
    if (
      !flag_enabled || flag_keep_all
    ) {
      list_artefact
    } else if (
      flag_by_coordinates
    ) {
      purrr::map(
        .x = list_artefact,
        .f = ~ filter_by_bounding_box(
          data_source = .x,
          list_bounding_box = list_subset,
          col_lon = purrr::chuck(list_subset_filter, "col_lon"),
          col_lat = purrr::chuck(list_subset_filter, "col_lat"),
          margin_lon = margin_lon,
          margin_lat = margin_lat
        )
      )
    } else {
      purrr::map(
        .x = list_artefact,
        .f = ~ dplyr::filter(
          .x,
          !base::is.na(.data[[col_key]]),
          .data[[col_key]] %in% vec_keys_kept
        )
      )
    }

  return(res)
}
