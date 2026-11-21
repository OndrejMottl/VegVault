#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_link_positions() validates list_positions", {
  data_positions <-
    tibble::tibble(coord_long = 1, coord_lat = 2, age = 0)

  testthat::expect_error(
    prepare_link_positions(list_positions = data_positions),
    regexp = "list_positions"
  )

  testthat::expect_error(
    prepare_link_positions(list_positions = list()),
    regexp = "list_positions"
  )

  testthat::expect_error(
    prepare_link_positions(list_positions = list(a = 1)),
    regexp = "list_positions"
  )

  testthat::expect_error(
    prepare_link_positions(list_positions = list(data_positions)),
    regexp = "named"
  )

  testthat::expect_error(
    prepare_link_positions(
      list_positions = rlang::set_names(
        list(data_positions, data_positions),
        c("a", "")
      )
    ),
    regexp = "named"
  )

  testthat::expect_error(
    prepare_link_positions(
      list_positions = list(a = data_positions, a = data_positions)
    ),
    regexp = "named"
  )

  testthat::expect_error(
    prepare_link_positions(
      list_positions = list(a = dplyr::select(data_positions, -age))
    ),
    regexp = "numeric columns"
  )

  testthat::expect_error(
    prepare_link_positions(
      list_positions = list(a = dplyr::mutate(data_positions, age = "0"))
    ),
    regexp = "numeric columns"
  )
})

testthat::test_that("prepare_link_positions() validates verbose", {
  list_positions <-
    list(a = tibble::tibble(coord_long = 1, coord_lat = 2, age = 0))

  purrr::walk(
    .x = list("yes", NA, c(TRUE, FALSE)),
    .f = ~ testthat::expect_error(
      prepare_link_positions(
        list_positions = list_positions,
        verbose = .x
      ),
      regexp = "verbose"
    )
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_link_positions() returns numbered positions", {
  res <-
    prepare_link_positions(
      list_positions = list(
        a = tibble::tibble(coord_long = 1L, coord_lat = 2L, age = 0L)
      ),
      verbose = FALSE
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(
    res,
    c("position_id", "coord_long", "coord_lat", "age")
  )
  testthat::expect_type(dplyr::pull(res, position_id), "integer")
  testthat::expect_type(dplyr::pull(res, coord_long), "double")
  testthat::expect_type(dplyr::pull(res, coord_lat), "double")
  testthat::expect_type(dplyr::pull(res, age), "double")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_link_positions() merges and sorts sources", {
  list_positions <-
    list(
      splot_plots = tibble::tibble(
        coord_long = c(14.25, -120.5, 14.25),
        coord_lat = c(50.1, 45, 50.1),
        age = c(0, 0, 0)
      ),
      fossilpol_assembly = tibble::tibble(
        coord_long = c(14.25, 14.25, -179.94),
        coord_lat = c(50.1, 50.1, -54.87),
        age = c(0, -73, 19997)
      )
    )

  res <-
    prepare_link_positions(
      list_positions = list_positions,
      verbose = FALSE
    )

  data_expected <-
    tibble::tibble(
      position_id = base::seq_len(4L),
      coord_long = c(-179.94, -120.5, 14.25, 14.25),
      coord_lat = c(-54.87, 45, 50.1, 50.1),
      age = c(19997, 0, -73, 0)
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_link_positions() ignores source and row order", {
  set.seed(900723)

  data_source_a <-
    tibble::tibble(
      coord_long = stats::runif(n = 50L, min = -180, max = 180),
      coord_lat = stats::runif(n = 50L, min = -90, max = 90),
      age = base::sample(
        x = c(-73, 0, 500.5, 8000),
        size = 50L,
        replace = TRUE
      )
    )

  data_source_b <-
    tibble::tibble(
      coord_long = stats::runif(n = 30L, min = -180, max = 180),
      coord_lat = stats::runif(n = 30L, min = -90, max = 90),
      age = 0
    )

  res_forward <-
    prepare_link_positions(
      list_positions = list(a = data_source_a, b = data_source_b),
      verbose = FALSE
    )

  res_reversed <-
    prepare_link_positions(
      list_positions = list(
        b = data_source_b[base::rev(base::seq_len(30L)), ],
        a = data_source_a[base::sample(base::seq_len(50L)), ]
      ),
      verbose = FALSE
    )

  testthat::expect_identical(res_forward, res_reversed)
  testthat::expect_equal(base::nrow(res_forward), 80L)
})

testthat::test_that("prepare_link_positions() drops rows with missing values", {
  list_positions <-
    list(
      splot_plots = tibble::tibble(
        coord_long = c(1, NA, 3),
        coord_lat = c(2, 2, NA),
        age = c(0, 0, 0)
      ),
      fossilpol_assembly = tibble::tibble(
        coord_long = c(1, 5),
        coord_lat = c(2, 6),
        age = c(NA, NaN)
      )
    )

  res <-
    prepare_link_positions(
      list_positions = list_positions,
      verbose = FALSE
    )

  data_expected <-
    tibble::tibble(
      position_id = 1L,
      coord_long = 1,
      coord_lat = 2,
      age = 0
    )

  testthat::expect_equal(res, data_expected)
})


#----------------------------------------------------------#
# Messages -----
#----------------------------------------------------------#

testthat::test_that("prepare_link_positions() reports dropped rows", {
  list_positions <-
    list(
      splot_plots = tibble::tibble(
        coord_long = c(1, NA, 3),
        coord_lat = c(2, 2, NA),
        age = c(0, 0, 0)
      ),
      bien_plots = tibble::tibble(coord_long = 1, coord_lat = 2, age = 0)
    )

  testthat::expect_message(
    prepare_link_positions(list_positions = list_positions),
    regexp = "splot_plots"
  )

  testthat::expect_no_message(
    prepare_link_positions(
      list_positions = list_positions,
      verbose = FALSE
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_link_positions() refuses impossible positions", {
  data_valid <-
    tibble::tibble(coord_long = 14, coord_lat = 50, age = 0)

  list_bad_rows <-
    list(
      tibble::tibble(coord_long = 181, coord_lat = 50, age = 0),
      tibble::tibble(coord_long = -Inf, coord_lat = 50, age = 0),
      tibble::tibble(coord_long = 14, coord_lat = 90.5, age = 0),
      tibble::tibble(coord_long = 14, coord_lat = 50, age = Inf)
    )

  purrr::walk(
    .x = list_bad_rows,
    .f = ~ testthat::expect_error(
      prepare_link_positions(
        list_positions = list(
          bien_plots = data_valid,
          splot_plots = dplyr::bind_rows(data_valid, .x)
        ),
        verbose = FALSE
      ),
      regexp = "splot_plots"
    )
  )
})

testthat::test_that("prepare_link_positions() keeps the range limits", {
  res <-
    prepare_link_positions(
      list_positions = list(
        a = tibble::tibble(
          coord_long = c(-180, 180),
          coord_lat = c(-90, 90),
          age = c(-73, 1e6)
        )
      ),
      verbose = FALSE
    )

  testthat::expect_equal(base::nrow(res), 2L)
})

testthat::test_that("prepare_link_positions() refuses an empty result", {
  testthat::expect_error(
    prepare_link_positions(
      list_positions = list(
        a = tibble::tibble(coord_long = NA_real_, coord_lat = 2, age = 0)
      ),
      verbose = FALSE
    ),
    regexp = "No position"
  )
})

testthat::test_that("prepare_link_positions() handles many positions", {
  set.seed(900723)

  data_source <-
    tibble::tibble(
      coord_long = base::round(
        x = stats::runif(n = 10000L, min = -180, max = 180),
        digits = 1
      ),
      coord_lat = base::round(
        x = stats::runif(n = 10000L, min = -90, max = 90),
        digits = 1
      ),
      age = 0
    )

  res <-
    prepare_link_positions(
      list_positions = list(a = data_source),
      verbose = FALSE
    )

  testthat::expect_equal(
    base::nrow(res),
    base::nrow(dplyr::distinct(data_source))
  )
  testthat::expect_equal(
    dplyr::pull(res, position_id),
    base::seq_len(base::nrow(res))
  )
})
