#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_database_table() validates arguments", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  list_tables <-
    build_writer_test_tables()

  testthat::expect_error(
    save_database_table(
      con = "not a connection",
      data_table = purrr::chuck(list_tables, "Loose"),
      name_table = "Loose",
      n_chunk_size = 2L
    ),
    regexp = "con"
  )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = "not a table",
          name_table = "Loose",
          n_chunk_size = 2L
        ),
        regexp = "data_table"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = c("Loose", "Usage"),
          n_chunk_size = 2L
        ),
        regexp = "name_table"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = "Loose",
          n_chunk_size = 0L
        ),
        regexp = "n_chunk_size"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = "Loose",
          n_chunk_size = 1.5
        ),
        regexp = "n_chunk_size"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = "Loose",
          n_chunk_size = 2L,
          verbose = "yes"
        ),
        regexp = "verbose"
      )
    }
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("save_database_table() writes rows in key order", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  list_tables <-
    build_writer_test_tables()

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      res_usage <-
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Usage"),
          name_table = "Usage",
          n_chunk_size = 3L,
          verbose = FALSE
        )

      testthat::expect_s3_class(res_usage, "tbl_df")
      testthat::expect_named(
        res_usage,
        c("table_name", "n_rows", "n_chunks")
      )
      testthat::expect_equal(dplyr::pull(res_usage, table_name), "Usage")
      testthat::expect_identical(dplyr::pull(res_usage, n_rows), 4L)
      testthat::expect_identical(dplyr::pull(res_usage, n_chunks), 2L)

      testthat::expect_invisible(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = "Loose",
          n_chunk_size = 1L,
          verbose = FALSE
        )
      )
    }
  )

  data_loose_stored <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT rowid, x, y FROM Loose ORDER BY rowid",
      flag_read_only = TRUE
    )

  # A table without a key is sorted by all of its columns before writing
  testthat::expect_equal(
    dplyr::pull(data_loose_stored, x),
    c(1L, 2L, 3L)
  )

  data_usage_stored <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT * FROM Usage ORDER BY reference_id, user_name",
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    dplyr::pull(data_usage_stored, value),
    c(15, 10, 20, 30)
  )
})

testthat::test_that("save_database_table() leaves absent columns default", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      save_database_table(
        con = .x,
        data_table = tibble::tibble(
          reference_id = 1L,
          reference_detail = "ref_a"
        ),
        name_table = "References",
        n_chunk_size = 10L,
        verbose = FALSE
      )
    }
  )

  data_stored <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT * FROM \"References\"",
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(data_stored, mandatory), 0L)
})

testthat::test_that("save_database_table() writes nothing for no rows", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  res <-
    run_with_database(
      path_database = path_database,
      fn = ~ {
        build_database_schema(
          con = .x,
          path_schema = path_schema,
          sel_objects = "tables"
        )

        res_empty <-
          save_database_table(
            con = .x,
            data_table = tibble::tibble(
              x = base::integer(0),
              y = base::character(0)
            ),
            name_table = "Loose",
            n_chunk_size = 10L,
            verbose = FALSE
          )

        res_empty
      }
    )

  testthat::expect_identical(dplyr::pull(res, n_rows), 0L)
  testthat::expect_identical(dplyr::pull(res, n_chunks), 0L)
})

testthat::test_that("save_database_table() reports progress when verbose", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  list_tables <-
    build_writer_test_tables()

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      testthat::expect_message(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "Loose"),
          name_table = "Loose",
          n_chunk_size = 2L,
          verbose = TRUE
        ),
        regexp = "Loose"
      )

      testthat::expect_no_message(
        save_database_table(
          con = .x,
          data_table = purrr::chuck(list_tables, "References"),
          name_table = "References",
          n_chunk_size = 2L,
          verbose = FALSE
        )
      )
    }
  )
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("save_database_table() fails on a repeated key", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  # Row 4 repeats the detail of row 1: with batches of 2 rows, batch 2
  #   (rows 3 and 4) fails and leaves no row, batch 1 stays written
  data_references <-
    tibble::tibble(
      reference_id = c(5L, 4L, 3L, 2L, 1L),
      reference_detail = c("ref_e", "ref_a", "ref_c", "ref_b", "ref_a")
    )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = data_references,
          name_table = "References",
          n_chunk_size = 2L,
          verbose = FALSE
        ),
        regexp = "References.*batch 2|batch 2.*References"
      )
    }
  )

  data_stored <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT reference_id FROM \"References\"",
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    base::sort(dplyr::pull(data_stored, reference_id)),
    c(1L, 2L)
  )
})

testthat::test_that("save_database_table() reports the database message", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(
            reference_id = 1L,
            user_name = "user_a",
            value = 200
          ),
          name_table = "Usage",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "CHECK constraint"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(
            reference_id = c(1L, 1L),
            user_name = c("user_a", "user_a")
          ),
          name_table = "Usage",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "UNIQUE constraint"
      )
    }
  )
})

testthat::test_that("save_database_table() checks the table before writing", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "db.sqlite")

  run_with_database(
    path_database = path_database,
    fn = ~ {
      build_database_schema(
        con = .x,
        path_schema = path_schema,
        sel_objects = "tables"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(x = 1L),
          name_table = "Missing",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "Missing"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(user_name = "user_a"),
          name_table = "UsageView",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "view"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(x = 1L, unknown_column = 2L),
          name_table = "Loose",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "unknown_column"
      )

      testthat::expect_error(
        save_database_table(
          con = .x,
          data_table = tibble::tibble(reference_id = 1L, value = 5),
          name_table = "Usage",
          n_chunk_size = 10L,
          verbose = FALSE
        ),
        regexp = "user_name"
      )
    }
  )

  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT (SELECT COUNT(*) FROM Loose) AS n_loose, ",
        "(SELECT COUNT(*) FROM Usage) AS n_usage"
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(data_counts, n_loose), 0L)
  testthat::expect_equal(dplyr::pull(data_counts, n_usage), 0L)
})

testthat::test_that("save_database_table() never reads or skips rows", {
  vec_body <-
    base::deparse(base::body(save_database_table))

  # Rows go in through plain appends, each batch in a transaction
  testthat::expect_true(
    base::any(
      stringr::str_detect(string = vec_body, pattern = "DBI::dbAppendTable")
    )
  )

  testthat::expect_true(
    base::any(
      stringr::str_detect(
        string = vec_body,
        pattern = "DBI::dbWithTransaction"
      )
    )
  )

  testthat::expect_false(
    base::any(
      stringr::str_detect(
        string = vec_body,
        pattern = stringr::regex("INSERT\\s+OR", ignore_case = TRUE)
      )
    )
  )

  testthat::expect_false(
    base::any(
      stringr::str_detect(
        string = vec_body,
        pattern = stringr::regex(
          "SELECT|dbReadTable|collect\\(|dplyr::tbl\\(",
          ignore_case = TRUE
        )
      )
    )
  )
})
