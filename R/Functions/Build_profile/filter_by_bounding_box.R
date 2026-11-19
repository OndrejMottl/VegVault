#' @title Filter records by a geographic bounding box
#' @description
#' Keep the rows of a table whose coordinates fall inside a
#' longitude-latitude bounding box, optionally widened by a margin. Used
#' to cut validated producer artefacts down to the regional `subset` box,
#' so that old and new builds can be compared on the same records.
#' @param data_source
#' A data frame with a longitude and a latitude column in WGS84 degrees.
#' @param list_bounding_box
#' A named list with `lon_min`, `lon_max`, `lat_min` and `lat_max`, such
#' as the `subset` section of `config.yml` (checked with
#' `validate_bounding_box()`).
#' @param col_lon
#' Character scalar. Name of the longitude column.
#' @param col_lat
#' Character scalar. Name of the latitude column.
#' @param margin_lon
#' Non-negative numeric scalar. Degrees added on both sides of the
#' longitude range. Default 0.
#' @param margin_lat
#' Non-negative numeric scalar. Degrees added on both sides of the
#' latitude range. Default 0.
#' @return
#' `data_source` with only the rows inside the (widened) box; columns and
#' row order are kept.
#' @details
#' The bounds are inclusive, so records on the edge of the box are kept,
#' as with SQL `BETWEEN`. Rows with a missing longitude or latitude are
#' not inside any box and are dropped. The widened box is not clipped to
#' -180 to 180 or -90 to 90 and does not wrap around the dateline.
#' @examples
#' \dontrun{
#' data_plots_subset <-
#'   filter_by_bounding_box(
#'     data_source = data_plots,
#'     list_bounding_box = load_config_value(value = "subset"),
#'     col_lon = "longitude",
#'     col_lat = "latitude"
#'   )
#' }
filter_by_bounding_box <- function(
  data_source,
  list_bounding_box,
  col_lon,
  col_lat,
  margin_lon = 0,
  margin_lat = 0
) {
  assertthat::assert_that(
    base::is.data.frame(data_source),
    msg = "`data_source` must be a data frame."
  )

  assertthat::assert_that(
    base::is.character(col_lon),
    base::length(col_lon) == 1L,
    base::is.character(col_lat),
    base::length(col_lat) == 1L,
    msg = "`col_lon` and `col_lat` must be character scalars."
  )

  vec_columns_missing <-
    base::setdiff(c(col_lon, col_lat), base::names(data_source))

  assertthat::assert_that(
    base::length(vec_columns_missing) == 0L,
    msg = stringr::str_c(
      "`data_source` has no column ",
      stringr::str_c(vec_columns_missing, collapse = ", "),
      "."
    )
  )

  assertthat::assert_that(
    base::is.numeric(dplyr::pull(data_source, {{ col_lon }})),
    base::is.numeric(dplyr::pull(data_source, {{ col_lat }})),
    msg = "The coordinate columns must be numeric."
  )

  assertthat::assert_that(
    base::is.numeric(margin_lon),
    base::length(margin_lon) == 1L,
    base::isTRUE(margin_lon >= 0),
    base::is.numeric(margin_lat),
    base::length(margin_lat) == 1L,
    base::isTRUE(margin_lat >= 0),
    msg = "`margin_lon` and `margin_lat` must be non-negative numbers."
  )

  validate_bounding_box(list_bounding_box = list_bounding_box)

  lon_lower <-
    purrr::chuck(list_bounding_box, "lon_min") - margin_lon

  lon_upper <-
    purrr::chuck(list_bounding_box, "lon_max") + margin_lon

  lat_lower <-
    purrr::chuck(list_bounding_box, "lat_min") - margin_lat

  lat_upper <-
    purrr::chuck(list_bounding_box, "lat_max") + margin_lat

  # dplyr::filter() drops rows whose condition is NA, i.e. rows with a
  #   missing coordinate
  res <-
    data_source |>
    dplyr::filter(
      .data[[col_lon]] >= lon_lower,
      .data[[col_lon]] <= lon_upper,
      .data[[col_lat]] >= lat_lower,
      .data[[col_lat]] <= lat_upper
    )

  return(res)
}
