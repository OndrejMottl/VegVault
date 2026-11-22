#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_position_tables() validates arguments", {
  list_source_tables <-
    build_test_database_sources() |>
    purrr::chuck("list_source_tables")

  list_inputs <-
    build_test_position_inputs(list_source_tables = list_source_tables)

  testthat::expect_error(
    prepare_position_tables(
      list_source_tables = list_source_tables,
      data_positions = dplyr::select(
        purrr::chuck(list_inputs, "data_positions"),
        -age
      ),
      data_position_links = purrr::chuck(list_inputs, "data_position_links"),
      data_gridpoints = purrr::chuck(list_inputs, "data_gridpoints"),
      verbose = FALSE
    ),
    regexp = "data_positions"
  )

  testthat::expect_error(
    prepare_position_tables(
      list_source_tables = list_source_tables,
      data_positions = purrr::chuck(list_inputs, "data_positions"),
      data_position_links = purrr::chuck(list_inputs, "data_position_links"),
      data_gridpoints = dplyr::select(
        purrr::chuck(list_inputs, "data_gridpoints"),
        -sample_name
      ),
      verbose = FALSE
    ),
    regexp = "data_gridpoints"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_position_tables() keeps the used positions", {
  list_source_tables <-
    build_test_database_sources() |>
    purrr::chuck("list_source_tables")

  list_inputs <-
    build_test_position_inputs(list_source_tables = list_source_tables)

  res <-
    prepare_position_tables(
      list_source_tables = list_source_tables,
      data_positions = purrr::chuck(list_inputs, "data_positions"),
      data_position_links = purrr::chuck(list_inputs, "data_position_links"),
      data_gridpoints = purrr::chuck(list_inputs, "data_gridpoints"),
      verbose = FALSE
    )

  testthat::expect_named(
    res,
    c("sample_positions", "positions", "position_links", "gridpoints")
  )
  testthat::expect_named(
    purrr::chuck(res, "sample_positions"),
    c("sample_name", "position_id")
  )

  # The unused position, its link and the gridpoint only it reaches go
  testthat::expect_false(
    123 %in% dplyr::pull(purrr::chuck(res, "positions"), age)
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "gridpoints"), gridpoint_id),
    c(1L, 2L)
  )
  testthat::expect_false(
    3L %in% dplyr::pull(purrr::chuck(res, "position_links"), gridpoint_id)
  )

  # Every position kept is used, and position ids are those of the input
  testthat::expect_setequal(
    dplyr::pull(purrr::chuck(res, "positions"), position_id),
    base::unique(
      dplyr::pull(purrr::chuck(res, "sample_positions"), position_id)
    )
  )

  # One row per sample whose dataset has both coordinates
  n_samples_placed <-
    list_source_tables |>
    purrr::map_int(
      .f = ~ purrr::chuck(.x, "datasets") |>
        dplyr::filter(
          !base::is.na(coord_long),
          !base::is.na(coord_lat)
        ) |>
        dplyr::inner_join(
          purrr::chuck(.x, "dataset_samples"),
          by = dplyr::join_by(dataset_name)
        ) |>
        base::nrow()
    ) |>
    base::sum()

  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "sample_positions")),
    n_samples_placed
  )
})

testthat::test_that("prepare_position_tables() skips samples without place", {
  list_source_tables <-
    build_test_database_sources() |>
    purrr::chuck("list_source_tables")

  list_inputs <-
    build_test_position_inputs(list_source_tables = list_source_tables)

  # The first TRY dataset loses its coordinates
  list_without_coordinates <-
    purrr::modify_in(
      list_source_tables,
      .where = c("try", "datasets"),
      .f = ~ dplyr::mutate(
        .x,
        coord_long = dplyr::if_else(
          dplyr::row_number() == 1L,
          NA_real_,
          coord_long
        )
      )
    )

  testthat::expect_message(
    res <-
      prepare_position_tables(
        list_source_tables = list_without_coordinates,
        data_positions = purrr::chuck(list_inputs, "data_positions"),
        data_position_links = purrr::chuck(
          list_inputs,
          "data_position_links"
        ),
        data_gridpoints = purrr::chuck(list_inputs, "data_gridpoints"),
        verbose = TRUE
      ),
    regexp = "coordinates"
  )

  vec_unplaced_samples <-
    purrr::chuck(list_source_tables, "try", "dataset_samples") |>
    dplyr::filter(dataset_name == "try_1") |>
    dplyr::pull(sample_name)

  testthat::expect_false(
    base::any(
      vec_unplaced_samples %in%
        dplyr::pull(purrr::chuck(res, "sample_positions"), sample_name)
    )
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_position_tables() refuses unplaced samples", {
  list_source_tables <-
    build_test_database_sources() |>
    purrr::chuck("list_source_tables")

  list_inputs <-
    build_test_position_inputs(list_source_tables = list_source_tables)

  testthat::expect_error(
    prepare_position_tables(
      list_source_tables = list_source_tables,
      data_positions = dplyr::slice(
        purrr::chuck(list_inputs, "data_positions"),
        -1L
      ),
      data_position_links = purrr::chuck(list_inputs, "data_position_links"),
      data_gridpoints = purrr::chuck(list_inputs, "data_gridpoints"),
      verbose = FALSE
    ),
    regexp = "no position"
  )
})
