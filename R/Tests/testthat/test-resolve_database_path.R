#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_path() reads the database path", {
  dir_project <-
    withr::local_tempdir()

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  base::writeLines(
    text = c(
      "database_path: \"D:/Private/VegVault/VegVault.sqlite\"",
      "database_v1_path: \"D:/Private/VegVault_v1/VegVault.sqlite\""
    ),
    con = path_secrets
  )

  res <-
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(res, "D:/Private/VegVault/VegVault.sqlite")

  res_v1 <-
    resolve_database_path(
      key = "database_v1_path",
      path_secrets = path_secrets,
      path_project = dir_project
    )

  testthat::expect_equal(res_v1, "D:/Private/VegVault_v1/VegVault.sqlite")
})

testthat::test_that("resolve_database_path() resolves relative paths", {
  dir_project <-
    withr::local_tempdir()

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  base::writeLines(
    text = "database_path: \"Data/Temp/test.sqlite\"",
    con = path_secrets
  )

  res <-
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project
    )

  testthat::expect_equal(
    res,
    base::normalizePath(
      base::file.path(dir_project, "Data/Temp/test.sqlite"),
      winslash = "/",
      mustWork = FALSE
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_path() needs the secrets file", {
  dir_project <-
    withr::local_tempdir()

  testthat::expect_error(
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project
    ),
    regexp = "secrets_example.yaml"
  )
})

testthat::test_that("resolve_database_path() needs a valid entry", {
  dir_project <-
    withr::local_tempdir()

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  base::writeLines(
    text = c(
      "database_v1_path: \"D:/Private/VegVault_v1/VegVault.sqlite\"",
      "database_path: 5"
    ),
    con = path_secrets
  )

  testthat::expect_error(
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project
    ),
    regexp = "database_path"
  )

  base::writeLines(
    text = "database_v1_path: \"D:/Private/VegVault_v1/VegVault.sqlite\"",
    con = path_secrets
  )

  res_error <-
    testthat::expect_error(
      resolve_database_path(
        path_secrets = path_secrets,
        path_project = dir_project
      ),
      regexp = "database_path"
    )

  # Paths are private, so no message may print one
  testthat::expect_false(
    stringr::str_detect(
      base::conditionMessage(res_error),
      stringr::fixed("D:/Private")
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_path() validates arguments", {
  testthat::expect_error(
    resolve_database_path(key = c("a", "b")),
    regexp = "key"
  )

  testthat::expect_error(
    resolve_database_path(key = "database_path", path_secrets = 1),
    regexp = "path_secrets"
  )
})
