#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_position_links() validates the data", {
  data_windows <-
    tibble::tibble(
      position_id = 1L,
      coord_long = 0,
      coord_lat = 0,
      age = 0,
      lat_lo = -0.5,
      lat_hi = 0.5,
      lon_lo = -0.5,
      lon_hi = 0.5
    )

  data_cells <-
    tibble::tibble(cell_index = 1L, coord_long = 0.1, coord_lat = 0)

  testthat::expect_error(
    compute_position_links(
      data_windows = dplyr::select(data_windows, -lon_hi),
      data_cells = data_cells,
      vec_ages = 0,
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    ),
    regexp = "data_windows"
  )

  list_bad_cells <-
    list(
      dplyr::select(data_cells, -coord_lat),
      dplyr::mutate(data_cells, cell_index = 2L),
      dplyr::mutate(data_cells, cell_index = 1),
      dplyr::mutate(data_cells, coord_long = NA_real_)
    )

  purrr::walk(
    .x = list_bad_cells,
    .f = ~ testthat::expect_error(
      compute_position_links(
        data_windows = data_windows,
        data_cells = .x,
        vec_ages = 0,
        distance_km = 50,
        distance_years = 5000,
        age_margin_years = 1
      ),
      regexp = "data_cells"
    )
  )

  list_bad_ages <-
    list(c(5000, 0), c(0, 0), c(0, NA), c(0, Inf), "0", base::numeric())

  purrr::walk(
    .x = list_bad_ages,
    .f = ~ testthat::expect_error(
      compute_position_links(
        data_windows = data_windows,
        data_cells = data_cells,
        vec_ages = .x,
        distance_km = 50,
        distance_years = 5000,
        age_margin_years = 1
      ),
      regexp = "vec_ages"
    )
  )
})

testthat::test_that("compute_position_links() validates the thresholds", {
  data_windows <-
    tibble::tibble(
      position_id = 1L,
      coord_long = 0,
      coord_lat = 0,
      age = 0,
      lat_lo = -0.5,
      lat_hi = 0.5,
      lon_lo = -0.5,
      lon_hi = 0.5
    )

  data_cells <-
    tibble::tibble(cell_index = 1L, coord_long = 0.1, coord_lat = 0)

  list_valid <-
    list(distance_km = 50, distance_years = 5000, age_margin_years = 1)

  list_bad_values <-
    list(
      distance_km = list(0, -50, NA_real_, "50", c(50, 60)),
      distance_years = list(-1, NA_real_, "5000"),
      age_margin_years = list(-1, NA_real_, c(1, 2))
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
              .fn = compute_position_links,
              data_windows = data_windows,
              data_cells = data_cells,
              vec_ages = 0,
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

testthat::test_that("compute_position_links() returns integer link columns", {
  data_windows <-
    build_link_windows(
      data_positions = tibble::tibble(
        position_id = 1L,
        coord_long = 0,
        coord_lat = 0,
        age = 1000
      ),
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 10L
    ) |>
    purrr::chuck(1L)

  res <-
    compute_position_links(
      data_windows = data_windows,
      data_cells = tibble::tibble(
        cell_index = c(1L, 2L),
        coord_long = c(0.3, 0.5),
        coord_lat = c(0, 0)
      ),
      vec_ages = c(0, 1000, 6000, 7000),
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(
    res,
    c("position_id", "gridpoint_id", "distance_in_km", "distance_in_years")
  )

  purrr::walk(
    .x = res,
    .f = ~ testthat::expect_type(.x, "integer")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_position_links() links a hand-checked case", {
  data_windows <-
    build_link_windows(
      data_positions = tibble::tibble(
        position_id = 1L,
        coord_long = 0,
        coord_lat = 0,
        age = 1000
      ),
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 10L
    ) |>
    purrr::chuck(1L)

  res <-
    compute_position_links(
      data_windows = data_windows,
      data_cells = tibble::tibble(
        cell_index = c(1L, 2L),
        coord_long = c(0.3, 0.5),
        coord_lat = c(0, 0)
      ),
      vec_ages = c(0, 1000, 6000, 7000),
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  # The cell at 0.3 degrees is 33.4 km away, the one at 0.5 is 55.7 km;
  #   ages 0, 1000 and 6000 are within 5000 years of 1000, 7000 is not
  data_expected <-
    tibble::tibble(
      position_id = c(1L, 1L, 1L),
      gridpoint_id = c(1L, 2L, 3L),
      distance_in_km = c(33L, 33L, 33L),
      distance_in_years = c(1000L, 0L, 5000L)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("compute_position_links() matches a brute-force search", {
  set.seed(900723)

  # Cells: dense blocks at the dateline, at high latitude (also across the
  #   dateline) and at both poles, plus random cells over the globe
  data_cells_raw <-
    dplyr::bind_rows(
      tidyr::expand_grid(
        coord_long = c(
          base::seq(from = 178, to = 180, by = 0.1),
          base::seq(from = -180, to = -178, by = 0.1)
        ),
        coord_lat = base::seq(from = -1, to = 1, by = 0.1)
      ),
      tidyr::expand_grid(
        coord_long = base::seq(from = 0, to = 4, by = 0.1),
        coord_lat = base::seq(from = 69, to = 71, by = 0.1)
      ),
      tidyr::expand_grid(
        coord_long = c(
          base::seq(from = 177, to = 180, by = 0.25),
          base::seq(from = -180, to = -177, by = 0.25)
        ),
        coord_lat = base::seq(from = 79, to = 81, by = 0.1)
      ),
      tidyr::expand_grid(
        coord_long = base::seq(from = -180, to = 180, by = 10),
        coord_lat = c(
          base::seq(from = 89.5, to = 90, by = 0.1),
          base::seq(from = -90, to = -89.5, by = 0.1)
        )
      ),
      tibble::tibble(
        coord_long = stats::runif(n = 2000L, min = -180, max = 180),
        coord_lat = stats::runif(n = 2000L, min = -90, max = 90)
      )
    )

  data_cells <-
    data_cells_raw |>
    dplyr::mutate(
      coord_long = base::round(x = coord_long, digits = 2),
      coord_lat = base::round(x = coord_lat, digits = 2)
    ) |>
    dplyr::distinct() |>
    dplyr::arrange(coord_long, coord_lat) |>
    dplyr::mutate(cell_index = dplyr::row_number(), .before = 1L)

  # Positions: random in each block and over the globe, plus exact cases
  data_positions <-
    dplyr::bind_rows(
      tibble::tibble(
        coord_long = stats::runif(n = 30L, min = 179, max = 181),
        coord_lat = stats::runif(n = 30L, min = -0.8, max = 0.8)
      ),
      tibble::tibble(
        coord_long = stats::runif(n = 30L, min = 0.5, max = 3.5),
        coord_lat = stats::runif(n = 30L, min = 69.3, max = 70.7)
      ),
      tibble::tibble(
        coord_long = stats::runif(n = 30L, min = 178, max = 182),
        coord_lat = stats::runif(n = 30L, min = 79.3, max = 80.7)
      ),
      tibble::tibble(
        coord_long = stats::runif(n = 30L, min = -180, max = 180),
        coord_lat = c(
          stats::runif(n = 15L, min = 89.4, max = 90),
          stats::runif(n = 15L, min = -90, max = -89.4)
        )
      ),
      tibble::tibble(
        coord_long = stats::runif(n = 100L, min = -180, max = 180),
        coord_lat = stats::runif(n = 100L, min = -90, max = 90)
      ),
      tibble::tibble(
        coord_long = c(180, -180, 2, 0),
        coord_lat = c(0, 0, 70, 90)
      )
    ) |>
    dplyr::mutate(
      coord_long = dplyr::if_else(
        condition = coord_long > 180,
        true = coord_long - 360,
        false = coord_long
      ),
      age = base::sample(
        x = c(-73, 0, 2500.5, 5000, 9999.5, 15000),
        size = dplyr::n(),
        replace = TRUE
      ),
      position_id = dplyr::row_number()
    )

  vec_ages <-
    c(0, 1000, 5000, 10000, 15000)

  data_ages <-
    tibble::tibble(
      age_index = base::seq_along(vec_ages),
      grid_age = vec_ages
    )

  # The v1.0.0 rule over every cell and every age
  data_pairs <-
    tidyr::expand_grid(
      data_positions,
      dplyr::rename(
        data_cells,
        grid_long = coord_long,
        grid_lat = coord_lat
      )
    )

  data_expected <-
    data_pairs |>
    dplyr::mutate(
      distance_in_km_exact = geosphere::distGeo(
        p1 = base::cbind(coord_long, coord_lat),
        p2 = base::cbind(grid_long, grid_lat)
      ) / 1e3
    ) |>
    dplyr::filter(distance_in_km_exact <= 50) |>
    tidyr::expand_grid(data_ages) |>
    dplyr::mutate(
      distance_in_years_exact = base::abs(age - grid_age)
    ) |>
    dplyr::filter(distance_in_years_exact <= 5000) |>
    dplyr::mutate(
      gridpoint_id = (cell_index - 1L) * base::length(vec_ages) +
        age_index,
      distance_in_km = base::as.integer(distance_in_km_exact),
      distance_in_years = base::as.integer(distance_in_years_exact)
    ) |>
    dplyr::select(
      position_id, gridpoint_id, distance_in_km, distance_in_years
    ) |>
    dplyr::arrange(position_id, gridpoint_id)

  list_windows <-
    build_link_windows(
      data_positions = data_positions,
      distance_km = 50,
      radius_min_km = 6335.4,
      margin_deg = 0.01,
      n_chunk_size = 37L
    )

  res <-
    purrr::map(
      .x = list_windows,
      .f = ~ compute_position_links(
        data_windows = .x,
        data_cells = data_cells,
        vec_ages = vec_ages,
        distance_km = 50,
        distance_years = 5000,
        age_margin_years = 1
      )
    ) |>
    dplyr::bind_rows()

  # The search must find links in every block, including those v1.0.0
  #   missed: more than 1 degree of longitude away, or across the dateline
  testthat::expect_true(base::nrow(data_expected) > 1000L)
  testthat::expect_equal(res, data_expected)
})

testthat::test_that("compute_position_links() links what v1.0.0 missed", {
  data_positions <-
    tibble::tibble(
      position_id = c(1L, 2L, 3L),
      coord_long = c(1, 179.9, 0),
      coord_lat = c(70, 0, 89.9),
      age = 0
    )

  data_cells <-
    tibble::tibble(
      cell_index = base::seq_len(4L),
      coord_long = c(-179.9, -90, 2.2, 180),
      coord_lat = c(0, 89.95, 70, 89.9)
    )

  res <-
    compute_position_links(
      data_windows = build_link_windows(
        data_positions = data_positions,
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = 0.01,
        n_chunk_size = 10L
      ) |>
        dplyr::bind_rows(),
      data_cells = data_cells,
      vec_ages = 0,
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  # 1.2 degrees of longitude at 70 degrees is 45.8 km; 179.9 and -179.9
  #   are 22.3 km apart; across the pole the cells are below 25 km away
  data_expected <-
    tibble::tibble(
      position_id = c(1L, 2L, 3L, 3L),
      gridpoint_id = c(3L, 1L, 2L, 4L),
      distance_in_km = c(45L, 22L, 12L, 22L)
    )

  testthat::expect_equal(
    dplyr::select(res, -distance_in_years),
    data_expected
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("compute_position_links() applies 50 km verbatim", {
  mat_positions <-
    geosphere::destPoint(
      p = c(0, 0),
      b = 45,
      d = c(49999, 50000, 50001)
    )

  data_positions <-
    tibble::tibble(
      position_id = c(1L, 2L, 3L),
      coord_long = mat_positions[, 1],
      coord_lat = mat_positions[, 2],
      age = 0
    )

  res <-
    compute_position_links(
      data_windows = build_link_windows(
        data_positions = data_positions,
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = 0.01,
        n_chunk_size = 10L
      ) |>
        dplyr::bind_rows(),
      data_cells = tibble::tibble(
        cell_index = 1L,
        coord_long = 0,
        coord_lat = 0
      ),
      vec_ages = 0,
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  flag_exact_linked <-
    geosphere::distGeo(
      p1 = mat_positions[2, ],
      p2 = c(0, 0)
    ) / 1e3 <= 50

  vec_expected_ids <-
    c(1L, 2L)[c(TRUE, flag_exact_linked)]

  testthat::expect_equal(dplyr::pull(res, position_id), vec_expected_ids)
  testthat::expect_true(
    base::all(dplyr::pull(res, distance_in_km) == 49L |
      dplyr::pull(res, distance_in_km) == 50L)
  )
})

testthat::test_that("compute_position_links() applies 5000 years verbatim", {
  data_positions <-
    tibble::tibble(
      position_id = c(1L, 2L, 3L),
      coord_long = 0,
      coord_lat = 0,
      age = c(0, 0.5, -73)
    )

  res <-
    compute_position_links(
      data_windows = build_link_windows(
        data_positions = data_positions,
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = 0.01,
        n_chunk_size = 10L
      ) |>
        dplyr::bind_rows(),
      data_cells = tibble::tibble(
        cell_index = 1L,
        coord_long = 0,
        coord_lat = 0
      ),
      vec_ages = c(0, 5000, 5001),
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  # Age 0 reaches 5000 exactly; 0.5 reaches 5000 (4999.5 years, truncated)
  #   but not 5001 (5000.5 years); -73 reaches only 0
  data_expected <-
    tibble::tibble(
      position_id = c(1L, 1L, 2L, 2L, 3L),
      gridpoint_id = c(1L, 2L, 1L, 2L, 1L),
      distance_in_km = 0L,
      distance_in_years = c(0L, 5000L, 0L, 4999L, 73L)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("compute_position_links() ignores margins and chunks", {
  set.seed(900723)

  data_positions <-
    tibble::tibble(
      position_id = base::seq_len(60L),
      coord_long = stats::runif(n = 60L, min = 9, max = 11),
      coord_lat = stats::runif(n = 60L, min = 59, max = 61),
      age = base::sample(
        x = c(0, 4999.5, 5000.5),
        size = 60L,
        replace = TRUE
      )
    )

  data_cells <-
    tidyr::expand_grid(
      coord_long = base::seq(from = 9, to = 11, by = 0.1),
      coord_lat = base::seq(from = 59, to = 61, by = 0.1)
    ) |>
    dplyr::mutate(cell_index = dplyr::row_number(), .before = 1L)

  list_settings <-
    list(
      one_chunk_no_margin = c(chunk = 1000, age_margin = 0),
      small_chunks_margin = c(chunk = 7, age_margin = 1),
      single_positions_wide_margin = c(chunk = 1, age_margin = 1000)
    )

  list_res <-
    purrr::map(
      .x = list_settings,
      .f = ~ {
        vec_setting <- .x

        build_link_windows(
          data_positions = data_positions,
          distance_km = 50,
          radius_min_km = 6335.4,
          margin_deg = 0.01,
          n_chunk_size = base::as.integer(vec_setting[["chunk"]])
        ) |>
          purrr::map(
            .f = ~ compute_position_links(
              data_windows = .x,
              data_cells = data_cells,
              vec_ages = c(0, 5000, 10000),
              distance_km = 50,
              distance_years = 5000,
              age_margin_years = vec_setting[["age_margin"]]
            )
          ) |>
          dplyr::bind_rows()
      }
    )

  testthat::expect_true(
    base::nrow(purrr::chuck(list_res, 1L)) > 100L
  )
  testthat::expect_equal(
    purrr::chuck(list_res, 2L),
    purrr::chuck(list_res, 1L)
  )
  testthat::expect_equal(
    purrr::chuck(list_res, 3L),
    purrr::chuck(list_res, 1L)
  )
})

testthat::test_that("compute_position_links() returns no rows if no link", {
  res <-
    compute_position_links(
      data_windows = build_link_windows(
        data_positions = tibble::tibble(
          position_id = 1L,
          coord_long = 100,
          coord_lat = 0,
          age = 0
        ),
        distance_km = 50,
        radius_min_km = 6335.4,
        margin_deg = 0.01,
        n_chunk_size = 10L
      ) |>
        purrr::chuck(1L),
      data_cells = tibble::tibble(
        cell_index = 1L,
        coord_long = 0,
        coord_lat = 0
      ),
      vec_ages = 0,
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    )

  testthat::expect_equal(base::nrow(res), 0L)
  testthat::expect_named(
    res,
    c("position_id", "gridpoint_id", "distance_in_km", "distance_in_years")
  )

  purrr::walk(
    .x = res,
    .f = ~ testthat::expect_type(.x, "integer")
  )
})

testthat::test_that("compute_position_links() refuses too many gridpoints", {
  testthat::expect_error(
    compute_position_links(
      data_windows = tibble::tibble(
        position_id = 1L,
        coord_long = 0,
        coord_lat = 0,
        age = 0,
        lat_lo = -0.5,
        lat_hi = 0.5,
        lon_lo = -0.5,
        lon_hi = 0.5
      ),
      data_cells = tibble::tibble(
        cell_index = base::seq_len(1e6),
        coord_long = 0,
        coord_lat = 0
      ),
      vec_ages = base::as.numeric(base::seq_len(3000L)),
      distance_km = 50,
      distance_years = 5000,
      age_margin_years = 1
    ),
    regexp = "integer"
  )
})
