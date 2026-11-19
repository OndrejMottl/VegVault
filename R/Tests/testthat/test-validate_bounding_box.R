#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_bounding_box() returns a valid box", {
  list_box <-
    list(
      box_name = "alaska_yukon",
      lon_min = -170,
      lon_max = -125,
      lat_min = 54,
      lat_max = 72
    )

  res <-
    validate_bounding_box(list_bounding_box = list_box)

  testthat::expect_identical(res, list_box)

  testthat::expect_invisible(
    validate_bounding_box(list_bounding_box = list_box)
  )
})

testthat::test_that("validate_bounding_box() accepts the world limits", {
  res <-
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -180L,
        lon_max = 180L,
        lat_min = -90L,
        lat_max = 90L
      )
    )

  testthat::expect_type(res, "list")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_bounding_box() needs every bound", {
  testthat::expect_error(
    validate_bounding_box(list_bounding_box = c(lon_min = 1)),
    regexp = "list"
  )

  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(lon_min = -10, lon_max = 10, lat_min = 0)
    ),
    regexp = "lat_max"
  )
})

testthat::test_that("validate_bounding_box() needs numeric scalars", {
  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = "-10",
        lon_max = 10,
        lat_min = 0,
        lat_max = 10
      )
    ),
    regexp = "lon_min"
  )

  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -10,
        lon_max = c(10, 20),
        lat_min = 0,
        lat_max = 10
      )
    ),
    regexp = "lon_max"
  )

  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = NA_real_,
        lat_max = 10
      )
    ),
    regexp = "lat_min"
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("validate_bounding_box() rejects values out of range", {
  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -181,
        lon_max = 10,
        lat_min = 0,
        lat_max = 10
      )
    ),
    regexp = "-180"
  )

  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = 0,
        lat_max = 91
      )
    ),
    regexp = "-90"
  )
})

testthat::test_that("validate_bounding_box() rejects inverted bounds", {
  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = 170,
        lon_max = -170,
        lat_min = 0,
        lat_max = 10
      )
    ),
    regexp = "dateline"
  )

  testthat::expect_error(
    validate_bounding_box(
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = 10,
        lat_max = 10
      )
    ),
    regexp = "lat_min"
  )
})
