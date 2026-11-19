data_climate <-
  tibble::tibble(
    long = c(1, 1, 2, 2),
    lat = c(10, 10, 20, 20),
    time_id = c("0", "5", "0", "5"),
    value = c(1, 2, 3, 4)
  )

data_traits <-
  tibble::tibble(
    trait_full_name = c("Leaf area", "Leaf area", "Plant height"),
    trait_unit = c("mm2", "cm2", "m")
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_table_rules() passes unique keys", {
  res <-
    diagnose_producer_table_rules(
      data_source = data_climate,
      list_keys = base::list(c("long", "lat", "time_id")),
      list_dependencies = base::list(),
      contract_id = "test_climate",
      scope_label = "variable bio1"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_table_rules() counts duplicate rows", {
  res <-
    diagnose_producer_table_rules(
      data_source = data_climate,
      list_keys = base::list(c("long", "lat")),
      list_dependencies = base::list(),
      contract_id = "test_climate",
      scope_label = "variable bio1"
    )

  testthat::expect_equal(dplyr::pull(res, check), "key_duplicate")

  testthat::expect_equal(dplyr::pull(res, n_violations), 4L)

  testthat::expect_equal(dplyr::pull(res, column), "long+lat")

  testthat::expect_match(dplyr::pull(res, message), "variable bio1")

  testthat::expect_true(base::is.na(dplyr::pull(res, file_name)))
})

testthat::test_that("diagnose_producer_table_rules() treats NA keys as equal", {
  res <-
    diagnose_producer_table_rules(
      data_source = tibble::tibble(id = c(NA, NA, 1)),
      list_keys = base::list("id"),
      list_dependencies = base::list(),
      contract_id = "c"
    )

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)
})

testthat::test_that("diagnose_producer_table_rules() checks dependencies", {
  res <-
    diagnose_producer_table_rules(
      data_source = data_traits,
      list_keys = base::list(),
      list_dependencies = base::list(
        base::list(determinant = "trait_full_name", dependent = "trait_unit")
      ),
      contract_id = "test_traits"
    )

  testthat::expect_equal(dplyr::pull(res, check), "dependency_violation")

  testthat::expect_equal(dplyr::pull(res, n_violations), 1L)

  testthat::expect_equal(
    dplyr::pull(res, column),
    "trait_full_name+trait_unit"
  )
})

testthat::test_that("diagnose_producer_table_rules() skips absent columns", {
  res <-
    diagnose_producer_table_rules(
      data_source = data_climate,
      list_keys = base::list(c("long", "lat", "age")),
      list_dependencies = base::list(
        base::list(determinant = "trait", dependent = "unit")
      ),
      contract_id = "c"
    )

  testthat::expect_equal(base::nrow(res), 0L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_table_rules() validates arguments", {
  testthat::expect_error(
    diagnose_producer_table_rules(
      data_source = "x",
      list_keys = base::list(),
      list_dependencies = base::list(),
      contract_id = "c"
    ),
    regexp = "data_source"
  )

  testthat::expect_error(
    diagnose_producer_table_rules(
      data_source = data_climate,
      list_keys = "long",
      list_dependencies = base::list(),
      contract_id = "c"
    ),
    regexp = "list_keys"
  )
})


#----------------------------------------------------------#
# Rounded keys -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_table_rules() checks rounded keys", {
  data_close <-
    tibble::tibble(
      long = c(1.001, 1.002, 2),
      lat = c(10, 10, 20)
    )

  res <-
    diagnose_producer_table_rules(
      data_source = data_close,
      list_keys = base::list(c("long", "lat")),
      list_dependencies = base::list(),
      contract_id = "test_climate",
      list_rounded_keys = base::list(
        base::list(columns = c("long", "lat"), digits = 2L)
      )
    )

  testthat::expect_equal(dplyr::pull(res, check), "key_duplicate_rounded")

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)

  testthat::expect_equal(dplyr::pull(res, column), "long+lat")

  res_fine <-
    diagnose_producer_table_rules(
      data_source = data_close,
      list_keys = base::list(),
      list_dependencies = base::list(),
      contract_id = "test_climate",
      list_rounded_keys = base::list(
        base::list(columns = c("long", "lat"), digits = 3L)
      )
    )

  testthat::expect_equal(base::nrow(res_fine), 0L)
})
