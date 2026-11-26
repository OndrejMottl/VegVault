data_counts_example <-
  tibble::tibble(
    metric = c("table_rows", "table_rows", "datasets", "age_min"),
    scope = c("Samples", "Taxa", "traits / TRY", "database"),
    n = c(12459714, 109220, 28272, NA)
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("select_version_count() returns the count of a metric", {
  res <-
    select_version_count(
      data_counts = data_counts_example,
      metric = "table_rows",
      scope = "Taxa"
    )

  testthat::expect_type(res, "double")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(res, 109220)
})

testthat::test_that("select_version_count() matches a scope with a slash", {
  res <-
    select_version_count(
      data_counts = data_counts_example,
      metric = "datasets",
      scope = "traits / TRY"
    )

  testthat::expect_equal(res, 28272)
})

testthat::test_that("select_version_count() returns a missing count as NA", {
  res <-
    select_version_count(
      data_counts = data_counts_example,
      metric = "age_min",
      scope = "database"
    )

  testthat::expect_true(base::is.na(res))
})


#----------------------------------------------------------#
# Failures -----
#----------------------------------------------------------#

testthat::test_that("select_version_count() aborts when no row matches", {
  testthat::expect_error(
    select_version_count(
      data_counts = data_counts_example,
      metric = "table_rows",
      scope = "Authors"
    ),
    regexp = "table_rows"
  )
})

testthat::test_that("select_version_count() aborts when two rows match", {
  data_counts_repeated <-
    dplyr::bind_rows(
      data_counts_example,
      tibble::tibble(metric = "table_rows", scope = "Taxa", n = 1)
    )

  testthat::expect_error(
    select_version_count(
      data_counts = data_counts_repeated,
      metric = "table_rows",
      scope = "Taxa"
    ),
    regexp = "Taxa"
  )
})

testthat::test_that("select_version_count() aborts without a needed column", {
  testthat::expect_error(
    select_version_count(
      data_counts = dplyr::rename(data_counts_example, n_v1 = "n"),
      metric = "table_rows",
      scope = "Taxa"
    ),
    regexp = "column"
  )
})

testthat::test_that("select_version_count() aborts on a bad metric or scope", {
  testthat::expect_error(
    select_version_count(
      data_counts = data_counts_example,
      metric = c("table_rows", "datasets"),
      scope = "Taxa"
    ),
    regexp = "metric"
  )

  testthat::expect_error(
    select_version_count(
      data_counts = data_counts_example,
      metric = "table_rows",
      scope = NA_character_
    ),
    regexp = "scope"
  )
})
