#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_chelsa_trace21k_ages() converts time slices", {
  list_data <-
    list(
      a.qs = tibble::tibble(time_id = c("20", "-160", "15")),
      b.qs = tibble::tibble(time_id = c("20", NA_character_))
    )

  res <-
    prepare_chelsa_trace21k_ages(list_data = list_data)

  # -time_id * 100 + 2000
  testthat::expect_equal(res, c(0, 500, 18000))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_chelsa_trace21k_ages() needs numeric slices", {
  testthat::expect_no_warning(
    testthat::expect_error(
      prepare_chelsa_trace21k_ages(
        list_data = list(a.qs = tibble::tibble(time_id = c("20", "abc")))
      ),
      regexp = "abc"
    )
  )

  testthat::expect_error(
    prepare_chelsa_trace21k_ages(
      list_data = list(a.qs = tibble::tibble(time = "20"))
    ),
    regexp = "time_id"
  )
})

testthat::test_that("prepare_chelsa_trace21k_ages() needs a table", {
  testthat::expect_error(
    prepare_chelsa_trace21k_ages(list_data = list()),
    regexp = "list_data"
  )
})
