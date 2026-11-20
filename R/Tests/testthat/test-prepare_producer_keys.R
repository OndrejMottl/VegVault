#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_producer_keys() lists the distinct keys", {
  list_data <-
    list(
      a.qs = tibble::tibble(dataset_id = c("3", "1", NA, "3")),
      b.qs = tibble::tibble(dataset_id = "2", other = 1)
    )

  res <-
    prepare_producer_keys(list_data = list_data, col_key = "dataset_id")

  testthat::expect_equal(res, c("1", "2", "3"))
})

testthat::test_that("prepare_producer_keys() keeps the column type", {
  res <-
    prepare_producer_keys(
      list_data = list(a.qs = tibble::tibble(id = c(10, 2))),
      col_key = "id"
    )

  testthat::expect_equal(res, c(2, 10))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_producer_keys() validates its input", {
  testthat::expect_error(
    prepare_producer_keys(list_data = list(), col_key = "dataset_id"),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_producer_keys(
      list_data = list(a.qs = tibble::tibble(id = 1)),
      col_key = "dataset_id"
    ),
    regexp = "dataset_id"
  )

  testthat::expect_error(
    prepare_producer_keys(
      list_data = list(a.qs = tibble::tibble(id = 1)),
      col_key = c("id", "id")
    ),
    regexp = "col_key"
  )
})
