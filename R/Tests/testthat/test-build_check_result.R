#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_check_result() returns the report format", {
  res <-
    build_check_result(
      check_id = "foreign_keys",
      scope = c("Samples -> Datasets", "SamplePosition -> Positions"),
      status = "fail",
      observed = c(3L, 1L),
      threshold = 0L,
      message = "Rows without a parent row."
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_true(
    base::all(purrr::map_lgl(.x = res, .f = base::is.character))
  )

  testthat::expect_equal(base::nrow(res), 2L)

  testthat::expect_equal(dplyr::pull(res, observed), c("3", "1"))

  testthat::expect_equal(dplyr::pull(res, threshold), c("0", "0"))

  testthat::expect_equal(dplyr::pull(res, check_id), c(
    "foreign_keys", "foreign_keys"
  ))
})

testthat::test_that("build_check_result() keeps missing values missing", {
  res <-
    build_check_result(
      check_id = "schema",
      scope = "database",
      status = "pass",
      message = "The database matches the schema file."
    )

  testthat::expect_equal(base::nrow(res), 1L)

  testthat::expect_true(base::is.na(dplyr::pull(res, observed)))

  testthat::expect_true(base::is.na(dplyr::pull(res, threshold)))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_check_result() checks its arguments", {
  testthat::expect_error(
    build_check_result(
      check_id = "schema",
      scope = "database",
      status = "warning",
      message = "x"
    ),
    regexp = "status"
  )

  testthat::expect_error(
    build_check_result(
      check_id = "",
      scope = "database",
      status = "pass",
      message = "x"
    ),
    regexp = "check_id"
  )

  testthat::expect_error(
    build_check_result(
      check_id = c("a", "b"),
      scope = "database",
      status = "pass",
      message = "x"
    ),
    regexp = "check_id"
  )

  testthat::expect_error(
    build_check_result(
      check_id = "schema",
      scope = c("a", "b", "c"),
      status = c("pass", "fail"),
      message = "x"
    )
  )
})
