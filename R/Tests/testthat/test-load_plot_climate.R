#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_plot_climate() returns taxa and climate rows", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_plot_climate(
      path_database = path_database,
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      abiotic_variable_name = "bio1",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  data_plots <-
    res |>
    dplyr::filter(dataset_type == "vegetation_plot") |>
    dplyr::arrange(sample_id, taxon_id)

  testthat::expect_equal(dplyr::pull(data_plots, sample_id), c(1L, 1L, 2L))

  testthat::expect_equal(dplyr::pull(data_plots, taxon_id), c(1L, 4L, 4L))

  data_gridpoints <-
    res |>
    dplyr::filter(dataset_type == "gridpoints") |>
    dplyr::arrange(sample_id)

  testthat::expect_equal(
    dplyr::pull(data_gridpoints, sample_id_link),
    c(1L, 2L)
  )

  testthat::expect_equal(
    dplyr::pull(data_gridpoints, abiotic_value),
    c(8.5, 9)
  )

  base::unlink(path_database)

  testthat::expect_false(base::file.exists(path_database))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_plot_climate() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_region <-
    list(lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1)

  testthat::expect_error(
    load_plot_climate(
      path_database = path_database,
      list_region = list_region,
      abiotic_variable_name = 1,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "abiotic_variable_name"
  )

  testthat::expect_error(
    load_plot_climate(
      path_database = path_database,
      list_region = list_region,
      abiotic_variable_name = "bio1",
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
