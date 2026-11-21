#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("select_contract_column() returns the column", {
  contract <-
    load_producer_contract(
      path_contract = here::here("Data", "Contracts", "hwsd_soil.yml")
    )

  res <-
    select_contract_column(contract = contract, column = "value")

  testthat::expect_type(res, "list")

  testthat::expect_equal(purrr::chuck(res, "name"), "value")

  testthat::expect_equal(purrr::chuck(res, "unit"), "Unitless")

  testthat::expect_true(purrr::chuck(res, "checks", "whole_number"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("select_contract_column() gives empty checks", {
  contract <-
    base::list(
      contract_id = "example",
      columns = base::list(base::list(name = "id", class = "integer"))
    )

  res <-
    select_contract_column(contract = contract, column = "id")

  testthat::expect_equal(purrr::chuck(res, "checks"), base::list())
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("select_contract_column() needs exactly one column", {
  contract <-
    base::list(
      contract_id = "example",
      columns = base::list(
        base::list(name = "id"),
        base::list(name = "id")
      )
    )

  testthat::expect_error(
    select_contract_column(contract = contract, column = "id"),
    regexp = "not 2"
  )

  testthat::expect_error(
    select_contract_column(contract = contract, column = "name"),
    regexp = "not 0"
  )
})
