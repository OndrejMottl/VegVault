#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_pragmas() validates arguments", {
  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  testthat::expect_error(
    validate_database_pragmas(
      con = "not a connection",
      list_pragmas = base::list(foreign_keys = "ON")
    ),
    regexp = "con"
  )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      testthat::expect_error(
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list("ON")
        ),
        regexp = "list_pragmas"
      )

      testthat::expect_error(
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list(page_size = 4096L)
        ),
        regexp = "page_size"
      )

      testthat::expect_error(
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list(foreign_keys = c("ON", "OFF"))
        ),
        regexp = "list_pragmas"
      )

      testthat::expect_error(
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list(synchronous = "SOMETIMES")
        ),
        regexp = "SOMETIMES"
      )
    }
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_database_pragmas() accepts matching values", {
  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  res <-
    run_with_database(
      path_database = path_database,
      fn = ~ {
        DBI::dbExecute(conn = .x, statement = "PRAGMA journal_mode = MEMORY")
        DBI::dbExecute(conn = .x, statement = "PRAGMA synchronous = OFF")
        DBI::dbExecute(conn = .x, statement = "PRAGMA foreign_keys = ON")
        DBI::dbExecute(conn = .x, statement = "PRAGMA temp_store = MEMORY")
        DBI::dbExecute(conn = .x, statement = "PRAGMA cache_size = -2000")

        res_names <-
          validate_database_pragmas(
            con = .x,
            list_pragmas = base::list(
              journal_mode = "MEMORY",
              synchronous = "OFF",
              foreign_keys = "ON",
              temp_store = "MEMORY",
              cache_size = -2000L
            )
          )

        # Numbers are accepted in place of the names
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list(synchronous = 0L, foreign_keys = 1)
        )

        res_names
      }
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("pragma", "expected", "value"))
  testthat::expect_equal(
    dplyr::pull(res, pragma),
    c("journal_mode", "synchronous", "foreign_keys", "temp_store",
      "cache_size")
  )
  testthat::expect_equal(
    dplyr::pull(res, value),
    c("memory", "0", "1", "2", "-2000")
  )
  testthat::expect_equal(
    dplyr::pull(res, expected),
    dplyr::pull(res, value)
  )
})

testthat::test_that("validate_database_pragmas() returns invisibly", {
  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      testthat::expect_invisible(
        validate_database_pragmas(
          con = .x,
          list_pragmas = base::list(foreign_keys = "OFF")
        )
      )
    }
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("validate_database_pragmas() names every difference", {
  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(conn = .x, statement = "PRAGMA synchronous = OFF")

      res_error <-
        testthat::expect_error(
          validate_database_pragmas(
            con = .x,
            list_pragmas = base::list(
              synchronous = "FULL",
              foreign_keys = "ON",
              journal_mode = "DELETE"
            )
          )
        )

      vec_message <-
        base::conditionMessage(res_error)

      testthat::expect_true(
        stringr::str_detect(string = vec_message, pattern = "synchronous")
      )
      testthat::expect_true(
        stringr::str_detect(string = vec_message, pattern = "foreign_keys")
      )
      testthat::expect_false(
        stringr::str_detect(string = vec_message, pattern = "journal_mode")
      )

      # Nothing was changed by the check
      testthat::expect_equal(
        DBI::dbGetQuery(conn = .x, statement = "PRAGMA synchronous") |>
          dplyr::pull(synchronous),
        0L
      )
    }
  )
})
