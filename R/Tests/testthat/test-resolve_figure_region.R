#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_figure_region() keeps the configured region", {
  res <-
    resolve_figure_region(
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_subset = list(enabled = FALSE)
    )

  testthat::expect_equal(
    res,
    list(lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("resolve_figure_region() uses an enabled subset box", {
  res <-
    resolve_figure_region(
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_subset = list(
        enabled = TRUE,
        box_name = "alaska_yukon",
        lon_min = -170,
        lon_max = -125,
        lat_min = 54,
        lat_max = 72,
        margin_lat = 0.5
      )
    )

  testthat::expect_equal(
    res,
    list(lon_min = -170, lon_max = -125, lat_min = 54, lat_max = 72)
  )
})

testthat::test_that("resolve_figure_region() drops other elements", {
  res <-
    resolve_figure_region(
      list_region = list(
        lat_max = 51.1, name = "Czechia", lon_min = 12, lon_max = 18.9,
        lat_min = 48.5
      ),
      list_subset = list(enabled = FALSE)
    )

  testthat::expect_named(res, c("lon_min", "lon_max", "lat_min", "lat_max"))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_figure_region() validates both boxes", {
  testthat::expect_error(
    resolve_figure_region(
      list_region = list(lon_min = 12, lon_max = 18.9, lat_min = 48.5),
      list_subset = list(enabled = FALSE)
    ),
    regexp = "lat_max"
  )

  testthat::expect_error(
    resolve_figure_region(
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_subset = list(enabled = TRUE, lon_min = -170)
    ),
    regexp = "lon_max"
  )

  testthat::expect_error(
    resolve_figure_region(
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_subset = "subset"
    ),
    regexp = "list_subset"
  )
})
