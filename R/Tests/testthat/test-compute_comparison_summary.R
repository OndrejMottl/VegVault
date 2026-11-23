#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_comparison_summary() validates arguments", {
  data_rows <-
    tibble::tibble(scope = "a", key = 1)

  testthat::expect_error(
    compute_comparison_summary(
      data_v1 = "rows",
      data_v2 = data_rows,
      sel_unit = "samples"
    ),
    regexp = "data_v1"
  )

  testthat::expect_error(
    compute_comparison_summary(
      data_v1 = tibble::tibble(key = 1),
      data_v2 = tibble::tibble(key = 1),
      sel_unit = "samples"
    ),
    regexp = "scope"
  )

  testthat::expect_error(
    compute_comparison_summary(
      data_v1 = data_rows,
      data_v2 = tibble::tibble(scope = "a", other = 1),
      sel_unit = "samples"
    ),
    regexp = "columns"
  )

  testthat::expect_error(
    compute_comparison_summary(
      data_v1 = data_rows,
      data_v2 = data_rows,
      sel_unit = c("a", "b")
    ),
    regexp = "sel_unit"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_comparison_summary() finds equal sides", {
  data_v1 <-
    tibble::tibble(
      scope = c("a", "a", "b"),
      name = c("x", "y", "z"),
      value = c(1, 2, 3)
    )

  # The same rows in another order and with the columns reordered
  data_v2 <-
    dplyr::slice(data_v1, c(3L, 1L, 2L)) |>
    dplyr::select(value, name, scope)

  res <-
    compute_comparison_summary(
      data_v1 = data_v1,
      data_v2 = data_v2,
      sel_unit = "samples"
    )

  testthat::expect_named(
    res,
    c(
      "unit", "scope", "n_v1", "n_v2", "n_both", "n_only_v1", "n_only_v2",
      "checksum_v1", "checksum_v2", "is_equal"
    )
  )

  testthat::expect_equal(dplyr::pull(res, scope), c("a", "b"))

  testthat::expect_equal(dplyr::pull(res, unit), c("samples", "samples"))

  testthat::expect_equal(dplyr::pull(res, n_both), c(2, 1))

  testthat::expect_true(base::all(dplyr::pull(res, is_equal)))

  testthat::expect_equal(
    dplyr::pull(res, checksum_v1),
    dplyr::pull(res, checksum_v2)
  )
})

testthat::test_that("compute_comparison_summary() counts the differences", {
  data_v1 <-
    tibble::tibble(
      scope = c("a", "a", "a", "b"),
      name = c("x", "x", "y", "z"),
      value = c(1, 1, 2, 3)
    )

  data_v2 <-
    tibble::tibble(
      scope = c("a", "a", "a", "c"),
      name = c("x", "y", "w", "v"),
      value = c(1, 2, 9, 4)
    )

  res <-
    compute_comparison_summary(
      data_v1 = data_v1,
      data_v2 = data_v2,
      sel_unit = "taxa"
    )

  testthat::expect_equal(
    dplyr::select(res, scope, n_v1, n_v2, n_both, n_only_v1, n_only_v2),
    tibble::tibble(
      scope = c("a", "b", "c"),
      n_v1 = c(3, 1, 0),
      n_v2 = c(3, 0, 1),
      n_both = c(2, 0, 0),
      n_only_v1 = c(1, 1, 0),
      n_only_v2 = c(1, 0, 1)
    )
  )

  testthat::expect_equal(dplyr::pull(res, is_equal), c(FALSE, FALSE, FALSE))

  testthat::expect_true(base::is.na(dplyr::pull(res, checksum_v2)[2]))

  testthat::expect_true(base::is.na(dplyr::pull(res, checksum_v1)[3]))

  testthat::expect_false(
    dplyr::pull(res, checksum_v1)[1] == dplyr::pull(res, checksum_v2)[1]
  )
})

testthat::test_that("compute_comparison_summary() accepts empty sides", {
  data_empty <-
    tibble::tibble(scope = base::character(0), name = base::character(0))

  res_empty <-
    compute_comparison_summary(
      data_v1 = data_empty,
      data_v2 = data_empty,
      sel_unit = "references"
    )

  testthat::expect_equal(base::nrow(res_empty), 0L)

  testthat::expect_named(
    res_empty,
    c(
      "unit", "scope", "n_v1", "n_v2", "n_both", "n_only_v1", "n_only_v2",
      "checksum_v1", "checksum_v2", "is_equal"
    )
  )

  res_one <-
    compute_comparison_summary(
      data_v1 = data_empty,
      data_v2 = tibble::tibble(scope = "a", name = "x"),
      sel_unit = "references"
    )

  testthat::expect_equal(dplyr::pull(res_one, n_only_v2), 1)
})

testthat::test_that("compute_comparison_summary() matches missing values", {
  data_v1 <-
    tibble::tibble(scope = "a", name = c("x", NA), value = c(NA, 1))

  res <-
    compute_comparison_summary(
      data_v1 = data_v1,
      data_v2 = dplyr::slice(data_v1, c(2L, 1L)),
      sel_unit = "samples"
    )

  testthat::expect_true(dplyr::pull(res, is_equal))

  testthat::expect_equal(dplyr::pull(res, n_both), 2)
})
