#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_name() fills date and hash", {
  res <-
    build_producer_file_name(
      name_template = "data_splot_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef"
    )

  testthat::expect_equal(
    res,
    "data_splot_2000-01-01__0123456789abcdef0123456789abcdef__.qs"
  )
})

testthat::test_that("build_producer_file_name() accepts a Date", {
  res <-
    build_producer_file_name(
      name_template = "data_splot_{date}__{hash}__.qs",
      date = base::as.Date("2000-01-01"),
      hash = "0123456789abcdef0123456789abcdef"
    )

  testthat::expect_equal(
    res,
    "data_splot_2000-01-01__0123456789abcdef0123456789abcdef__.qs"
  )
})

testthat::test_that("build_producer_file_name() fills partition, variable", {
  res <-
    build_producer_file_name(
      name_template = "bio{variable}_batch_{partition}_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef",
      partition = 2L,
      variable_token = "12"
    )

  testthat::expect_equal(
    res,
    "bio12_batch_2_2000-01-01__0123456789abcdef0123456789abcdef__.qs"
  )
})

testthat::test_that("build_producer_file_name() matches its own regex", {
  res <-
    build_producer_file_name(
      name_template = "data_age_uncertainty_{partition}_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef",
      partition = "C"
    )

  pattern_file <-
    build_producer_file_regex(
      name_template = "data_age_uncertainty_{partition}_{date}__{hash}__.qs",
      partition_scheme = "letter"
    )

  testthat::expect_true(stringr::str_detect(res, pattern_file))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_name() rejects malformed values", {
  testthat::expect_error(
    build_producer_file_name(
      name_template = "data_splot_{date}__{hash}__.qs",
      date = "2000-1-1",
      hash = "0123456789abcdef0123456789abcdef"
    ),
    regexp = "date"
  )

  testthat::expect_error(
    build_producer_file_name(
      name_template = "data_splot_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "abc"
    ),
    regexp = "hash"
  )
})

testthat::test_that("build_producer_file_name() matches placeholders", {
  testthat::expect_error(
    build_producer_file_name(
      name_template = "data_splot_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef",
      partition = 1L
    ),
    regexp = "partition"
  )

  testthat::expect_error(
    build_producer_file_name(
      name_template = "data_{partition}_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef"
    ),
    regexp = "partition"
  )

  testthat::expect_error(
    build_producer_file_name(
      name_template = "bio{variable}_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef"
    ),
    regexp = "variable"
  )

  testthat::expect_error(
    build_producer_file_name(
      name_template = "data_{date}__{hash}__.qs",
      date = "2000-01-01",
      hash = "0123456789abcdef0123456789abcdef",
      variable_token = "01"
    ),
    regexp = "variable"
  )
})
