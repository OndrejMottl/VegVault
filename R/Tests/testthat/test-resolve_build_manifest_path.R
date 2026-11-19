#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_build_manifest_path() validates its input", {
  testthat::expect_error(
    resolve_build_manifest_path(path_database = c("a.sqlite", "b.sqlite")),
    regexp = "path_database"
  )

  testthat::expect_error(
    resolve_build_manifest_path(path_database = ""),
    regexp = "path_database"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("resolve_build_manifest_path() names the manifest", {
  res <-
    resolve_build_manifest_path(
      path_database = "D:/Data/VegVault/VegVault.sqlite"
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(
    res,
    "D:/Data/VegVault/VegVault_build_manifest.yml"
  )
})

testthat::test_that("resolve_build_manifest_path() keeps the folder", {
  res <-
    resolve_build_manifest_path(
      path_database = "Temp/Subset/VegVault_subset.db.sqlite"
    )

  testthat::expect_equal(
    res,
    "Temp/Subset/VegVault_subset.db_build_manifest.yml"
  )

  res_backslash <-
    resolve_build_manifest_path(
      path_database = "D:\\Data\\VegVault.sqlite"
    )

  testthat::expect_equal(
    res_backslash,
    "D:/Data/VegVault_build_manifest.yml"
  )
})
