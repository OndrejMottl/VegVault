# Helper function to get valid gridpoints ids
#' @title Get valid gridpoints ids
#' @description Get valid gridpoints ids based on the distance from
#' the vegetation data
#' @param data_source A class of `tbl`
#' @param sel_dataset_type A character vector of dataset types to filter
#' @param sel_grid_size_degree A a helper grid size in degrees to
#' help to minime the caluclation proces
#' @param sel_distance_km A maximal distance in km from the vegetation data
#' @return A numeric vector of valid gridpoints ids
get_gridpoints_link <- function(
    data_source = NULL,
    data_source_gridpoints = NULL,
    sel_grid_size_degree = NULL,
    sel_distance_km = NULL,
    sel_distance_years = NULL) {
  assertthat::assert_that(
    inherits(data_source, "tbl"),
    msg = "data_source must be a class of `tbl`"
  )

  assertthat::assert_that(
    inherits(data_source_gridpoints, "tbl"),
    msg = "data_source must be a class of `tbl`"
  )

  assertthat::assert_that(
    is.numeric(sel_distance_km),
    msg = "sel_distance_km must be a numeric vector"
  )

  assertthat::assert_that(
    length(sel_distance_km) == 1,
    msg = "sel_distance_km must be a vector of length 1"
  )

  assertthat::assert_that(
    sel_distance_km > 0,
    msg = "sel_distance_km must be a a positive number"
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
    is.numeric(sel_distance_years),
    msg = "sel_distance_years must be a numeric vector"
  )

  assertthat::assert_that(
    length(sel_distance_years) == 1,
    msg = "sel_distance_years must be a vector of length 1"
  )

  assertthat::assert_that(
    sel_distance_years > 0,
    msg = "sel_distance_years must be a a positive number"
  )


  # Stage 1: Coarse filtering

  vec_gridpoits_coarse_filtering <-
    c("none", "NE", "SE", "SW", "NW") %>%
    purrr::map(
      .progress = "coarse filtering",
      .f = ~ get_valid_gridpoints_ids(
        data_source = data_source,
        data_source_gridpoints = data_source_gridpoints,
        sel_grid_size_degree = sel_grid_size_degree,
        offset = .x
      )
    ) %>%
    unlist() %>%
    unique()

  data_source_gridpoints_sub <-
    data_source_gridpoints %>%
    dplyr::filter(sample_name %in% vec_gridpoits_coarse_filtering)

  # Stage 2: Fine filtering

  data_vegetation_bounding_box <-
    data_source %>%
    dplyr::distinct(
      .data$dataset_id,
      .data$sample_name,
      .keep_all = TRUE
    ) %>%
    dplyr::mutate(
      coord_long_max = coord_long + sel_grid_size_degree / 2,
      coord_long_min = coord_long - sel_grid_size_degree / 2,
      coord_lat_max = coord_lat + sel_grid_size_degree / 2,
      coord_lat_min = coord_lat - sel_grid_size_degree / 2
    )

  data_vegetation_grid_data <-
    data_vegetation_bounding_box %>%
    # dplyr::sample_n(500) %>%
    dplyr::mutate(
      data_gridpoints_sub = purrr::pmap(
        .progress = "fine filtering",
        .l = list(
          coord_long_max,
          coord_long_min,
          coord_lat_max,
          coord_lat_min,
          age
        ),
        .f = ~ data_source_gridpoints_sub %>%
          vctrs::vec_slice(
            data_source_gridpoints_sub$coord_long <= ..1 &
              data_source_gridpoints_sub$coord_long >= ..2 &
              data_source_gridpoints_sub$coord_lat <= ..3 &
              data_source_gridpoints_sub$coord_lat >= ..4 & 
              abs(data_source_gridpoints_sub$age - ..5) <= sel_distance_years
          ) %>%
          dplyr::rename(
            dataset_id_gridpoints = dataset_id,
            sample_name_gridpoints = sample_name,
            coord_long_gridpoints = coord_long,
            coord_lat_gridpoints = coord_lat,
            age_gridpoints = age
          )
      )
    )

  data_vegetation_grid_unnest <-
    data_vegetation_grid_data %>%
    dplyr::select(
      dataset_id, sample_name,
      coord_long, coord_lat, age,
      data_gridpoints_sub
    ) %>%
    tidyr::unnest(data_gridpoints_sub)


  # Stage 3: Distance calculation
  data_vegetation_distance <-
    data_vegetation_grid_unnest %>%
    dplyr::mutate(
      distance_in_m = purrr::pmap_dbl(
        .progress = "estimating distance",
        .l = list(
          .data$coord_long,
          .data$coord_lat,
          .data$coord_long_gridpoints,
          .data$coord_lat_gridpoints
        ),
        .f = ~ geosphere::distGeo(
          c(..1, ..2),
          c(..3, ..4)
        )
      ),
      distance_in_km = distance_in_m / 1e3,
      distance_in_years = abs(age - age_gridpoints)
    )

  # Stage 4: Filtering
  data_vegetation_distance_filter <-
    data_vegetation_distance %>%
    dplyr::filter(
      distance_in_km <= sel_distance_km,
      distance_in_years <= sel_distance_years
    ) %>%
    dplyr::select(
      dataset_id,
      sample_name,
      dataset_id_gridpoints,
      sample_name_gridpoints,
      distance_in_km,
      distance_in_years
    )

  return(data_vegetation_distance_filter)
}
