#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_build_paths() validates arguments", {
  testthat::expect_error(
    resolve_database_build_paths(path_database = 1),
    regexp = "path_database"
  )

  testthat::expect_error(
    resolve_database_build_paths(path_database = c("a.sqlite", "b.sqlite")),
    regexp = "path_database"
  )

  testthat::expect_error(
    resolve_database_build_paths(path_database = NA_character_),
    regexp = "path_database"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_build_paths() names two sibling files", {
  dir_database <-
    withr::local_tempdir()

  res <-
    resolve_database_build_paths(
      path_database = base::file.path(dir_database, "VegVault.sqlite")
    )

  testthat::expect_type(res, "list")
  testthat::expect_named(res, c("path_work", "path_new"))
  testthat::expect_equal(
    purrr::chuck(res, "path_work"),
    base::file.path(dir_database, "VegVault_work.sqlite")
  )
  testthat::expect_equal(
    purrr::chuck(res, "path_new"),
    base::file.path(dir_database, "VegVault_new.sqlite")
  )
})

testthat::test_that("resolve_database_build_paths() keeps the extension", {
  res <-
    resolve_database_build_paths(
      path_database = "folder/VegVault.SQLite"
    )

  testthat::expect_equal(
    purrr::chuck(res, "path_work"),
    "folder/VegVault_work.SQLite"
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_build_paths() refuses other files", {
  testthat::expect_error(
    resolve_database_build_paths(path_database = "folder/VegVault.db"),
    regexp = "sqlite"
  )

  testthat::expect_error(
    resolve_database_build_paths(
      path_database = "folder/VegVault_work.sqlite"
    ),
    regexp = "work"
  )

  testthat::expect_error(
    resolve_database_build_paths(
      path_database = "folder/VegVault_new.sqlite"
    ),
    regexp = "new"
  )
})

testthat::test_that("resolve_database_build_paths() never prints the path", {
  res_error <-
    testthat::expect_error(
      resolve_database_build_paths(
        path_database = "private_folder/VegVault.db"
      ),
      regexp = "sqlite"
    )

  testthat::expect_false(
    stringr::str_detect(
      string = base::conditionMessage(res_error),
      pattern = "private_folder"
    )
  )
})
