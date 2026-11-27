#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("run_with_database() validates arguments", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  testthat::expect_error(
    run_with_database(
      path_database = c("a.sqlite", "b.sqlite"),
      fn = DBI::dbListTables
    ),
    regexp = "path_database"
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = "dbListTables"
    ),
    regexp = "fn"
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = DBI::dbListTables,
      flag_read_only = NA
    ),
    regexp = "flag_read_only"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("run_with_database() returns the result of fn", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  res <-
    run_with_database(
      path_database = path_database,
      fn = ~ DBI::dbGetQuery(conn = .x, statement = "SELECT 2 + 3 AS n")
    )

  testthat::expect_s3_class(res, "data.frame")

  testthat::expect_equal(dplyr::pull(res, n), 5L)

  # Read-write mode creates a missing database
  testthat::expect_true(base::file.exists(path_database))
})

testthat::test_that("run_with_database() passes further arguments", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Example",
    value = base::data.frame(id = 1:3)
  )

  res <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbReadTable,
      name = "Example",
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(res, id), 1:3)
})

testthat::test_that("run_with_database() disconnects after success", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  env_capture <-
    base::new.env()

  run_with_database(
    path_database = path_database,
    fn = ~ base::assign(x = "con", value = .x, envir = env_capture)
  )

  con_used <-
    base::get(x = "con", envir = env_capture)

  testthat::expect_s4_class(con_used, "SQLiteConnection")

  testthat::expect_false(DBI::dbIsValid(con_used))
})

testthat::test_that("run_with_database() disconnects after an error", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  env_capture <-
    base::new.env()

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = ~ {
        base::assign(x = "con", value = .x, envir = env_capture)
        cli::cli_abort("Failure inside the task.")
      }
    ),
    regexp = "Failure inside the task"
  )

  con_used <-
    base::get(x = "con", envir = env_capture)

  testthat::expect_false(DBI::dbIsValid(con_used))
})


#----------------------------------------------------------#
# Read-only mode -----
#----------------------------------------------------------#

testthat::test_that("run_with_database() read-only mode cannot write", {
  path_database <-
    base::file.path(withr::local_tempdir(), "test.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Example",
    value = base::data.frame(id = 1L)
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = DBI::dbExecute,
      statement = "INSERT INTO Example (id) VALUES (2)",
      flag_read_only = TRUE
    ),
    regexp = "readonly|read-only|read only"
  )

  res <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbReadTable,
      name = "Example",
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(res, id), 1L)
})

testthat::test_that("run_with_database() read-only needs an existing file", {
  dir_private <-
    withr::local_tempdir(pattern = "private_folder_")

  path_database <-
    base::file.path(dir_private, "missing.sqlite")

  res_error <-
    testthat::expect_error(
      run_with_database(
        path_database = path_database,
        fn = DBI::dbListTables,
        flag_read_only = TRUE
      ),
      regexp = "does not exist"
    )

  # Database paths are private, so the message must not print one
  testthat::expect_false(
    stringr::str_detect(
      base::conditionMessage(res_error),
      stringr::fixed("private_folder_")
    )
  )

  testthat::expect_false(base::file.exists(path_database))
})
