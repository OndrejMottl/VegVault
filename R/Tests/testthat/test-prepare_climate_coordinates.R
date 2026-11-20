#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_climate_coordinates() lists distinct points", {
  list_data <-
    list(
      a.qs = tibble::tibble(
        long = c(2, 1, 1, NA),
        lat = c(5, 6, 6, 7),
        value = 1:4
      ),
      b.qs = tibble::tibble(long = 1, lat = 6, value = 9L)
    )

  res <-
    prepare_climate_coordinates(list_data = list_data)

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(res, tibble::tibble(long = c(1, 2), lat = c(6, 5)))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_climate_coordinates() keeps the decimals", {
  list_data <-
    list(
      a.qs = tibble::tibble(
        long = c(10.124, 10.126, 10.124),
        lat = c(50, 50, 49.999)
      )
    )

  res <-
    prepare_climate_coordinates(list_data = list_data)

  testthat::expect_equal(
    res,
    tibble::tibble(long = c(10.124, 10.124, 10.126), lat = c(49.999, 50, 50))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_climate_coordinates() needs long and lat", {
  testthat::expect_error(
    prepare_climate_coordinates(
      list_data = list(a.qs = tibble::tibble(longitude = 1, latitude = 2))
    ),
    regexp = "long"
  )

  testthat::expect_error(
    prepare_climate_coordinates(list_data = tibble::tibble(long = 1, lat = 2)),
    regexp = "list_data"
  )
})

testthat::test_that("prepare_climate_coordinates() needs a table", {
  testthat::expect_error(
    prepare_climate_coordinates(list_data = list()),
    regexp = "list_data"
  )
})
