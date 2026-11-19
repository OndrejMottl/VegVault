#' @title Validate a geographic bounding box
#' @description
#' Check that a list describes a longitude-latitude bounding box in WGS84
#' degrees that does not cross the dateline.
#' @param list_bounding_box
#' A named list with the numeric scalars `lon_min`, `lon_max`, `lat_min`
#' and `lat_max`. Other elements, such as the box name of the `subset`
#' configuration section, are ignored.
#' @return
#' `list_bounding_box`, unchanged and invisibly.
#' @details
#' Aborts when an element is missing, not a finite numeric scalar, outside
#' -180 to 180 (longitude) or -90 to 90 (latitude), or when a minimum is
#' not smaller than its maximum. A box with `lon_min > lon_max` would cross
#' the dateline, which is not supported.
#' @examples
#' \dontrun{
#' validate_bounding_box(
#'   list_bounding_box = load_config_value(value = "subset")
#' )
#' }
validate_bounding_box <- function(list_bounding_box) {
  assertthat::assert_that(
    base::is.list(list_bounding_box),
    msg = "`list_bounding_box` must be a named list."
  )

  vec_bounds <-
    c("lon_min", "lon_max", "lat_min", "lat_max")

  vec_bounds_missing <-
    vec_bounds[!vec_bounds %in% base::names(list_bounding_box)]

  if (
    base::length(vec_bounds_missing) > 0L
  ) {
    cli::cli_abort(
      "The bounding box has no {.field {vec_bounds_missing}}."
    )
  }

  vec_bounds_invalid <-
    vec_bounds |>
    purrr::discard(
      .p = ~ {
        value_bound <-
          purrr::chuck(list_bounding_box, .x)

        base::is.numeric(value_bound) &&
          base::length(value_bound) == 1L &&
          base::is.finite(value_bound)
      }
    )

  if (
    base::length(vec_bounds_invalid) > 0L
  ) {
    cli::cli_abort(
      "{.field {vec_bounds_invalid}} of the bounding box must be finite
      numbers."
    )
  }

  lon_min <-
    purrr::chuck(list_bounding_box, "lon_min")

  lon_max <-
    purrr::chuck(list_bounding_box, "lon_max")

  lat_min <-
    purrr::chuck(list_bounding_box, "lat_min")

  lat_max <-
    purrr::chuck(list_bounding_box, "lat_max")

  if (
    base::any(base::abs(c(lon_min, lon_max)) > 180)
  ) {
    cli::cli_abort(
      "The longitudes of the bounding box must lie between -180 and 180."
    )
  }

  if (
    base::any(base::abs(c(lat_min, lat_max)) > 90)
  ) {
    cli::cli_abort(
      "The latitudes of the bounding box must lie between -90 and 90."
    )
  }

  if (
    lon_min >= lon_max
  ) {
    cli::cli_abort(
      c(
        "{.field lon_min} must be smaller than {.field lon_max}.",
        "i" = "Boxes that cross the dateline are not supported."
      )
    )
  }

  if (
    lat_min >= lat_max
  ) {
    cli::cli_abort(
      "{.field lat_min} must be smaller than {.field lat_max}."
    )
  }

  res <- list_bounding_box

  return(invisible(res))
}
