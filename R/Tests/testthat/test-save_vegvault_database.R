#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_vegvault_database() validates arguments", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  list_tables <-
    build_writer_test_tables()

  testthat::expect_error(
    save_vegvault_database(
      path_database = 1,
      list_tables = list_tables,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "path_database"
  )

  testthat::expect_error(
    save_vegvault_database(
      path_database = path_database,
      list_tables = "not a list",
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "list_tables"
  )

  testthat::expect_error(
    save_vegvault_database(
      path_database = path_database,
      list_tables = list_tables,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      flag_replace_existing = "no",
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "flag_replace_existing"
  )

  testthat::expect_false(base::file.exists(path_database))
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("save_vegvault_database() builds the database file", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  testthat::expect_invisible(
    save_vegvault_database(
      path_database = path_database,
      list_tables = build_writer_test_tables(),
      list_pragmas_load = base::list(
        journal_mode = "MEMORY",
        synchronous = "OFF",
        foreign_keys = "OFF"
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
  )

  testthat::expect_true(base::file.exists(path_database))
  testthat::expect_false(
    base::file.exists(base::file.path(dir_test, "Vault_work.sqlite"))
  )
  testthat::expect_false(
    base::file.exists(base::file.path(dir_test, "Vault_new.sqlite"))
  )

  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT (SELECT COUNT(*) FROM \"References\") AS n_references, ",
        "(SELECT COUNT(*) FROM Usage) AS n_usage, ",
        "(SELECT COUNT(*) FROM Loose) AS n_loose"
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(dplyr::pull(data_counts, n_references), 3L)
  testthat::expect_equal(dplyr::pull(data_counts, n_usage), 4L)
  testthat::expect_equal(dplyr::pull(data_counts, n_loose), 3L)
})

testthat::test_that("save_vegvault_database() returns the load summary", {
  dir_test <-
    withr::local_tempdir()

  res <-
    save_vegvault_database(
      path_database = base::file.path(dir_test, "Vault.sqlite"),
      list_tables = build_writer_test_tables(),
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      path_schema = build_writer_test_schema(dir = dir_test),
      verbose = FALSE
    )

  testthat::expect_named(res, c("data_tables", "data_steps"))
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "data_steps"), step),
    c(
      "schema", "pragmas_load", "tables", "indexes", "analyze",
      "pragmas_final", "vacuum_into", "replace"
    )
  )
})

testthat::test_that("save_vegvault_database() does not depend on row order", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  list_tables <-
    build_writer_test_tables()

  list_tables_reversed <-
    list_tables |>
    purrr::map(
      .f = ~ dplyr::slice(.x, base::rev(base::seq_len(base::nrow(.x))))
    )

  vec_paths <-
    c(
      base::file.path(dir_test, "Vault_a.sqlite"),
      base::file.path(dir_test, "Vault_b.sqlite")
    )

  purrr::walk2(
    .x = vec_paths,
    .y = base::list(list_tables, list_tables_reversed),
    .f = ~ save_vegvault_database(
      path_database = .x,
      list_tables = .y,
      list_pragmas_load = base::list(foreign_keys = "OFF"),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 2L,
      path_schema = path_schema,
      verbose = FALSE
    )
  )

  list_stored <-
    vec_paths |>
    purrr::map(
      .f = ~ run_with_database(
        path_database = .x,
        fn = ~ base::list(
          references = DBI::dbGetQuery(
            conn = .x,
            statement = "SELECT rowid, * FROM \"References\""
          ),
          usage = DBI::dbGetQuery(
            conn = .x,
            statement = "SELECT * FROM Usage"
          ),
          loose = DBI::dbGetQuery(
            conn = .x,
            statement = "SELECT rowid, * FROM Loose"
          )
        ),
        flag_read_only = TRUE
      )
    )

  testthat::expect_identical(
    purrr::chuck(list_stored, 1L),
    purrr::chuck(list_stored, 2L)
  )
})

testthat::test_that("save_vegvault_database() clears a failed build", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  # Leftovers of an interrupted build: a used work file and a new file
  run_with_database(
    path_database = base::file.path(dir_test, "Vault_work.sqlite"),
    fn = DBI::dbExecute,
    statement = "CREATE TABLE leftover (x INTEGER)"
  )

  base::writeLines(
    text = "partial",
    con = base::file.path(dir_test, "Vault_new.sqlite")
  )

  save_vegvault_database(
    path_database = path_database,
    list_tables = build_writer_test_tables(),
    list_pragmas_load = base::list(foreign_keys = "OFF"),
    list_pragmas_final = base::list(foreign_keys = "ON"),
    n_chunk_size = 10L,
    path_schema = path_schema,
    verbose = FALSE
  )

  vec_tables <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbListTables,
      flag_read_only = TRUE
    )

  testthat::expect_false("leftover" %in% vec_tables)
  testthat::expect_true("Usage" %in% vec_tables)
})


#----------------------------------------------------------#
# Existing database -----
#----------------------------------------------------------#

testthat::test_that("save_vegvault_database() keeps an existing database", {
  dir_test <-
    withr::local_tempdir("private_folder")

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  base::writeLines(text = "old database", con = path_database)

  res_error <-
    testthat::expect_error(
      save_vegvault_database(
        path_database = path_database,
        list_tables = build_writer_test_tables(),
        list_pragmas_load = base::list(foreign_keys = "OFF"),
        list_pragmas_final = base::list(foreign_keys = "ON"),
        n_chunk_size = 10L,
        path_schema = path_schema,
        verbose = FALSE
      ),
      regexp = "exists"
    )

  testthat::expect_false(
    stringr::str_detect(
      string = base::conditionMessage(res_error),
      pattern = "private_folder"
    )
  )
  testthat::expect_equal(base::readLines(path_database), "old database")
  testthat::expect_false(
    base::file.exists(base::file.path(dir_test, "Vault_work.sqlite"))
  )
})

testthat::test_that("save_vegvault_database() replaces only when asked", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "CREATE TABLE old_marker (x INTEGER)"
  )

  save_vegvault_database(
    path_database = path_database,
    list_tables = build_writer_test_tables(),
    list_pragmas_load = base::list(foreign_keys = "OFF"),
    list_pragmas_final = base::list(foreign_keys = "ON"),
    n_chunk_size = 10L,
    flag_replace_existing = TRUE,
    path_schema = path_schema,
    verbose = FALSE
  )

  vec_tables <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbListTables,
      flag_read_only = TRUE
    )

  testthat::expect_false("old_marker" %in% vec_tables)
  testthat::expect_true("References" %in% vec_tables)
})

testthat::test_that("save_vegvault_database() keeps the old file on failure", {
  dir_test <-
    withr::local_tempdir()

  path_schema <-
    build_writer_test_schema(dir = dir_test)

  path_database <-
    base::file.path(dir_test, "Vault.sqlite")

  base::writeLines(text = "old database", con = path_database)

  list_tables_bad <-
    purrr::assign_in(
      build_writer_test_tables(),
      where = "References",
      value = tibble::tibble(
        reference_id = c(1L, 2L),
        reference_detail = c("ref_same", "ref_same")
      )
    )

  testthat::expect_error(
    save_vegvault_database(
      path_database = path_database,
      list_tables = list_tables_bad,
      list_pragmas_load = base::list(
        journal_mode = "MEMORY",
        foreign_keys = "OFF"
      ),
      list_pragmas_final = base::list(foreign_keys = "ON"),
      n_chunk_size = 10L,
      flag_replace_existing = TRUE,
      path_schema = path_schema,
      verbose = FALSE
    ),
    regexp = "References"
  )

  testthat::expect_equal(base::readLines(path_database), "old database")
  testthat::expect_true(
    base::file.exists(base::file.path(dir_test, "Vault_work.sqlite"))
  )
  testthat::expect_false(
    base::file.exists(base::file.path(dir_test, "Vault_new.sqlite"))
  )
})

testthat::test_that("save_vegvault_database() never reads or skips rows", {
  vec_body <-
    base::deparse(base::body(save_vegvault_database))

  # The rows are written only by the load into the work file
  testthat::expect_true(
    base::any(
      stringr::str_detect(string = vec_body, pattern = "run_database_load")
    )
  )

  testthat::expect_false(
    base::any(
      stringr::str_detect(
        string = vec_body,
        pattern = stringr::regex(
          "INSERT\\s+OR|SELECT|dbReadTable|collect\\(|dplyr::tbl\\(",
          ignore_case = TRUE
        )
      )
    )
  )
})
