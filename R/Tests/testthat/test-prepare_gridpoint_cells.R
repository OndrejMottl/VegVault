#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_cells() validates list_coordinates", {
  data_coordinates <-
    tibble::tibble(long = c(14.123, 15), lat = c(50, 49.996))

  testthat::expect_error(
    prepare_gridpoint_cells(list_coordinates = data_coordinates),
    regexp = "list_coordinates"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(list_coordinates = list()),
    regexp = "list_coordinates"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(list_coordinates = list(1:3)),
    regexp = "list_coordinates"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(tibble::tibble(x = 1, lat = 2))
    ),
    regexp = "numeric columns"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(tibble::tibble(long = "1", lat = 2))
    ),
    regexp = "numeric columns"
  )
})

testthat::test_that("prepare_gridpoint_cells() validates n_digits", {
  list_coordinates <-
    list(tibble::tibble(long = c(14.123, 15), lat = c(50, 49.996)))

  vec_bad_digits <-
    list(-1L, 1.5, "2", c(1L, 2L), NA_integer_)

  purrr::walk(
    .x = vec_bad_digits,
    .f = ~ testthat::expect_error(
      prepare_gridpoint_cells(
        list_coordinates = list_coordinates,
        n_digits = .x
      ),
      regexp = "n_digits"
    )
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_cells() returns the cell columns", {
  res <-
    prepare_gridpoint_cells(
      list_coordinates = list(
        tibble::tibble(long = c(14.123, 15), lat = c(50, 49.996))
      )
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("cell_index", "coord_long", "coord_lat"))
  testthat::expect_type(dplyr::pull(res, cell_index), "integer")
  testthat::expect_type(dplyr::pull(res, coord_long), "double")
  testthat::expect_type(dplyr::pull(res, coord_lat), "double")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_cells() rounds, merges and sorts", {
  list_coordinates <-
    list(
      tibble::tibble(
        long = c(14.123, 14.1249, 15, NA, 10),
        lat = c(50.004, 50.0049, 50, 1, 5)
      ),
      tibble::tibble(
        long = c(-20.5, 15.001, 10, 3),
        lat = c(10, 49.996, -5, NA)
      )
    )

  res <-
    prepare_gridpoint_cells(list_coordinates = list_coordinates)

  data_expected <-
    tibble::tibble(
      cell_index = base::seq_len(5L),
      coord_long = c(-20.5, 10, 10, 14.12, 15),
      coord_lat = c(10, -5, 5, 50, 50)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_gridpoint_cells() uses n_digits", {
  list_coordinates <-
    list(
      tibble::tibble(
        long = c(14.123, 15.001, 14.4),
        lat = c(50.004, 49.996, 49.6)
      )
    )

  res <-
    prepare_gridpoint_cells(
      list_coordinates = list_coordinates,
      n_digits = 0L
    )

  data_expected <-
    tibble::tibble(
      cell_index = base::seq_len(2L),
      coord_long = c(14, 15),
      coord_lat = c(50, 50)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_gridpoint_cells() ignores other columns", {
  res <-
    prepare_gridpoint_cells(
      list_coordinates = list(
        tibble::tibble(long = 1, lat = 2, value = 3, time_id = "20")
      )
    )

  testthat::expect_named(res, c("cell_index", "coord_long", "coord_lat"))
  testthat::expect_equal(base::nrow(res), 1L)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_cells() keeps the range limits", {
  res <-
    prepare_gridpoint_cells(
      list_coordinates = list(
        tibble::tibble(
          long = c(-180, 180.004, 0),
          lat = c(-90, 90, 89.996)
        )
      )
    )

  testthat::expect_equal(dplyr::pull(res, coord_long), c(-180, 0, 180))
  testthat::expect_equal(dplyr::pull(res, coord_lat), c(-90, 90, 90))
})

testthat::test_that("prepare_gridpoint_cells() refuses impossible cells", {
  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(tibble::tibble(long = 180.006, lat = 0))
    ),
    regexp = "outside"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(tibble::tibble(long = 0, lat = -90.01))
    ),
    regexp = "outside"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(tibble::tibble(long = Inf, lat = 0))
    ),
    regexp = "outside"
  )
})

testthat::test_that("prepare_gridpoint_cells() refuses an empty grid", {
  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(
        tibble::tibble(long = c(NA, 1), lat = c(2, NA))
      )
    ),
    regexp = "No cell"
  )

  testthat::expect_error(
    prepare_gridpoint_cells(
      list_coordinates = list(
        tibble::tibble(long = base::numeric(), lat = base::numeric())
      )
    ),
    regexp = "No cell"
  )
})

testthat::test_that("prepare_gridpoint_cells() handles a large grid", {
  data_coordinates <-
    tidyr::expand_grid(
      long = base::seq(from = 0.001, to = 99.001, by = 1),
      lat = base::seq(from = -49.999, to = 49.001, by = 1)
    )

  res <-
    prepare_gridpoint_cells(
      list_coordinates = list(data_coordinates, data_coordinates)
    )

  testthat::expect_equal(base::nrow(res), 10000L)
  testthat::expect_equal(
    dplyr::pull(res, cell_index),
    base::seq_len(10000L)
  )
  testthat::expect_false(
    base::is.unsorted(dplyr::pull(res, coord_long))
  )
})
