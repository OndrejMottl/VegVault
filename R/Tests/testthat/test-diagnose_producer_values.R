#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_values() passes valid values", {
  res <-
    diagnose_producer_values(
      vec_values = c(-10.5, 0, 35),
      list_checks = base::list(
        range = base::list(min = -90, max = 60),
        finite = TRUE,
        forbidden_values = c(6553.5)
      ),
      nullable = FALSE,
      contract_id = "test_climate",
      column = "value",
      file_name = "bio01.qs"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(
    res,
    c(
      "contract_id", "file_name", "column", "check", "n_violations",
      "message"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_values() counts missing values", {
  res <-
    diagnose_producer_values(
      vec_values = c(1, NA, NaN, 4),
      list_checks = NULL,
      nullable = FALSE,
      contract_id = "test_fossilpol",
      column = "levels[].age",
      file_name = "a.qs"
    )

  testthat::expect_equal(dplyr::pull(res, check), "value_missing")

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)

  testthat::expect_equal(dplyr::pull(res, column), "levels[].age")

  testthat::expect_equal(dplyr::pull(res, file_name), "a.qs")

  res_nullable <-
    diagnose_producer_values(
      vec_values = c(1, NA),
      list_checks = NULL,
      nullable = TRUE,
      contract_id = "test_fossilpol",
      column = "levels[].age"
    )

  testthat::expect_equal(base::nrow(res_nullable), 0L)
})

testthat::test_that("diagnose_producer_values() checks ranges and finiteness", {
  res <-
    diagnose_producer_values(
      vec_values = c(-200, 0, 10, 200, Inf, NA),
      list_checks = base::list(
        range = base::list(min = -180, max = 180),
        finite = TRUE
      ),
      nullable = TRUE,
      contract_id = "c",
      column = "long"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("value_out_of_range", "value_not_finite")
  )

  testthat::expect_equal(
    res |>
      dplyr::filter(check == "value_out_of_range") |>
      dplyr::pull(n_violations),
    3L
  )

  res_exclusive <-
    diagnose_producer_values(
      vec_values = c(0, 5),
      list_checks = base::list(
        range = base::list(min = 0, min_inclusive = FALSE)
      ),
      nullable = FALSE,
      contract_id = "c",
      column = "value"
    )

  testthat::expect_equal(
    dplyr::pull(res_exclusive, check),
    "value_out_of_range"
  )

  testthat::expect_equal(dplyr::pull(res_exclusive, n_violations), 1L)
})

testthat::test_that("diagnose_producer_values() finds type-limit values", {
  res <-
    diagnose_producer_values(
      vec_values = c(100, 65535 * 0.1, 6553.5, 6553.4),
      list_checks = base::list(forbidden_values = c(6553.5)),
      nullable = FALSE,
      contract_id = "c",
      column = "value"
    )

  testthat::expect_equal(dplyr::pull(res, check), "value_forbidden")

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)

  testthat::expect_match(dplyr::pull(res, message), "6553.5")
})

testthat::test_that("diagnose_producer_values() checks whole numbers", {
  res <-
    diagnose_producer_values(
      vec_values = c(1, 2.5, 3),
      list_checks = base::list(whole_number = TRUE),
      nullable = FALSE,
      contract_id = "c",
      column = "id"
    )

  testthat::expect_equal(dplyr::pull(res, check), "value_not_whole")

  testthat::expect_equal(dplyr::pull(res, n_violations), 1L)
})

testthat::test_that("diagnose_producer_values() checks allowed text", {
  res <-
    diagnose_producer_values(
      vec_values = c("published", "quarantined", "published"),
      list_checks = base::list(allowed_values = "published"),
      nullable = FALSE,
      contract_id = "test_traits",
      column = "disposition"
    )

  testthat::expect_equal(dplyr::pull(res, check), "value_not_allowed")

  testthat::expect_equal(dplyr::pull(res, n_violations), 1L)

  testthat::expect_match(dplyr::pull(res, message), "quarantined")
})

testthat::test_that("diagnose_producer_values() checks patterns and empty", {
  res <-
    diagnose_producer_values(
      vec_values = base::factor(c("bio1", "", "temp")),
      list_checks = base::list(pattern = "^bio[0-9]+$", not_empty = TRUE),
      nullable = FALSE,
      contract_id = "c",
      column = "var_name"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("value_pattern", "value_empty")
  )

  testthat::expect_equal(
    res |>
      dplyr::filter(check == "value_pattern") |>
      dplyr::pull(n_violations),
    2L
  )
})

testthat::test_that("diagnose_producer_values() skips checks of other types", {
  res <-
    diagnose_producer_values(
      vec_values = c("a", "b"),
      list_checks = base::list(
        range = base::list(min = 0),
        finite = TRUE,
        whole_number = TRUE
      ),
      nullable = FALSE,
      contract_id = "c",
      column = "x"
    )

  testthat::expect_equal(base::nrow(res), 0L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_values() validates arguments", {
  testthat::expect_error(
    diagnose_producer_values(
      vec_values = base::list(1, 2),
      list_checks = NULL,
      nullable = FALSE,
      contract_id = "c",
      column = "x"
    ),
    regexp = "vec_values"
  )

  testthat::expect_error(
    diagnose_producer_values(
      vec_values = 1,
      list_checks = NULL,
      nullable = NA,
      contract_id = "c",
      column = "x"
    ),
    regexp = "nullable"
  )
})
