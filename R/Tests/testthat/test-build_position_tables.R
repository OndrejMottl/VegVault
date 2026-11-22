#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_position_tables() validates arguments", {
  testthat::expect_error(
    build_position_tables(
      list_tables = base::list(Datasets = tibble::tibble()),
      list_positions = base::list()
    ),
    regexp = "Samples"
  )

  testthat::expect_error(
    build_position_tables(
      list_tables = base::list(
        Samples = tibble::tibble(sample_id = 1L, sample_name = "a")
      ),
      list_positions = base::list(positions = tibble::tibble())
    ),
    regexp = "list_positions"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("build_position_tables() links samples to gridpoints", {
  list_inputs <-
    build_test_database_sources()

  list_source_tables <-
    purrr::chuck(list_inputs, "list_source_tables")

  list_stage_inputs <-
    build_test_position_inputs(list_source_tables = list_source_tables)

  list_positions <-
    prepare_position_tables(
      list_source_tables = list_source_tables,
      data_positions = purrr::chuck(list_stage_inputs, "data_positions"),
      data_position_links = purrr::chuck(
        list_stage_inputs,
        "data_position_links"
      ),
      data_gridpoints = purrr::chuck(list_stage_inputs, "data_gridpoints"),
      verbose = FALSE
    )

  list_gridpoint_source <-
    prepare_gridpoint_tables(
      data_gridpoints = purrr::chuck(list_positions, "gridpoints"),
      list_source = base::list(
        dataset_type = "gridpoints",
        dataset_source_type = "gridpoints",
        data_source_desc = "gridpoints",
        references = base::list(
          base::list(role = "sample", mandatory = TRUE, detail = "grid")
        )
      ),
      verbose = FALSE
    )

  list_tables <-
    build_database_tables(
      list_source_tables = c(
        list_source_tables,
        base::list(gridpoints = list_gridpoint_source)
      ),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  res <-
    build_position_tables(
      list_tables = list_tables,
      list_positions = list_positions
    )

  testthat::expect_named(
    res,
    c("Positions", "SamplePosition", "PositionLink")
  )
  testthat::expect_named(
    purrr::chuck(res, "Positions"),
    c("position_id", "coord_long", "coord_lat", "age")
  )
  testthat::expect_named(
    purrr::chuck(res, "PositionLink"),
    c("position_id", "sample_ref_id", "distance_in_km", "distance_in_years")
  )

  data_positions <-
    purrr::chuck(res, "Positions")

  # Positions are numbered again from 1 in the order of their keys
  testthat::expect_equal(
    dplyr::pull(data_positions, position_id),
    base::seq_len(base::nrow(data_positions))
  )
  testthat::expect_identical(
    data_positions,
    dplyr::arrange(data_positions, coord_long, coord_lat, age)
  )

  vec_gridpoint_sample_ids <-
    purrr::chuck(list_tables, "Samples") |>
    dplyr::filter(stringr::str_starts(sample_name, "geo_")) |>
    dplyr::pull(sample_id)

  testthat::expect_true(
    base::all(
      dplyr::pull(purrr::chuck(res, "PositionLink"), sample_ref_id) %in%
        vec_gridpoint_sample_ids
    )
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "SamplePosition")),
    base::nrow(purrr::chuck(list_positions, "sample_positions"))
  )

  # The whole database loads, and the view returns one row per sample link
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  save_vegvault_database(
    path_database = path_database,
    list_tables = c(list_tables, res),
    list_pragmas_load = base::list(
      journal_mode = "MEMORY",
      foreign_keys = "OFF"
    ),
    list_pragmas_final = base::list(foreign_keys = "ON"),
    n_chunk_size = 1000L,
    verbose = FALSE
  )

  list_checks <-
    run_with_database(
      path_database = path_database,
      fn = ~ base::list(
        foreign_keys = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA foreign_key_check"
        ),
        n_view = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT COUNT(*) AS n FROM AbioticDataReference"
        )
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    base::nrow(purrr::chuck(list_checks, "foreign_keys")),
    0L
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(list_checks, "n_view"), n),
    base::nrow(purrr::chuck(res, "SamplePosition")) * 2L
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("build_position_tables() refuses unknown samples", {
  list_positions <-
    base::list(
      sample_positions = tibble::tibble(sample_name = "s1", position_id = 1L),
      positions = tibble::tibble(
        position_id = 1L,
        coord_long = 1,
        coord_lat = 1,
        age = 0
      ),
      position_links = tibble::tibble(
        position_id = 1L,
        gridpoint_id = 1L,
        distance_in_km = 1L,
        distance_in_years = 0L
      ),
      gridpoints = tibble::tibble(gridpoint_id = 1L, sample_name = "g1")
    )

  testthat::expect_error(
    build_position_tables(
      list_tables = base::list(
        Samples = tibble::tibble(sample_id = 1L, sample_name = "s1")
      ),
      list_positions = list_positions
    ),
    regexp = "PositionLink"
  )
})
