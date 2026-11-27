#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_rounded_rectangle() spans the rectangle", {
  res <-
    build_rounded_rectangle(
      x = 1, y = 2, width = 4, height = 2, radius = 0.5, n_corner = 5L
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("x", "y"))

  testthat::expect_equal(base::nrow(res), 20L)

  testthat::expect_equal(base::range(dplyr::pull(res, x)), c(-1, 3))

  testthat::expect_equal(base::range(dplyr::pull(res, y)), c(1, 3))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_rounded_rectangle() rounds each corner", {
  res <-
    build_rounded_rectangle(
      x = 0, y = 0, width = 4, height = 2, radius = 0.5, n_corner = 5L
    )

  # The first arc belongs to the top-right corner, centred 0.5 inside it
  data_arc <-
    dplyr::slice(res, 1:5)

  vec_distance <-
    base::sqrt(
      (dplyr::pull(data_arc, x) - 1.5)^2 + (dplyr::pull(data_arc, y) - 0.5)^2
    )

  testthat::expect_equal(vec_distance, base::rep(0.5, 5L))

  testthat::expect_equal(
    c(dplyr::pull(data_arc, x)[1], dplyr::pull(data_arc, y)[1]),
    c(2, 0.5)
  )

  testthat::expect_equal(
    c(dplyr::pull(data_arc, x)[5], dplyr::pull(data_arc, y)[5]),
    c(1.5, 1)
  )
})

testthat::test_that("build_rounded_rectangle() goes counter-clockwise", {
  res <-
    build_rounded_rectangle(
      x = 0, y = 0, width = 4, height = 2, radius = 0.5, n_corner = 5L
    )

  vec_x <-
    dplyr::pull(res, x)

  vec_y <-
    dplyr::pull(res, y)

  # The shoelace area is positive for a counter-clockwise outline
  value_area <-
    base::sum(vec_x * c(vec_y[-1], vec_y[1]) - c(vec_x[-1], vec_x[1]) * vec_y) /
    2

  testthat::expect_true(value_area > 0)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("build_rounded_rectangle() keeps sharp corners at 0", {
  res <-
    build_rounded_rectangle(
      x = 0, y = 0, width = 4, height = 2, radius = 0, n_corner = 3L
    )

  testthat::expect_equal(
    dplyr::distinct(res),
    tibble::tibble(x = c(2, -2, -2, 2), y = c(1, 1, -1, -1))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_rounded_rectangle() validates its arguments", {
  testthat::expect_error(
    build_rounded_rectangle(
      x = 0, y = 0, width = 0, height = 2, radius = 0
    ),
    regexp = "width"
  )

  testthat::expect_error(
    build_rounded_rectangle(
      x = 0, y = 0, width = 4, height = 2, radius = 1.5
    ),
    regexp = "radius"
  )

  testthat::expect_error(
    build_rounded_rectangle(
      x = NA_real_, y = 0, width = 4, height = 2, radius = 0.5
    ),
    regexp = "x"
  )

  testthat::expect_error(
    build_rounded_rectangle(
      x = 0, y = 0, width = 4, height = 2, radius = 0.5, n_corner = 1L
    ),
    regexp = "n_corner"
  )
})
