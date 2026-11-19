#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_findings() returns documented columns", {
  res <-
    build_producer_findings(
      contract_id = "splot_plots",
      check = "column_missing",
      message = "Column is missing."
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c(
      "contract_id", "file_name", "column", "check", "n_violations",
      "message"
    )
  )

  testthat::expect_equal(base::nrow(res), 1L)

  testthat::expect_type(dplyr::pull(res, n_violations), "integer")

  testthat::expect_type(dplyr::pull(res, file_name), "character")

  testthat::expect_true(base::is.na(dplyr::pull(res, column)))
})

testthat::test_that("build_producer_findings() recycles scalar arguments", {
  res <-
    build_producer_findings(
      contract_id = "bien_plots",
      check = c("column_missing", "class_mismatch"),
      message = c("first", "second"),
      file_name = "data_bien.qs",
      column = c("longitude", "latitude"),
      n_violations = 3L
    )

  testthat::expect_equal(base::nrow(res), 2L)

  testthat::expect_equal(
    dplyr::pull(res, column),
    c("longitude", "latitude")
  )

  testthat::expect_equal(
    dplyr::pull(res, file_name),
    c("data_bien.qs", "data_bien.qs")
  )

  testthat::expect_equal(dplyr::pull(res, n_violations), c(3L, 3L))

  testthat::expect_equal(
    dplyr::pull(res, contract_id),
    c("bien_plots", "bien_plots")
  )
})

testthat::test_that("build_producer_findings() returns zero rows when empty", {
  res <-
    build_producer_findings(
      contract_id = "splot_plots",
      check = base::character(0),
      message = base::character(0)
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(
    res,
    c(
      "contract_id", "file_name", "column", "check", "n_violations",
      "message"
    )
  )

  testthat::expect_type(dplyr::pull(res, n_violations), "integer")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_findings() rejects invalid arguments", {
  testthat::expect_error(
    build_producer_findings(
      contract_id = c("a", "b"),
      check = "column_missing",
      message = "x"
    ),
    regexp = "contract_id"
  )

  testthat::expect_error(
    build_producer_findings(
      contract_id = "a",
      check = c("column_missing", "class_mismatch"),
      message = "only one message"
    ),
    regexp = "message"
  )

  testthat::expect_error(
    build_producer_findings(
      contract_id = "a",
      check = 1,
      message = "x"
    ),
    regexp = "check"
  )

  testthat::expect_error(
    build_producer_findings(
      contract_id = "a",
      check = c("x", "y", "z"),
      message = c("x", "y", "z"),
      column = c("a", "b")
    ),
    regexp = "column"
  )
})
