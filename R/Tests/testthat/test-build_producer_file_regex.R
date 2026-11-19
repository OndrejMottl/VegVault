#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_regex() matches RUtilpol names", {
  res <-
    build_producer_file_regex(
      name_template = "data_splot_{date}__{hash}__.qs",
      partition_scheme = "none"
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_true(
    stringr::str_detect(
      "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs",
      res
    )
  )

  # The dot before the extension is literal
  testthat::expect_false(
    stringr::str_detect(
      "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__xqs",
      res
    )
  )

  # Anchored at both ends
  testthat::expect_false(
    stringr::str_detect(
      "old_data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs",
      res
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs.bak",
      res
    )
  )
})

testthat::test_that("build_producer_file_regex() checks date and hash", {
  res <-
    build_producer_file_regex(
      name_template = "data_splot_{date}__{hash}__.qs",
      partition_scheme = "none"
    )

  testthat::expect_false(
    stringr::str_detect(
      "data_splot_2023-12-6__cbf9022330b5d47a5c76bf7ca6b226b4__.qs",
      res
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b__.qs",
      res
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      "data_splot_2023-12-06__CBF9022330B5D47A5C76BF7CA6B226B4__.qs",
      res
    )
  )
})

testthat::test_that("build_producer_file_regex() names its groups", {
  res <-
    build_producer_file_regex(
      name_template = "bio{variable}_batch_{partition}_{date}__{hash}__.qs",
      partition_scheme = "integer",
      vec_variable_tokens = c("01", "12")
    )

  mat_match <-
    stringr::str_match(
      "bio12_batch_3_2024-08-06__ba82b2c5dc1ab5a7b97c3527ce46265e__.qs",
      res
    )

  testthat::expect_equal(
    base::unname(mat_match[1, "variable"]),
    "12"
  )

  testthat::expect_equal(
    base::unname(mat_match[1, "partition"]),
    "3"
  )

  testthat::expect_equal(
    base::unname(mat_match[1, "date"]),
    "2024-08-06"
  )

  testthat::expect_equal(
    base::unname(mat_match[1, "hash"]),
    "ba82b2c5dc1ab5a7b97c3527ce46265e"
  )

  # A token outside the list does not match
  testthat::expect_false(
    stringr::str_detect(
      "bio04_batch_3_2024-08-06__ba82b2c5dc1ab5a7b97c3527ce46265e__.qs",
      res
    )
  )
})

testthat::test_that("build_producer_file_regex() handles letter partitions", {
  res <-
    build_producer_file_regex(
      name_template = "data_age_uncertainty_{partition}_{date}__{hash}__.qs",
      partition_scheme = "letter"
    )

  hash_part <- "7781fda623c5da21cd6d4766e550985d"

  testthat::expect_true(
    stringr::str_detect(
      stringr::str_c(
        "data_age_uncertainty_B_2023-12-12__", hash_part, "__.qs"
      ),
      res
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      stringr::str_c(
        "data_age_uncertainty_2_2023-12-12__", hash_part, "__.qs"
      ),
      res
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      stringr::str_c(
        "data_age_uncertainty_AB_2023-12-12__", hash_part, "__.qs"
      ),
      res
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_regex() rejects bad templates", {
  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_splot__{hash}__.qs",
      partition_scheme = "none"
    ),
    regexp = "date"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_splot_{date}.qs",
      partition_scheme = "none"
    ),
    regexp = "hash"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_{part}_{date}__{hash}__.qs",
      partition_scheme = "none"
    ),
    regexp = "part"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_{partition}_{date}__{hash}__.qs",
      partition_scheme = "none"
    ),
    regexp = "partition"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_{date}__{hash}__.qs",
      partition_scheme = "integer"
    ),
    regexp = "partition"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "bio{variable}_{date}__{hash}__.qs",
      partition_scheme = "none"
    ),
    regexp = "variable"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "bio_{date}__{hash}__.qs",
      partition_scheme = "none",
      vec_variable_tokens = "01"
    ),
    regexp = "variable"
  )

  testthat::expect_error(
    build_producer_file_regex(
      name_template = "data_{date}__{hash}__.qs",
      partition_scheme = "decimal"
    ),
    regexp = "partition_scheme"
  )
})
