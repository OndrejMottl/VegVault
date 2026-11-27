#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("save_table_csv() exports a table with a header", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  dir_export <-
    withr::local_tempdir()

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  data_datasets <-
    tibble::tibble(
      dataset_id = 1:3,
      dataset_name = c("a", NA, "c, with comma"),
      coord_long = c(10.5, -3.25, NA)
    )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = data_datasets
  )

  res <-
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      ),
      dir_export = base::file.path(dir_export, "Flat_files"),
      path_sqlite3 = resolve_sqlite3_path()
    )

  path_csv <-
    base::file.path(dir_export, "Flat_files", "Datasets.csv")

  testthat::expect_equal(res, path_csv)

  data_read <-
    readr::read_csv(file = path_csv, col_types = "icd")

  # Plain data frames, because readr adds its own class and column spec
  testthat::expect_equal(
    base::as.data.frame(data_read),
    base::as.data.frame(data_datasets)
  )

  # Only the CSV is left in the folder, no temporary file
  testthat::expect_equal(
    base::list.files(base::file.path(dir_export, "Flat_files")),
    "Datasets.csv"
  )
})

testthat::test_that("save_table_csv() ends rows as the v1 export did", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Notes",
    value = base::data.frame(note_id = 1:2, note = c("one", "two"))
  )

  path_csv <-
    save_table_csv(
      path_database = path_database,
      table_name = "Notes",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      ),
      dir_export = withr::local_tempdir(),
      path_sqlite3 = resolve_sqlite3_path()
    )

  text_csv <-
    base::readBin(con = path_csv, what = "raw", n = 1000L) |>
    base::rawToChar()

  testthat::expect_equal(text_csv, "note_id,note\r\n1,one\r\n2,two\r\n")
})

testthat::test_that("save_table_csv() replaces an existing file", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  dir_export <-
    withr::local_tempdir()

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1:2)
  )

  path_csv <-
    base::file.path(dir_export, "Datasets.csv")

  base::writeLines(text = "old content", con = path_csv)

  res <-
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      ),
      dir_export = dir_export,
      path_sqlite3 = resolve_sqlite3_path()
    )

  testthat::expect_equal(res, path_csv)

  testthat::expect_equal(
    base::readLines(con = path_csv),
    c("dataset_id", "1", "2")
  )
})

testthat::test_that("save_table_csv() leaves the database unchanged", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1:2)
  )

  base::Sys.setFileTime(
    path = path_database,
    time = base::as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  )

  vec_md5_before <-
    tools::md5sum(path_database)

  save_table_csv(
    path_database = path_database,
    table_name = "Datasets",
    list_build_manifest = list(
      database = list(file_name = "VegVault.sqlite")
    ),
    dir_export = withr::local_tempdir(),
    path_sqlite3 = resolve_sqlite3_path()
  )

  testthat::expect_equal(tools::md5sum(path_database), vec_md5_before)

  testthat::expect_equal(
    base::as.numeric(base::file.mtime(path_database)),
    base::as.numeric(
      base::as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("save_table_csv() keeps the old file on failure", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  dir_export <-
    withr::local_tempdir()

  dir_private <-
    withr::local_tempdir(pattern = "private_folder_")

  path_database <-
    base::file.path(dir_private, "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  path_csv <-
    base::file.path(dir_export, "Missing.csv")

  base::writeLines(text = "old content", con = path_csv)

  res_error <-
    testthat::expect_error(
      save_table_csv(
        path_database = path_database,
        table_name = "Missing",
        list_build_manifest = list(
          database = list(file_name = "VegVault.sqlite")
        ),
        dir_export = dir_export,
        path_sqlite3 = resolve_sqlite3_path()
      ),
      regexp = "exit status"
    )

  text_message <-
    base::conditionMessage(res_error)

  # sqlite3's own reason is passed on, but never the database path
  testthat::expect_true(
    stringr::str_detect(text_message, "no such table")
  )

  testthat::expect_false(
    stringr::str_detect(text_message, stringr::fixed("private_folder_"))
  )

  testthat::expect_equal(base::readLines(con = path_csv), "old content")

  testthat::expect_equal(base::list.files(dir_export), "Missing.csv")
})

testthat::test_that("save_table_csv() reports a sqlite3 that cannot run", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  dir_export <-
    withr::local_tempdir()

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      ),
      dir_export = dir_export,
      path_sqlite3 = base::file.path(dir_export, "no_sqlite3.exe")
    ),
    regexp = "could not be started"
  )

  testthat::expect_equal(base::list.files(dir_export), base::character(0))
})

testthat::test_that("save_table_csv() aborts when it cannot replace", {
  testthat::skip_if(
    base::Sys.which("sqlite3") == "",
    message = "sqlite3 is not on the PATH"
  )

  dir_export <-
    withr::local_tempdir()

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  # A folder where the CSV should go cannot be replaced by a file
  base::dir.create(base::file.path(dir_export, "Datasets.csv"))

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      ),
      dir_export = dir_export,
      path_sqlite3 = resolve_sqlite3_path()
    ),
    regexp = "could not replace"
  )

  testthat::expect_equal(base::list.files(dir_export), "Datasets.csv")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_table_csv() validates arguments", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  list_manifest <-
    list(database = list(file_name = "VegVault.sqlite"))

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets]; DROP TABLE [Datasets",
      list_build_manifest = list_manifest,
      dir_export = withr::local_tempdir(),
      path_sqlite3 = "sqlite3"
    ),
    regexp = "table_name"
  )

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault_other.sqlite")
      ),
      dir_export = withr::local_tempdir(),
      path_sqlite3 = "sqlite3"
    ),
    regexp = "manifest"
  )

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list_manifest,
      dir_export = withr::local_tempdir(),
      path_sqlite3 = ""
    ),
    regexp = "path_sqlite3"
  )

  testthat::expect_error(
    save_table_csv(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list_manifest,
      dir_export = withr::local_tempdir(),
      path_sqlite3 = "sqlite3"
    ),
    regexp = "does not exist"
  )
})
