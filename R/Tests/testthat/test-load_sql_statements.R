#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_sql_statements() validates its argument", {
  testthat::expect_error(
    load_sql_statements(path_sql = 1),
    regexp = "path_sql"
  )

  testthat::expect_error(
    load_sql_statements(path_sql = c("a.sql", "b.sql")),
    regexp = "path_sql"
  )

  testthat::expect_error(
    load_sql_statements(
      path_sql = base::file.path(withr::local_tempdir(), "missing.sql")
    ),
    regexp = "path_sql"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_sql_statements() returns one row per statement", {
  path_sql <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE \"a\" (\"x\" INTEGER);",
      "CREATE UNIQUE INDEX idx_a_x ON a(x);",
      "CREATE VIEW [v] AS SELECT x FROM a;",
      "INSERT INTO a VALUES (1);"
    ),
    con = path_sql
  )

  res <-
    load_sql_statements(path_sql = path_sql)

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("statement_id", "object_type", "object_name", "statement")
  )

  testthat::expect_equal(dplyr::pull(res, statement_id), 1:4)

  testthat::expect_equal(
    dplyr::pull(res, object_type),
    c("table", "index", "view", "other")
  )

  testthat::expect_equal(
    dplyr::pull(res, object_name),
    c("a", "idx_a_x", "v", NA_character_)
  )

  testthat::expect_equal(
    dplyr::pull(res, statement),
    c(
      "CREATE TABLE \"a\" (\"x\" INTEGER)",
      "CREATE UNIQUE INDEX idx_a_x ON a(x)",
      "CREATE VIEW [v] AS SELECT x FROM a",
      "INSERT INTO a VALUES (1)"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_sql_statements() ignores quoted semicolons", {
  path_sql <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE \"semi;colon\" (",
      "  [col;a] TEXT DEFAULT 'it''s; fine',",
      "  `col;b` TEXT",
      ");",
      "CREATE TABLE b (x TEXT DEFAULT ';')"
    ),
    con = path_sql
  )

  res <-
    load_sql_statements(path_sql = path_sql)

  testthat::expect_equal(base::nrow(res), 2L)

  testthat::expect_equal(
    dplyr::pull(res, object_name),
    c("semi;colon", "b")
  )

  testthat::expect_equal(
    dplyr::pull(res, statement),
    c(
      stringr::str_c(
        "CREATE TABLE \"semi;colon\" (\n",
        "  [col;a] TEXT DEFAULT 'it''s; fine',\n",
        "  `col;b` TEXT\n",
        ")"
      ),
      "CREATE TABLE b (x TEXT DEFAULT ';')"
    )
  )
})

testthat::test_that("load_sql_statements() drops comments", {
  path_sql <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "-- A header comment; with a semicolon",
      "/* A block comment;",
      "   over two lines */",
      "CREATE TABLE a (x INTEGER); -- trailing; comment",
      "CREATE TABLE b (y TEXT DEFAULT '-- not a comment');",
      "-- only a comment after the last statement;"
    ),
    con = path_sql
  )

  res <-
    load_sql_statements(path_sql = path_sql)

  testthat::expect_equal(
    dplyr::pull(res, statement),
    c(
      "CREATE TABLE a (x INTEGER)",
      "CREATE TABLE b (y TEXT DEFAULT '-- not a comment')"
    )
  )
})

testthat::test_that("load_sql_statements() reads every CREATE form", {
  path_sql <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "create temp table if not exists `t1` (x INTEGER);",
      "CREATE TEMPORARY TABLE t2 (x INTEGER);",
      "CREATE INDEX IF NOT EXISTS \"idx_t2\" ON t2 (x);",
      "CREATE TEMP VIEW v1 AS SELECT 1;",
      "PRAGMA foreign_keys = ON"
    ),
    con = path_sql
  )

  res <-
    load_sql_statements(path_sql = path_sql)

  testthat::expect_equal(
    dplyr::pull(res, object_type),
    c("table", "table", "index", "view", "other")
  )

  testthat::expect_equal(
    dplyr::pull(res, object_name),
    c("t1", "t2", "idx_t2", "v1", NA_character_)
  )
})

testthat::test_that("load_sql_statements() reads the project schema", {
  res <-
    load_sql_statements(
      path_sql = here::here("Data", "SQL", "make_tables.sql")
    )

  testthat::expect_equal(
    base::as.integer(base::table(dplyr::pull(res, object_type))),
    c(30L, 34L, 1L)
  )

  testthat::expect_equal(
    base::names(base::table(dplyr::pull(res, object_type))),
    c("index", "table", "view")
  )

  testthat::expect_false(
    base::anyDuplicated(dplyr::pull(res, object_name)) > 0L
  )
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("load_sql_statements() aborts on unclosed text", {
  vec_broken <-
    c(
      "CREATE TABLE a (x TEXT DEFAULT 'open);",
      "CREATE TABLE \"a (x TEXT);",
      "CREATE TABLE [a (x TEXT);",
      "CREATE TABLE `a (x TEXT);",
      "CREATE TABLE a (x TEXT); /* open comment",
      "CREATE TABLE a (x TEXT DEFAULT 'a'');"
    )

  purrr::walk(
    .x = vec_broken,
    .f = ~ {
      path_sql <-
        withr::local_tempfile(fileext = ".sql")

      base::writeLines(text = .x, con = path_sql)

      testthat::expect_error(
        load_sql_statements(path_sql = path_sql),
        regexp = "not closed"
      )
    }
  )
})

testthat::test_that("load_sql_statements() refuses triggers", {
  path_sql <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE a (x INTEGER);",
      "CREATE TRIGGER trg AFTER INSERT ON a BEGIN SELECT 1; END;"
    ),
    con = path_sql
  )

  testthat::expect_error(
    load_sql_statements(path_sql = path_sql),
    regexp = "TRIGGER"
  )
})

testthat::test_that("load_sql_statements() aborts without statements", {
  path_empty <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(text = character(0), con = path_empty)

  testthat::expect_error(
    load_sql_statements(path_sql = path_empty),
    regexp = "no statement"
  )

  path_comments <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c("-- only a comment", "/* and another */", ";"),
    con = path_comments
  )

  testthat::expect_error(
    load_sql_statements(path_sql = path_comments),
    regexp = "no statement"
  )
})
