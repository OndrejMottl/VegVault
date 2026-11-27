#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_link_windows() validates data_positions", {
  data_positions <-
    tibble::tibble(
      position_id = c(1L, 2L),
      coord_long = c(0, 10),
      coord_lat = c(0, 20),
      age = c(0, 0)
    )

  list_bad_positions <-
    list(
      "a",
      dplyr::select(data_positions, -age),
      dplyr::mutate(data_positions, position_id = c(1, 2)),
      dplyr::mutate(data_positions, position_id = c(1L, 1L)),
      dplyr::mutate(data_positions, coord_lat = c(0, NA)),
      dplyr::mutate(data_positions, coord_long = c("0", "10"))
    )

  purrr::walk(
    .x = list_bad_positions,
    .f = ~ testthat::expect_error(
      build_link_windows(
        data_positions = .x,
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = 0.01,
        n_chunk_size = 10L
      ),
      regexp = "data_positions"
    )
  )
})

testthat::test_that("build_link_windows() validates the settings", {
  data_positions <-
    tibble::tibble(position_id = 1L, coord_long = 0, coord_lat = 0, age = 0)

  list_valid <-
    list(
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 10L
    )

  list_bad_values <-
    list(
      distance_km = list(0, -1, "50", NA_real_, c(1, 2)),
      radius_min_km = list(0, -6335.4, NA_real_),
      margin_deg = list(-0.1, NA_real_, "0"),
      n_chunk_size = list(0L, 1.5, NA_integer_, c(1L, 2L))
    )

  purrr::iwalk(
    .x = list_bad_values,
    .f = ~ {
      sel_argument <- .y

      purrr::walk(
        .x = .x,
        .f = ~ {
          list_arguments <-
            purrr::list_modify(
              list_valid,
              !!sel_argument := .x
            )

          testthat::expect_error(
            rlang::exec(
              .fn = build_link_windows,
              data_positions = data_positions,
              !!!list_arguments
            ),
            regexp = sel_argument
          )
        }
      )
    }
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_link_windows() splits positions into chunks", {
  data_positions <-
    tibble::tibble(
      position_id = c(5L, 1L, 7L, 3L, 2L, 6L, 4L),
      coord_long = c(5, 1, 7, 3, 2, 6, 4),
      coord_lat = 0,
      age = c(500, 100, 700, 300, 200, 600, 400)
    )

  res <-
    build_link_windows(
      data_positions = data_positions,
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 3L
    )

  testthat::expect_type(res, "list")
  testthat::expect_named(res, c("chunk_1", "chunk_2", "chunk_3"))

  purrr::walk(
    .x = res,
    .f = ~ {
      testthat::expect_s3_class(.x, "tbl_df")
      testthat::expect_named(
        .x,
        c(
          "position_id", "coord_long", "coord_lat", "age",
          "lat_lo", "lat_hi", "lon_lo", "lon_hi"
        )
      )
    }
  )

  testthat::expect_equal(
    purrr::map(.x = res, .f = ~ dplyr::pull(.x, position_id)),
    list(chunk_1 = 1:3, chunk_2 = 4:6, chunk_3 = 7L)
  )

  testthat::expect_equal(
    purrr::map(.x = res, .f = ~ dplyr::pull(.x, age)),
    list(
      chunk_1 = c(100, 200, 300),
      chunk_2 = c(400, 500, 600),
      chunk_3 = 700
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_link_windows() windows hold every point in range", {
  set.seed(900723)

  data_positions <-
    tibble::tibble(
      coord_long = c(
        0, 10, 179.99, -179.99, 179.6, -179.6, 25, 25, 25, 25, 25, -40,
        179.9, 0, stats::runif(n = 40L, min = -180, max = 180)
      ),
      coord_lat = c(
        0, 45, 0, 0, 63.3, 70, 80, 85, 89.5, 89.99, -89.99, -75,
        80, 90, stats::runif(n = 40L, min = -90, max = 90)
      ),
      age = 0
    ) |>
    dplyr::mutate(position_id = dplyr::row_number())

  data_windows <-
    build_link_windows(
      data_positions = data_positions,
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0,
      n_chunk_size = 1000L
    ) |>
    dplyr::bind_rows()

  data_points <-
    tidyr::expand_grid(
      data_positions,
      bearing = base::seq(from = 0, to = 345, by = 15),
      distance_m = c(1000, 25000, 49999, 50000)
    )

  mat_destination <-
    geosphere::destPoint(
      p = base::cbind(
        dplyr::pull(data_points, coord_long),
        dplyr::pull(data_points, coord_lat)
      ),
      b = dplyr::pull(data_points, bearing),
      d = dplyr::pull(data_points, distance_m)
    )

  data_inside <-
    data_points |>
    dplyr::mutate(
      point_id = dplyr::row_number(),
      point_long = mat_destination[, 1],
      point_lat = mat_destination[, 2]
    ) |>
    dplyr::select(position_id, point_id, point_long, point_lat) |>
    dplyr::inner_join(
      dplyr::select(
        data_windows,
        position_id, lat_lo, lat_hi, lon_lo, lon_hi
      ),
      by = dplyr::join_by(position_id),
      relationship = "many-to-many"
    ) |>
    dplyr::mutate(
      flag_inside = point_lat >= lat_lo &
        point_lat <= lat_hi &
        point_long >= lon_lo &
        point_long <= lon_hi
    ) |>
    dplyr::summarise(
      flag_inside = base::any(flag_inside),
      .by = point_id
    )

  testthat::expect_equal(
    base::nrow(data_inside),
    base::nrow(data_points)
  )
  testthat::expect_true(
    base::all(dplyr::pull(data_inside, flag_inside))
  )
})

testthat::test_that("build_link_windows() keeps windows narrow", {
  res <-
    build_link_windows(
      data_positions = tibble::tibble(
        position_id = 1L,
        coord_long = 10,
        coord_lat = 0,
        age = 0
      ),
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0,
      n_chunk_size = 10L
    ) |>
    purrr::chuck(1L)

  # 50 km east of the equator is 0.4492 degrees of longitude
  testthat::expect_equal(base::nrow(res), 1L)
  testthat::expect_true(dplyr::pull(res, lon_hi) - 10 > 0.4491)
  testthat::expect_true(dplyr::pull(res, lon_hi) - 10 < 0.46)
  testthat::expect_true(10 - dplyr::pull(res, lon_lo) < 0.46)
  testthat::expect_true(dplyr::pull(res, lat_hi) < 0.46)
  testthat::expect_true(dplyr::pull(res, lat_lo) > -0.46)
})

testthat::test_that("build_link_windows() widens windows by margin_deg", {
  data_positions <-
    tibble::tibble(
      position_id = c(1L, 2L),
      coord_long = c(10, -60),
      coord_lat = c(0, 70),
      age = 0
    )

  list_windows <-
    purrr::map(
      .x = c(0, 0.5),
      .f = ~ build_link_windows(
        data_positions = data_positions,
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = .x,
        n_chunk_size = 10L
      ) |>
        purrr::chuck(1L)
    )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(list_windows, 2L), lat_hi) -
      dplyr::pull(purrr::chuck(list_windows, 1L), lat_hi),
    c(0.5, 0.5),
    tolerance = 1e-8
  )

  testthat::expect_true(
    base::all(
      dplyr::pull(purrr::chuck(list_windows, 2L), lon_hi) -
        dplyr::pull(purrr::chuck(list_windows, 1L), lon_hi) >= 0.5
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("build_link_windows() splits windows at the dateline", {
  res <-
    build_link_windows(
      data_positions = tibble::tibble(
        position_id = c(1L, 2L, 3L),
        coord_long = c(179.9, -179.8, 0),
        coord_lat = c(0, 10, 0),
        age = 0
      ),
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 10L
    ) |>
    purrr::chuck(1L) |>
    dplyr::arrange(position_id, lon_lo)

  testthat::expect_equal(
    dplyr::pull(res, position_id),
    c(1L, 1L, 2L, 2L, 3L)
  )

  data_east <-
    dplyr::filter(res, position_id == 1L)

  testthat::expect_equal(dplyr::pull(data_east, lon_lo)[1], -180)
  testthat::expect_true(dplyr::pull(data_east, lon_hi)[1] > -179.7)
  testthat::expect_true(dplyr::pull(data_east, lon_hi)[1] < -179.6)
  testthat::expect_true(dplyr::pull(data_east, lon_lo)[2] < 179.5)
  testthat::expect_equal(dplyr::pull(data_east, lon_hi)[2], 180)

  data_west <-
    dplyr::filter(res, position_id == 2L)

  testthat::expect_equal(dplyr::pull(data_west, lon_lo)[1], -180)
  testthat::expect_true(dplyr::pull(data_west, lon_lo)[2] > 179.6)
  testthat::expect_equal(dplyr::pull(data_west, lon_hi)[2], 180)
})

testthat::test_that("build_link_windows() spans all longitudes at a pole", {
  res <-
    build_link_windows(
      data_positions = tibble::tibble(
        position_id = c(1L, 2L, 3L),
        coord_long = c(30, -100, 30),
        coord_lat = c(89.9, -89.7, 85),
        age = 0
      ),
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 10L
    ) |>
    purrr::chuck(1L) |>
    dplyr::arrange(position_id)

  testthat::expect_equal(dplyr::pull(res, position_id), c(1L, 2L, 3L))
  testthat::expect_equal(dplyr::pull(res, lon_lo)[1:2], c(-180, -180))
  testthat::expect_equal(dplyr::pull(res, lon_hi)[1:2], c(180, 180))
  testthat::expect_true(dplyr::pull(res, lon_hi)[3] < 37)
  testthat::expect_true(dplyr::pull(res, lon_lo)[3] > 23)
})
