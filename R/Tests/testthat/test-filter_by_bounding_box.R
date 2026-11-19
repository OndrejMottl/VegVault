#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("filter_by_bounding_box() validates arguments", {
  data_points <-
    tibble::tibble(lon = 0, lat = 0)

  list_box <-
    list(lon_min = -10, lon_max = 10, lat_min = -5, lat_max = 5)

  testthat::expect_error(
    filter_by_bounding_box(
      data_source = list(lon = 0, lat = 0),
      list_bounding_box = list_box,
      col_lon = "lon",
      col_lat = "lat"
    ),
    regexp = "data_source"
  )

  testthat::expect_error(
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list_box,
      col_lon = "longitude",
      col_lat = "lat"
    ),
    regexp = "longitude"
  )

  testthat::expect_error(
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(lon_min = -10, lon_max = 10),
      col_lon = "lon",
      col_lat = "lat"
    ),
    regexp = "lat_min"
  )

  testthat::expect_error(
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list_box,
      col_lon = "lon",
      col_lat = "lat",
      margin_lon = -1
    ),
    regexp = "margin"
  )

  testthat::expect_error(
    filter_by_bounding_box(
      data_source = tibble::tibble(lon = "0", lat = 0),
      list_bounding_box = list_box,
      col_lon = "lon",
      col_lat = "lat"
    ),
    regexp = "numeric"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("filter_by_bounding_box() keeps points inside", {
  data_points <-
    tibble::tibble(
      id = 1:5,
      lon = c(0, 20, -9.5, 0, 9.9),
      lat = c(0, 0, 4, 6, -4.9),
      value = c("a", "b", "c", "d", "e")
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = -5,
        lat_max = 5
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("id", "lon", "lat", "value"))

  testthat::expect_equal(dplyr::pull(res, id), c(1L, 3L, 5L))
})

testthat::test_that("filter_by_bounding_box() keeps points on the edge", {
  data_points <-
    tibble::tibble(
      id = 1:6,
      lon = c(-10, 10, 0, 0, 10, 10.000001),
      lat = c(0, 0, -5, 5, 5, 0)
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = -5,
        lat_max = 5
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  testthat::expect_equal(dplyr::pull(res, id), 1:5)
})

testthat::test_that("filter_by_bounding_box() drops missing coordinates", {
  data_points <-
    tibble::tibble(
      id = 1:4,
      lon = c(0, NA, 0, NaN),
      lat = c(0, 0, NA, 0)
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = -5,
        lat_max = 5
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  testthat::expect_equal(dplyr::pull(res, id), 1L)
})

testthat::test_that("filter_by_bounding_box() widens the box by margins", {
  data_points <-
    tibble::tibble(
      id = 1:4,
      long = c(-11.5, 11.6, 0, 0),
      lat = c(0, 0, 5.5, -5.6)
    )

  list_box <-
    list(
      box_name = "test",
      lon_min = -10,
      lon_max = 10,
      lat_min = -5,
      lat_max = 5
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list_box,
      col_lon = "long",
      col_lat = "lat",
      margin_lon = 1.5,
      margin_lat = 0.5
    )

  testthat::expect_equal(dplyr::pull(res, id), c(1L, 3L))

  res_no_margin <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list_box,
      col_lon = "long",
      col_lat = "lat"
    )

  testthat::expect_equal(base::nrow(res_no_margin), 0L)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("filter_by_bounding_box() keeps a zero-row table", {
  data_points <-
    tibble::tibble(
      lon = base::numeric(0),
      lat = base::numeric(0),
      value = base::character(0)
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = -5,
        lat_max = 5
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(res, c("lon", "lat", "value"))
})

testthat::test_that("filter_by_bounding_box() keeps list-columns", {
  data_points <-
    tibble::tibble(
      lon = c(0, 50),
      lat = c(0, 0),
      levels = list(
        tibble::tibble(depth = 1:2),
        tibble::tibble(depth = 3L)
      )
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -10,
        lon_max = 10,
        lat_min = -5,
        lat_max = 5
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  testthat::expect_equal(base::nrow(res), 1L)

  testthat::expect_equal(
    dplyr::pull(res, levels),
    list(tibble::tibble(depth = 1:2))
  )
})

testthat::test_that("filter_by_bounding_box() scales to many records", {
  base::set.seed(900723)

  data_points <-
    tibble::tibble(
      lon = stats::runif(n = 10000L, min = -180, max = 180),
      lat = stats::runif(n = 10000L, min = -90, max = 90)
    )

  res <-
    filter_by_bounding_box(
      data_source = data_points,
      list_bounding_box = list(
        lon_min = -170,
        lon_max = -125,
        lat_min = 54,
        lat_max = 72
      ),
      col_lon = "lon",
      col_lat = "lat"
    )

  vec_lon <-
    dplyr::pull(res, lon)

  vec_lat <-
    dplyr::pull(res, lat)

  testthat::expect_true(base::nrow(res) > 0L)

  testthat::expect_true(base::all(vec_lon >= -170 & vec_lon <= -125))

  testthat::expect_true(base::all(vec_lat >= 54 & vec_lat <= 72))
})
