#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_id_text() validates arguments", {
  testthat::expect_error(
    prepare_id_text(vec_ids = base::list(1, 2), name_column = "id"),
    regexp = "vec_ids"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = c(TRUE, FALSE), name_column = "id"),
    regexp = "vec_ids"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = 1, name_column = c("a", "b")),
    regexp = "name_column"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_id_text() keeps text ids as they are", {
  res <-
    prepare_id_text(vec_ids = c("bt0001", "90001_1"), name_column = "id")

  testthat::expect_type(res, "character")
  testthat::expect_equal(res, c("bt0001", "90001_1"))
})

testthat::test_that("prepare_id_text() writes numbers in full", {
  testthat::expect_equal(
    prepare_id_text(
      vec_ids = c(300000, 18000000, 101, -3),
      name_column = "id"
    ),
    c("300000", "18000000", "101", "-3")
  )

  testthat::expect_equal(
    prepare_id_text(vec_ids = c(5L, 100000L), name_column = "id"),
    c("5", "100000")
  )

  testthat::expect_equal(
    prepare_id_text(vec_ids = base::numeric(0), name_column = "id"),
    base::character(0)
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_id_text() refuses missing or partial ids", {
  testthat::expect_error(
    prepare_id_text(vec_ids = c("a", NA), name_column = "plot_id"),
    regexp = "plot_id"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = c("a", ""), name_column = "plot_id"),
    regexp = "plot_id"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = c(1, NA), name_column = "plot_id"),
    regexp = "plot_id"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = c(1, 1.5), name_column = "plot_id"),
    regexp = "whole"
  )

  testthat::expect_error(
    prepare_id_text(vec_ids = c(1, Inf), name_column = "plot_id"),
    regexp = "whole"
  )
})
