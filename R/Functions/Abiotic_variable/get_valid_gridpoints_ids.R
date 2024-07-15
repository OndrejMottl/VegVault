get_valid_gridpoints_ids <- function(
    data_source = NULL,
    data_source_gridpoints = NULL,
    sel_grid_size_degree = NULL,
    offset = c("none", "NE", "SE", "SW", "NW")) {
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

  offset <- match.arg(offset)
  long_offset <- NULL
  lat_offset <- NULL

  switch(offset,
    "none" = {
      long_offset <- 0
      lat_offset <- 0
    },
    "NE" = {
      long_offset <- sel_grid_size_degree / 2
      lat_offset <- sel_grid_size_degree / 2
    },
    "SE" = {
      long_offset <- sel_grid_size_degree / 2
      lat_offset <- -(sel_grid_size_degree / 2)
    },
    "SW" = {
      long_offset <- -(sel_grid_size_degree / 2)
      lat_offset <- -(sel_grid_size_degree / 2)
    },
    "NW" = {
      long_offset <- -(sel_grid_size_degree / 2)
      lat_offset <- sel_grid_size_degree / 2
    }
  )


  data_source_coord <-
    data_source %>%
    bin_coord_data(sel_grid_size_degree = sel_grid_size_degree)


  data_source_gridpoints_coord <-
    data_source_gridpoints %>%
    bin_coord_data(
      sel_grid_size_degree = sel_grid_size_degree,
      long_offset = long_offset,
      lat_offset = lat_offset
    )

  vec_gridpoits_coarse_filtering <-
    dplyr::inner_join(
      data_source_coord,
      data_source_gridpoints_coord,
      by = c(
        "coord_long_bin",
        "coord_lat_bin"
      ),
      relationship = "many-to-many",
      suffix = c("_vegetation", "_gridpoints")
    ) %>%
    dplyr::distinct(
      .data$sample_name_gridpoints
    ) %>%
    .[["sample_name_gridpoints"]]

  return(vec_gridpoits_coarse_filtering)
}
