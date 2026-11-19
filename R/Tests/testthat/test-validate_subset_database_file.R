#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_subset_database_file() accepts a subfolder", {
  res <-
    validate_subset_database_file(
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  testthat::expect_equal(res, "Temp/Subset/VegVault_subset.sqlite")

  testthat::expect_invisible(
    validate_subset_database_file(database_file = "VegVault_subset.sqlite")
  )

  # Two dots inside a file name are not a parent-folder segment
  res_dots <-
    validate_subset_database_file(database_file = "Temp/a..b.sqlite")

  testthat::expect_equal(res_dots, "Temp/a..b.sqlite")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_subset_database_file() needs a text value", {
  testthat::expect_error(
    validate_subset_database_file(database_file = NULL),
    regexp = "database_file"
  )

  testthat::expect_error(
    validate_subset_database_file(database_file = ""),
    regexp = "database_file"
  )

  testthat::expect_error(
    validate_subset_database_file(database_file = c("a.sqlite", "b.sqlite")),
    regexp = "database_file"
  )

  testthat::expect_error(
    validate_subset_database_file(database_file = NA_character_),
    regexp = "database_file"
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("validate_subset_database_file() refuses absolute", {
  vec_absolute <-
    c(
      "D:/Private/VegVault.sqlite",
      "D:\\Private\\VegVault.sqlite",
      "/home/private/VegVault.sqlite",
      "\\\\server\\share\\VegVault.sqlite",
      "D:VegVault.sqlite"
    )

  purrr::walk(
    .x = vec_absolute,
    .f = ~ testthat::expect_error(
      validate_subset_database_file(database_file = .x),
      regexp = "relative"
    )
  )
})

testthat::test_that("validate_subset_database_file() stays in the root", {
  vec_escaping <-
    c(
      "../Live/VegVault.sqlite",
      "Temp/../../VegVault.sqlite",
      "Temp\\..\\..\\VegVault.sqlite",
      "..",
      "Temp/.."
    )

  purrr::walk(
    .x = vec_escaping,
    .f = ~ testthat::expect_error(
      validate_subset_database_file(database_file = .x),
      regexp = "data root"
    )
  )
})
