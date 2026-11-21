#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_modern_positions() validates list_data", {
  data_plots <-
    tibble::tibble(longitude = 14, latitude = 50)

  testthat::expect_error(
    prepare_modern_positions(list_data = data_plots),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_modern_positions(list_data = list()),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_modern_positions(list_data = list("a")),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_modern_positions(
      list_data = list(tibble::tibble(longitude = 14, lat = 50))
    ),
    regexp = "numeric columns"
  )

  testthat::expect_error(
    prepare_modern_positions(
      list_data = list(tibble::tibble(longitude = "14", latitude = 50))
    ),
    regexp = "numeric columns"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_modern_positions() returns position columns", {
  res <-
    prepare_modern_positions(
      list_data = list(
        tibble::tibble(longitude = 14L, latitude = 50L, plot_name = "a")
      )
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("coord_long", "coord_lat", "age"))
  testthat::expect_type(dplyr::pull(res, coord_long), "double")
  testthat::expect_type(dplyr::pull(res, coord_lat), "double")
  testthat::expect_type(dplyr::pull(res, age), "double")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_modern_positions() lists distinct positions", {
  list_data <-
    list(
      file_1 = tibble::tibble(
        longitude = c(14.25, 14.25, -120.5, NA),
        latitude = c(50.1, 50.1, 45, 3),
        trait_value = c(1, 2, 3, 4)
      ),
      file_2 = tibble::tibble(
        longitude = c(-120.5, 0.123456789, NA),
        latitude = c(45, -10, 3),
        trait_value = c(5, 6, 7)
      )
    )

  res <-
    prepare_modern_positions(list_data = list_data) |>
    dplyr::arrange(coord_long, coord_lat)

  data_expected <-
    tibble::tibble(
      coord_long = c(-120.5, 0.123456789, 14.25, NA),
      coord_lat = c(45, -10, 50.1, 3),
      age = c(0, 0, 0, 0)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_modern_positions() keeps coordinates exact", {
  vec_longitude <-
    c(14.123456789012, -0.000001)

  res <-
    prepare_modern_positions(
      list_data = list(
        tibble::tibble(longitude = vec_longitude, latitude = c(1, 2))
      )
    ) |>
    dplyr::arrange(coord_lat)

  testthat::expect_identical(dplyr::pull(res, coord_long), vec_longitude)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_modern_positions() accepts empty tables", {
  res <-
    prepare_modern_positions(
      list_data = list(
        tibble::tibble(
          longitude = base::numeric(),
          latitude = base::numeric()
        )
      )
    )

  testthat::expect_equal(base::nrow(res), 0L)
  testthat::expect_named(res, c("coord_long", "coord_lat", "age"))
})
