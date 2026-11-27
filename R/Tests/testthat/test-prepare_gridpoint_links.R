#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_links() pairs plots and gridpoints", {
  data_raw <-
    tibble::tibble(
      dataset_type = c(
        "vegetation_plot", "vegetation_plot", "vegetation_plot",
        "vegetation_plot", "gridpoints", "gridpoints"
      ),
      sample_id = c(1L, 1L, 2L, 9L, 3L, 4L),
      sample_id_link = c(NA, NA, NA, NA, 1L, 2L),
      coord_long = c(14, 14, 16, 17, 14.1, 16.1),
      coord_lat = c(50, 50, 49.5, 49, 50.1, 49.6)
    )

  res <-
    prepare_gridpoint_links(data_gridpoint_links_raw = data_raw)

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      sample_id = c(1L, 2L, 9L),
      coord_long_plot = c(14, 16, 17),
      coord_lat_plot = c(50, 49.5, 49),
      coord_long_gridpoint = c(14.1, 16.1, NA),
      coord_lat_gridpoint = c(50.1, 49.6, NA)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_gridpoint_links() requires its columns", {
  testthat::expect_error(
    prepare_gridpoint_links(
      data_gridpoint_links_raw = tibble::tibble(
        dataset_type = "gridpoints",
        sample_id = 1L
      )
    ),
    regexp = "sample_id_link"
  )

  testthat::expect_error(
    prepare_gridpoint_links(data_gridpoint_links_raw = "data"),
    regexp = "data_gridpoint_links_raw"
  )
})
