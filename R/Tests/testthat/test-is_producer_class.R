#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("is_producer_class() recognises atomic classes", {
  testthat::expect_true(is_producer_class(x = "a", class_name = "character"))

  testthat::expect_true(is_producer_class(x = 1.5, class_name = "numeric"))

  testthat::expect_true(is_producer_class(x = 1L, class_name = "numeric"))

  testthat::expect_true(is_producer_class(x = 1.5, class_name = "double"))

  testthat::expect_true(is_producer_class(x = 1L, class_name = "integer"))

  testthat::expect_true(is_producer_class(x = TRUE, class_name = "logical"))

  testthat::expect_true(
    is_producer_class(
      x = base::as.Date("2024-01-01"),
      class_name = "Date"
    )
  )

  testthat::expect_true(
    is_producer_class(
      x = base::factor("a"),
      class_name = "factor"
    )
  )
})

testthat::test_that("is_producer_class() keeps numeric and other apart", {
  testthat::expect_false(is_producer_class(x = "1", class_name = "numeric"))

  testthat::expect_false(
    is_producer_class(
      x = base::factor("1"),
      class_name = "numeric"
    )
  )

  testthat::expect_false(
    is_producer_class(
      x = base::as.Date("2024-01-01"),
      class_name = "numeric"
    )
  )

  testthat::expect_false(
    is_producer_class(
      x = base::as.Date("2024-01-01"),
      class_name = "double"
    )
  )

  testthat::expect_false(is_producer_class(x = 1.5, class_name = "integer"))

  testthat::expect_false(is_producer_class(x = 1L, class_name = "double"))

  testthat::expect_false(
    is_producer_class(
      x = base::factor("a"),
      class_name = "character"
    )
  )
})

testthat::test_that("is_producer_class() recognises containers", {
  testthat::expect_true(
    is_producer_class(
      x = base::list(1, 2),
      class_name = "list"
    )
  )

  testthat::expect_false(
    is_producer_class(
      x = base::data.frame(a = 1),
      class_name = "list"
    )
  )

  testthat::expect_true(
    is_producer_class(
      x = tibble::tibble(a = 1),
      class_name = "data.frame"
    )
  )

  testthat::expect_true(
    is_producer_class(
      x = base::matrix(1:4, nrow = 2),
      class_name = "matrix"
    )
  )

  testthat::expect_false(
    is_producer_class(
      x = base::data.frame(a = 1),
      class_name = "matrix"
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("is_producer_class() rejects an unknown class name", {
  testthat::expect_error(
    is_producer_class(x = 1, class_name = "numerik"),
    regexp = "numerik"
  )

  testthat::expect_error(
    is_producer_class(x = 1, class_name = c("numeric", "double"))
  )
})
