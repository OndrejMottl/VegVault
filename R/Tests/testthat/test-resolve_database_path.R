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


#----------------------------------------------------------#
# Subset profile -----
#----------------------------------------------------------#

testthat::test_that("resolve_database_path() uses the subset database", {
  dir_project <-
    withr::local_tempdir()

  dir_data <-
    base::file.path(dir_project, "Data")

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  base::writeLines(
    text = c(
      "database_path: \"D:/Private/VegVault/VegVault.sqlite\"",
      "database_v1_path: \"D:/Private/VegVault_v1/VegVault.sqlite\""
    ),
    con = path_secrets
  )

  list_subset <-
    list(
      enabled = TRUE,
      box_name = "alaska_yukon",
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  res <-
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project,
      list_subset = list_subset,
      path_data_storage = dir_data
    )

  testthat::expect_equal(
    res,
    base::normalizePath(
      base::file.path(dir_data, "Temp/Subset/VegVault_subset.sqlite"),
      winslash = "/",
      mustWork = FALSE
    )
  )

  # The v1.0.0 database is always the released file
  res_v1 <-
    resolve_database_path(
      key = "database_v1_path",
      path_secrets = path_secrets,
      path_project = dir_project,
      list_subset = list_subset,
      path_data_storage = dir_data
    )

  testthat::expect_equal(res_v1, "D:/Private/VegVault_v1/VegVault.sqlite")
})

testthat::test_that("resolve_database_path() subset needs no secrets", {
  dir_project <-
    withr::local_tempdir()

  res <-
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project,
      list_subset = list(
        enabled = TRUE,
        database_file = "VegVault_subset.sqlite"
      ),
      path_data_storage = dir_project
    )

  testthat::expect_match(res, "/VegVault_subset[.]sqlite$")
})

testthat::test_that("resolve_database_path() ignores a disabled subset", {
  dir_project <-
    withr::local_tempdir()

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  base::writeLines(
    text = "database_path: \"D:/Private/VegVault/VegVault.sqlite\"",
    con = path_secrets
  )

  res <-
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project,
      list_subset = list(enabled = FALSE),
      path_data_storage = dir_project
    )

  testthat::expect_equal(res, "D:/Private/VegVault/VegVault.sqlite")
})

testthat::test_that("resolve_database_path() checks the subset settings", {
  dir_project <-
    withr::local_tempdir()

  testthat::expect_error(
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project,
      list_subset = list(enabled = "yes"),
      path_data_storage = dir_project
    ),
    regexp = "enabled"
  )

  testthat::expect_error(
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project,
      list_subset = list(enabled = TRUE),
      path_data_storage = dir_project
    ),
    regexp = "database_file"
  )

  testthat::expect_error(
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project,
      list_subset = list(
        enabled = TRUE,
        database_file = "D:/Private/VegVault.sqlite"
      ),
      path_data_storage = dir_project
    ),
    regexp = "relative"
  )
})

testthat::test_that("resolve_database_path() keeps the subset in the root", {
  dir_project <-
    withr::local_tempdir()

  testthat::expect_error(
    resolve_database_path(
      path_secrets = base::file.path(dir_project, "secrets.yaml"),
      path_project = dir_project,
      list_subset = list(
        enabled = TRUE,
        database_file = "../Live/VegVault.sqlite"
      ),
      path_data_storage = dir_project
    ),
    regexp = "data root"
  )
})

testthat::test_that("resolve_database_path() subset uses the data root", {
  dir_project <-
    withr::local_tempdir()

  # Forward slashes, because backslashes are escapes in YAML double quotes
  dir_data <-
    withr::local_tempdir() |>
    base::normalizePath(winslash = "/")

  path_secrets <-
    base::file.path(dir_project, "secrets.yaml")

  # The data root may come from the secrets file, the database path never
  base::writeLines(
    text = c(
      stringr::str_c("Data: \"", dir_data, "\""),
      "database_path: \"D:/Private/VegVault/VegVault.sqlite\""
    ),
    con = path_secrets
  )

  res <-
    resolve_database_path(
      path_secrets = path_secrets,
      path_project = dir_project,
      list_subset = list(
        enabled = TRUE,
        database_file = "Temp/VegVault_subset.sqlite"
      )
    )

  testthat::expect_equal(
    res,
    base::normalizePath(
      base::file.path(dir_data, "Temp/VegVault_subset.sqlite"),
      winslash = "/",
      mustWork = FALSE
    )
  )
})
