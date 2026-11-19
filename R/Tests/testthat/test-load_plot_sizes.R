#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_plot_sizes() returns vegetation plot sizes", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_plot_sizes(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      sample_id = c(1L, 2L, 6L),
      sample_size = c(100, 400, 100),
      sample_size_unit = base::rep("square meters", 3L)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_plot_sizes() refuses another database", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_plot_sizes(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
