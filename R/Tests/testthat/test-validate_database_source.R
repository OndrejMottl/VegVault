#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_source() accepts its manifest", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  res <-
    validate_database_source(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_equal(res, path_database)

  testthat::expect_invisible(
    validate_database_source(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_database_source() refuses another database", {
  dir_private <-
    withr::local_tempdir(pattern = "private_folder_")

  res_error <-
    testthat::expect_error(
      validate_database_source(
        path_database = base::file.path(dir_private, "VegVault_old.sqlite"),
        list_build_manifest = list(
          database = list(file_name = "VegVault.sqlite")
        )
      ),
      regexp = "not the database of the build manifest"
    )

  testthat::expect_false(
    stringr::str_detect(
      base::conditionMessage(res_error),
      stringr::fixed("private_folder_")
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_source() validates arguments", {
  testthat::expect_error(
    validate_database_source(
      path_database = c("a.sqlite", "b.sqlite"),
      list_build_manifest = list(database = list(file_name = "a.sqlite"))
    ),
    regexp = "path_database"
  )

  testthat::expect_error(
    validate_database_source(
      path_database = "a.sqlite",
      list_build_manifest = list(profile = "default")
    ),
    regexp = "file_name"
  )

  testthat::expect_error(
    validate_database_source(
      path_database = "a.sqlite",
      list_build_manifest = "a.sqlite"
    ),
    regexp = "list_build_manifest"
  )
})
