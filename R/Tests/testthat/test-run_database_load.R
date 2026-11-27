#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("run_database_load() validates arguments", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_work <-
    base::file.path(dir_test, "db_work.sqlite")

  path_new <-
    base::file.path(dir_test, "db_new.sqlite")

  list_tables <-
    build_writer_test_tables()

  list_pragmas_load <-
    base::list(journal_mode = "MEMORY", foreign_keys = "OFF")

  list_pragmas_final <-
    base::list(journal_mode = "DELETE", foreign_keys = "ON")

  testthat::expect_error(
    run_database_load(
      con = "not a connection",
      list_tables = list_tables,
      path_vacuum_into = path_new,
      list_pragmas_load = list_pragmas_load,
      list_pragmas_final = list_pragmas_final,
      n_chunk_size = 2L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "con"
  )

  run_with_database(
    path_database = path_work,
    fn = ~ {
      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = base::list(Unknown = tibble::tibble(x = 1L)),
          path_vacuum_into = path_new,
          list_pragmas_load = list_pragmas_load,
          list_pragmas_final = list_pragmas_final,
          n_chunk_size = 2L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "Unknown"
      )

      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = base::list(
            UsageView = tibble::tibble(user_name = "a")
          ),
          path_vacuum_into = path_new,
          list_pragmas_load = list_pragmas_load,
          list_pragmas_final = list_pragmas_final,
          n_chunk_size = 2L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "UsageView"
      )

      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = base::list(Loose = "not a table"),
          path_vacuum_into = path_new,
          list_pragmas_load = list_pragmas_load,
          list_pragmas_final = list_pragmas_final,
          n_chunk_size = 2L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "list_tables"
      )

      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = list_tables,
          path_vacuum_into = path_new,
          list_pragmas_load = base::list(
            journal_mode = "OFF; DROP TABLE Usage"
          ),
          list_pragmas_final = list_pragmas_final,
          n_chunk_size = 2L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "list_pragmas_load"
      )

      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = list_tables,
          path_vacuum_into = path_new,
          list_pragmas_load = list_pragmas_load,
          list_pragmas_final = base::list(page_size = 4096L),
          n_chunk_size = 2L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "list_pragmas_final"
      )

      testthat::expect_error(
        run_database_load(
          con = .x,
          list_tables = list_tables,
          path_vacuum_into = path_new,
          list_pragmas_load = list_pragmas_load,
          list_pragmas_final = list_pragmas_final,
          n_chunk_size = -1L,
          path_schema = path_schema,
          verbose = FALSE
        ),
        regexp = "n_chunk_size"
      )
    }
  )

  # The refused calls created nothing
  vec_objects <-
    run_with_database(
      path_database = path_work,
      fn = DBI::dbListTables,
      flag_read_only = TRUE
    )

  testthat::expect_length(vec_objects, 0L)
  testthat::expect_false(base::file.exists(path_new))
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("run_database_load() loads, finishes and copies a file", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_work <-
    base::file.path(dir_test, "db_work.sqlite")

  path_new <-
    base::file.path(dir_test, "db_new.sqlite")

  list_tables <-
    build_writer_test_tables()

  res <-
    run_with_database(
      path_database = path_work,
      fn = run_database_load,
      list_tables = list_tables,
      path_vacuum_into = path_new,
      list_pragmas_load = base::list(
        journal_mode = "MEMORY",
        synchronous = "OFF",
        foreign_keys = "OFF",
        cache_size = -4096L
      ),
      list_pragmas_final = base::list(
        journal_mode = "DELETE",
        synchronous = "FULL",
        foreign_keys = "ON"
      ),
      n_chunk_size = 2L,
      path_schema = path_schema,
      verbose = FALSE
    )

  testthat::expect_type(res, "list")
  testthat::expect_named(res, c("data_tables", "data_steps"))

  data_tables <-
    purrr::chuck(res, "data_tables")

  testthat::expect_named(
    data_tables,
    c("table_name", "n_rows", "n_chunks", "seconds")
  )
  testthat::expect_equal(
    dplyr::pull(data_tables, table_name),
    c("References", "Usage", "Loose")
  )
  testthat::expect_equal(dplyr::pull(data_tables, n_rows), c(3L, 4L, 3L))
  testthat::expect_equal(dplyr::pull(data_tables, n_chunks), c(2L, 2L, 2L))
  testthat::expect_true(
    base::all(dplyr::pull(data_tables, seconds) >= 0)
  )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "data_steps"), step),
    c(
      "schema", "pragmas_load", "tables", "indexes", "analyze",
      "pragmas_final", "vacuum_into"
    )
  )

  testthat::expect_true(base::file.exists(path_new))

  list_new <-
    run_with_database(
      path_database = path_new,
      fn = ~ base::list(
        objects = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT type, name FROM sqlite_schema ORDER BY name"
        ),
        usage = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT * FROM Usage ORDER BY reference_id, user_name"
        ),
        references = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT * FROM \"References\" ORDER BY reference_id"
        )
      ),
      flag_read_only = TRUE
    )

  vec_object_names <-
    purrr::chuck(list_new, "objects") |>
    dplyr::pull(name)

  testthat::expect_true("idx_usage_value" %in% vec_object_names)
  testthat::expect_true("UsageView" %in% vec_object_names)
  testthat::expect_true("sqlite_stat1" %in% vec_object_names)

  testthat::expect_equal(
    purrr::chuck(list_new, "references") |>
      dplyr::pull(reference_detail),
    c("ref_a", "ref_b", "ref_c")
  )
  testthat::expect_equal(
    purrr::chuck(list_new, "usage") |>
      dplyr::pull(value),
    c(15, 10, 20, 30)
  )

  # The new file uses a rollback journal (header bytes 19 and 20 are 1)
  vec_header <-
    base::readBin(con = path_new, what = "raw", n = 20L)

  testthat::expect_equal(vec_header[19:20], base::as.raw(c(1L, 1L)))
})

testthat::test_that("run_database_load() leaves unlisted tables empty", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_new <-
    base::file.path(dir_test, "db_new.sqlite")

  # A usage without its reference loads: foreign keys are checked later
  res <-
    run_with_database(
      path_database = base::file.path(dir_test, "db_work.sqlite"),
      fn = run_database_load,
      list_tables = base::list(
        Usage = tibble::tibble(
          reference_id = 99L,
          user_name = "user_a",
          value = 1
        )
      ),
      path_vacuum_into = path_new,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    )

  data_tables <-
    purrr::chuck(res, "data_tables")

  testthat::expect_equal(dplyr::pull(data_tables, n_rows), c(0L, 1L, 0L))
  testthat::expect_equal(dplyr::pull(data_tables, n_chunks), c(0L, 1L, 0L))
  testthat::expect_true(base::file.exists(path_new))
})

testthat::test_that("run_database_load() reports progress when verbose", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  testthat::expect_message(
    run_with_database(
      path_database = base::file.path(dir_test, "db_work.sqlite"),
      fn = run_database_load,
      list_tables = build_writer_test_tables(),
      path_vacuum_into = base::file.path(dir_test, "db_new.sqlite"),
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = TRUE
    ),
    regexp = "VACUUM INTO"
  )
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("run_database_load() refuses a used work file", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_work <-
    base::file.path(dir_test, "db_work.sqlite")

  path_new <-
    base::file.path(dir_test, "db_new.sqlite")

  run_with_database(
    path_database = path_work,
    fn = DBI::dbExecute,
    statement = "CREATE TABLE leftover (x INTEGER)"
  )

  testthat::expect_error(
    run_with_database(
      path_database = path_work,
      fn = run_database_load,
      list_tables = build_writer_test_tables(),
      path_vacuum_into = path_new,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "empty"
  )

  base::writeLines(text = "occupied", con = path_new)

  testthat::expect_error(
    run_with_database(
      path_database = base::file.path(dir_test, "other_work.sqlite"),
      fn = run_database_load,
      list_tables = build_writer_test_tables(),
      path_vacuum_into = path_new,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "exists"
  )
})

testthat::test_that("run_database_load() stops on a bad row", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_new <-
    base::file.path(dir_test, "db_new.sqlite")

  list_tables <-
    build_writer_test_tables()

  list_tables_bad <-
    purrr::assign_in(
      list_tables,
      where = "References",
      value = tibble::tibble(
        reference_id = c(1L, 2L),
        reference_detail = c("ref_same", "ref_same")
      )
    )

  testthat::expect_error(
    run_with_database(
      path_database = base::file.path(dir_test, "db_work.sqlite"),
      fn = run_database_load,
      list_tables = list_tables_bad,
      path_vacuum_into = path_new,
      list_pragmas_load = base::list(
        journal_mode = "MEMORY",
        foreign_keys = "OFF"
      ),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "References"
  )

  testthat::expect_false(base::file.exists(path_new))
})

testthat::test_that("run_database_load() never reads or skips rows", {
  vec_body <-
    base::deparse(base::body(run_database_load))

  # Every table goes through the batched writer
  testthat::expect_true(
    base::any(
      stringr::str_detect(string = vec_body, pattern = "save_database_table")
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
