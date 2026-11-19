#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_country_border() returns the country outline", {
  # skip_if_offline() also skips when NOT_CRAN is unset, as in the project
  #   test runner; only the connection should decide here
  withr::local_envvar(.new = c(NOT_CRAN = "true"))

  testthat::skip_if_offline(host = "geodata.ucdavis.edu")

  dir_cache <-
    withr::local_tempdir()

  res <-
    load_country_border(country_code = "CZE", dir_cache = dir_cache)

  testthat::expect_s3_class(res, "sf")

  testthat::expect_equal(base::nrow(res), 1L)

  # The download stays in the cache folder for the next call
  testthat::expect_gt(
    base::length(base::list.files(dir_cache, recursive = TRUE)),
    0L
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_country_border() validates its arguments", {
  dir_cache <-
    withr::local_tempdir()

  testthat::expect_error(
    load_country_border(country_code = "Czechia", dir_cache = dir_cache),
    regexp = "country_code"
  )

  testthat::expect_error(
    load_country_border(country_code = c("CZE", "SVK"), dir_cache = dir_cache),
    regexp = "country_code"
  )

  testthat::expect_error(
    load_country_border(
      country_code = "CZE",
      dir_cache = base::file.path(dir_cache, "missing")
    ),
    regexp = "dir_cache"
  )
})
