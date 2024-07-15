# Helper function to add bin coordinates
#' @title Add bin coordinates
#' @description Add bin coordinates to the data
#' @param data_source A class of `tbl`
#' @param sel_grid_size_degree A grid size in degrees
#' @param long_offset A grid offset to shift the gridpoints
#' @param lat_offset A grid offset to shift the gridpoints
#' @return A class of `tbl`
#' @keywords internal
bin_coord_data <- function(data_source = NULL,
                           sel_grid_size_degree = NULL,
                           long_offset = 0,
                           lat_offset = 0) {
  assertthat::assert_that(
    inherits(data_source, "tbl"),
    msg = "data_source must be a class of `tbl`"
  )

  assertthat::assert_that(
    is.numeric(sel_grid_size_degree),
    msg = "sel_grid_size_degree must be a numeric vector"
  )

  assertthat::assert_that(
    length(sel_grid_size_degree) == 1,
    msg = "sel_grid_size_degree must be a vector of length 1"
  )

  assertthat::assert_that(
    sel_grid_size_degree > 0,
    msg = "sel_grid_size_degree must be a a positive number"
  )

  assertthat::assert_that(
    length(long_offset) == 1,
    msg = "long_offset must be a vector of length 1"
  )

  assertthat::assert_that(
    length(lat_offset) == 1,
    msg = "lat_offset must be a vector of length 1"
  )

  data_source %>%
    dplyr::mutate(
      coord_long_bin = floor(
        (.data$coord_long + long_offset) / sel_grid_size_degree
      ) * sel_grid_size_degree,
      coord_lat_bin = floor(
        (.data$coord_lat + lat_offset) / sel_grid_size_degree
      ) * sel_grid_size_degree
    ) %>%
    return()
}