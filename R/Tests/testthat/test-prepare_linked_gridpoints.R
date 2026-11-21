#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_linked_gridpoints() validates arguments", {
  data_links <-
    tibble::tibble(position_id = 1L, gridpoint_id = 1L)

  data_cells <-
    tibble::tibble(cell_index = 1L, coord_long = 0, coord_lat = 0)

  list_bad_links <-
    list(
      "a",
      tibble::tibble(position_id = 1L),
      tibble::tibble(gridpoint_id = 1)
    )

  purrr::walk(
    .x = list_bad_links,
    .f = ~ testthat::expect_error(
      prepare_linked_gridpoints(
        data_position_links = .x,
        data_cells = data_cells,
        vec_ages = 0
      ),
      regexp = "data_position_links"
    )
  )

  testthat::expect_error(
    prepare_linked_gridpoints(
      data_position_links = data_links,
      data_cells = dplyr::mutate(data_cells, cell_index = 2L),
      vec_ages = 0
    ),
    regexp = "data_cells"
  )

  testthat::expect_error(
    prepare_linked_gridpoints(
      data_position_links = data_links,
      data_cells = data_cells,
      vec_ages = c(10, 0)
    ),
    regexp = "vec_ages"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_linked_gridpoints() returns named gridpoints", {
  res <-
    prepare_linked_gridpoints(
      data_position_links = tibble::tibble(
        position_id = 1L,
        gridpoint_id = 1L,
        distance_in_km = 3L,
        distance_in_years = 0L
      ),
      data_cells = tibble::tibble(
        cell_index = 1L,
        coord_long = 14.25,
        coord_lat = 50.1
      ),
      vec_ages = 0
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(
    res,
    c(
      "gridpoint_id", "coord_long", "coord_lat", "age", "dataset_name",
      "sample_name"
    )
  )
  testthat::expect_type(dplyr::pull(res, gridpoint_id), "integer")
  testthat::expect_type(dplyr::pull(res, coord_long), "double")
  testthat::expect_type(dplyr::pull(res, age), "double")
  testthat::expect_type(dplyr::pull(res, dataset_name), "character")
  testthat::expect_type(dplyr::pull(res, sample_name), "character")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_linked_gridpoints() decodes ids and names", {
  data_cells <-
    tibble::tibble(
      cell_index = c(1L, 2L, 3L),
      coord_long = c(-20.5, 0, 14.1),
      coord_lat = c(10, 89.99, -0.05)
    )

  res <-
    prepare_linked_gridpoints(
      data_position_links = tibble::tibble(
        position_id = c(1L, 1L, 2L, 3L, 3L),
        gridpoint_id = c(5L, 1L, 5L, 9L, 7L)
      ),
      data_cells = data_cells,
      vec_ages = c(0, 500, 22000)
    )

  data_expected <-
    tibble::tibble(
      gridpoint_id = c(1L, 5L, 7L, 9L),
      coord_long = c(-20.5, 0, 14.1, 14.1),
      coord_lat = c(10, 89.99, -0.05, -0.05),
      age = c(0, 500, 0, 22000),
      dataset_name = c(
        "geo_-20.5_10", "geo_0_89.99", "geo_14.1_-0.05", "geo_14.1_-0.05"
      ),
      sample_name = c(
        "geo_-20.5_10_0", "geo_0_89.99_500", "geo_14.1_-0.05_0",
        "geo_14.1_-0.05_22000"
      )
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_linked_gridpoints() inverts the link ids", {
  data_cells <-
    tidyr::expand_grid(
      coord_long = c(-179.99, 0.5, 120.25),
      coord_lat = c(-60.01, 0, 45.75)
    ) |>
    dplyr::mutate(cell_index = dplyr::row_number(), .before = 1L)

  vec_ages <-
    c(0, 1500, 21000)

  data_gridpoints <-
    tidyr::expand_grid(
      data_cells,
      tibble::tibble(age_index = base::seq_len(3L), age = vec_ages)
    ) |>
    dplyr::mutate(gridpoint_id = (cell_index - 1L) * 3L + age_index)

  res <-
    prepare_linked_gridpoints(
      data_position_links = dplyr::select(data_gridpoints, gridpoint_id),
      data_cells = data_cells,
      vec_ages = vec_ages
    )

  testthat::expect_equal(base::nrow(res), 27L)
  testthat::expect_equal(
    dplyr::select(res, gridpoint_id, coord_long, coord_lat, age),
    dplyr::select(data_gridpoints, gridpoint_id, coord_long, coord_lat, age)
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_linked_gridpoints() refuses unknown ids", {
  data_cells <-
    tibble::tibble(
      cell_index = c(1L, 2L),
      coord_long = c(0, 1),
      coord_lat = c(0, 0)
    )

  purrr::walk(
    .x = list(0L, 5L, NA_integer_, -1L),
    .f = ~ testthat::expect_error(
      prepare_linked_gridpoints(
        data_position_links = tibble::tibble(gridpoint_id = c(1L, .x)),
        data_cells = data_cells,
        vec_ages = c(0, 100)
      ),
      regexp = "gridpoint_id"
    )
  )
})

testthat::test_that("prepare_linked_gridpoints() accepts no links", {
  res <-
    prepare_linked_gridpoints(
      data_position_links = tibble::tibble(
        position_id = base::integer(),
        gridpoint_id = base::integer()
      ),
      data_cells = tibble::tibble(
        cell_index = 1L,
        coord_long = 0,
        coord_lat = 0
      ),
      vec_ages = 0
    )

  testthat::expect_equal(base::nrow(res), 0L)
  testthat::expect_named(
    res,
    c(
      "gridpoint_id", "coord_long", "coord_lat", "age", "dataset_name",
      "sample_name"
    )
  )
})
