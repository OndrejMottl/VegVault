#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_tables() validates arguments", {
  data_gridpoints <-
    build_test_position_inputs(
      list_source_tables = base::list()
    ) |>
    purrr::chuck("data_gridpoints")

  testthat::expect_error(
    prepare_gridpoint_tables(
      data_gridpoints = dplyr::select(data_gridpoints, -dataset_name),
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "dataset_name"
  )

  testthat::expect_error(
    prepare_gridpoint_tables(
      data_gridpoints = data_gridpoints,
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "data_source_desc"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_tables() makes cells and samples", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints")

  list_source <-
    base::list(
      dataset_type = "gridpoints",
      dataset_source_type = "gridpoints",
      data_source_desc = "gridpoints",
      references = purrr::map(
        .x = c("source_type", "data_source", "dataset", "sample"),
        .f = ~ base::list(
          role = .x,
          mandatory = TRUE,
          detail = "gridpoint reference"
        )
      )
    )

  res <-
    prepare_gridpoint_tables(
      data_gridpoints = data_gridpoints,
      list_source = list_source,
      verbose = FALSE
    )

  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    purrr::map(.x = build_source_table_template(), .f = base::names)
  )

  data_datasets <-
    purrr::chuck(res, "datasets")

  testthat::expect_equal(
    dplyr::pull(data_datasets, dataset_name),
    c("geo_0.5_0.5", "geo_10_50")
  )
  testthat::expect_equal(dplyr::pull(data_datasets, coord_long), c(0.5, 10))
  testthat::expect_equal(
    base::unique(dplyr::pull(data_datasets, data_source_desc)),
    "gridpoints"
  )

  testthat::expect_equal(
    base::sort(dplyr::pull(purrr::chuck(res, "samples"), sample_name)),
    base::sort(dplyr::pull(data_gridpoints, sample_name))
  )
  testthat::expect_true(
    base::all(
      base::is.na(dplyr::pull(purrr::chuck(res, "samples"), sample_size))
    )
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "dataset_samples")),
    3L
  )

  # Every dataset and every sample has the gridpoint reference
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "dataset_references")),
    2L
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "sample_references")),
    3L
  )
  testthat::expect_true(
    base::all(
      dplyr::pull(purrr::chuck(res, "sample_references"), mandatory)
    )
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "data_source_references")),
    1L
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_tables() refuses moving cells", {
  data_gridpoints <-
    build_test_position_inputs(list_source_tables = base::list()) |>
    purrr::chuck("data_gridpoints") |>
    dplyr::mutate(
      coord_lat = dplyr::if_else(gridpoint_id == 2L, 51, coord_lat)
    )

  testthat::expect_error(
    prepare_gridpoint_tables(
      data_gridpoints = data_gridpoints,
      list_source = base::list(
        dataset_type = "gridpoints",
        dataset_source_type = "gridpoints",
        data_source_desc = "gridpoints",
        references = base::list()
      ),
      verbose = FALSE
    ),
    regexp = "geo_10_50"
  )
})
