#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_sample_ages() returns distinct rows", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = c("vegetation_plot", "fossil_pollen_archive"),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_id = c(1L, 2L, 6L, 7L, 7L, 8L, 8L),
      dataset_type = c(
        base::rep("vegetation_plot", 3L),
        base::rep("fossil_pollen_archive", 4L)
      ),
      coord_long = c(14, 16, -100, -90, -90, -70, -70),
      coord_lat = c(50, 49.5, 45, 50, 50, -20, -20),
      age = c(0, 0, 0, 1000, 6000, 7000, 11000)
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_sample_ages() keeps only given types", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = "gridpoints",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, dataset_id), c(3L, 4L, 5L))

  testthat::expect_equal(
    base::unique(dplyr::pull(res, dataset_type)),
    "gridpoints"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_sample_ages() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_manifest <-
    list(database = list(file_name = "f.sqlite"))

  testthat::expect_error(
    load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = character(0),
      list_build_manifest = list_manifest
    ),
    regexp = "vec_dataset_types"
  )

  testthat::expect_error(
    load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = 1,
      list_build_manifest = list_manifest
    ),
    regexp = "vec_dataset_types"
  )

  testthat::expect_error(
    load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = "gridpoints",
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
