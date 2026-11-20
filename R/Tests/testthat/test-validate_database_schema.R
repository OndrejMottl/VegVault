#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_schema() validates arguments", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY);",
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  testthat::expect_error(
    validate_database_schema(
      con = "not a connection",
      path_schema = path_schema
    ),
    regexp = "con"
  )

  con_closed <-
    DBI::dbConnect(drv = RSQLite::SQLite(), dbname = path_database)

  DBI::dbDisconnect(conn = con_closed)

  testthat::expect_error(
    validate_database_schema(con = con_closed, path_schema = path_schema),
    regexp = "con"
  )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      testthat::expect_error(
        validate_database_schema(con = .x, path_schema = 1),
        regexp = "path_schema"
      )

      testthat::expect_error(
        validate_database_schema(
          con = .x,
          path_schema = base::file.path(base::tempdir(), "missing.sql")
        ),
        regexp = "path_schema"
      )

      testthat::expect_error(
        validate_database_schema(
          con = .x,
          path_schema = path_schema,
          flag_require_indexes = NA
        ),
        regexp = "flag_require_indexes"
      )
    }
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_database_schema() accepts a built schema", {
  vec_statements <-
    c(
      stringr::str_c(
        "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY, ",
        "alpha_name TEXT NOT NULL UNIQUE)"
      ),
      stringr::str_c(
        "CREATE TABLE tbl_beta (alpha_id INTEGER NOT NULL, x REAL NOT NULL, ",
        "PRIMARY KEY (alpha_id, x), ",
        "FOREIGN KEY (alpha_id) REFERENCES tbl_alpha (alpha_id)) ",
        "WITHOUT ROWID"
      ),
      stringr::str_c(
        "CREATE VIEW view_gamma AS SELECT a.alpha_name, b.x ",
        "FROM tbl_alpha AS a JOIN tbl_beta AS b ON b.alpha_id = a.alpha_id"
      ),
      "CREATE INDEX idx_beta_x ON tbl_beta (x)"
    )

  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = stringr::str_c(vec_statements, ";"),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ purrr::walk(
      .x = vec_statements,
      .f = DBI::dbExecute,
      conn = .x
    )
  )

  # Statistics tables of SQLite are not part of the schema
  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "ANALYZE"
  )

  run_with_database(
    path_database = path_database,
    fn = ~ testthat::expect_invisible(
      validate_database_schema(con = .x, path_schema = path_schema)
    ),
    flag_read_only = TRUE
  )

  res <-
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      path_schema = path_schema,
      flag_read_only = TRUE
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("object_type", "object_name"))

  testthat::expect_equal(
    dplyr::pull(res, object_type),
    c("table", "table", "view", "index")
  )

  testthat::expect_equal(
    dplyr::pull(res, object_name),
    c("tbl_alpha", "tbl_beta", "view_gamma", "idx_beta_x")
  )
})

testthat::test_that("validate_database_schema() can skip missing indexes", {
  vec_statements <-
    c(
      "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY, x REAL)",
      "CREATE INDEX idx_alpha_x ON tbl_alpha (x)"
    )

  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = stringr::str_c(vec_statements, ";"),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = vec_statements[1]
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      path_schema = path_schema,
      flag_read_only = TRUE
    ),
    regexp = "idx_alpha_x"
  )

  res <-
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      path_schema = path_schema,
      flag_require_indexes = FALSE,
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(res, object_name), "tbl_alpha")
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("validate_database_schema() names missing objects", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY);",
      "CREATE TABLE tbl_beta (beta_id INTEGER PRIMARY KEY);",
      "CREATE VIEW view_gamma AS SELECT beta_id FROM tbl_beta;"
    ),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY)"
  )

  purrr::walk(
    .x = c("tbl_beta", "view_gamma"),
    .f = ~ testthat::expect_error(
      run_with_database(
        path_database = path_database,
        fn = validate_database_schema,
        path_schema = path_schema,
        flag_require_indexes = FALSE,
        flag_read_only = TRUE
      ),
      regexp = .x
    )
  )
})

testthat::test_that("validate_database_schema() names unexpected objects", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY);",
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(
        conn = .x,
        statement = "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY)"
      )

      DBI::dbExecute(
        conn = .x,
        statement = "CREATE TABLE tbl_extra (extra_id INTEGER)"
      )
    }
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      path_schema = path_schema,
      flag_read_only = TRUE
    ),
    regexp = "tbl_extra"
  )
})

testthat::test_that("validate_database_schema() names changed objects", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      stringr::str_c(
        "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY, ",
        "alpha_name TEXT NOT NULL UNIQUE);"
      ),
      "CREATE TABLE tbl_beta (beta_id INTEGER PRIMARY KEY);"
    ),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(
        conn = .x,
        statement = stringr::str_c(
          "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY, ",
          "alpha_name TEXT)"
        )
      )

      DBI::dbExecute(
        conn = .x,
        statement = "CREATE TABLE tbl_beta (beta_id INTEGER PRIMARY KEY)"
      )
    }
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      path_schema = path_schema,
      flag_read_only = TRUE
    ),
    regexp = "tbl_alpha"
  )
})
