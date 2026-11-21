#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

data_test_deltas <-
  tibble::tribble(
    ~metric, ~scope, ~n_v1, ~n_v2, ~delta, ~relative_change, ~status,
    ~expected_reason, ~note,
    "table_rows", "Samples", 100, 104, 4, 0.04, "pass", NA, NA,
    "table_rows", "Positions", NA, 7, NA, NA, "flag", "New tables.", NA
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_v1_count_deltas() writes the build's file", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  dir_output <-
    base::file.path(withr::local_tempdir(), "Report")

  res <-
    save_v1_count_deltas(
      data_deltas = data_test_deltas,
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      dir_output = dir_output
    )

  testthat::expect_true(base::file.exists(res))

  testthat::expect_equal(
    base::basename(res),
    stringr::str_c(
      "validation_v1_deltas_",
      build_validation_id(
        list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
      ),
      ".csv"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_v1_count_deltas() keeps the table", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    save_v1_count_deltas(
      data_deltas = data_test_deltas,
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      dir_output = withr::local_tempdir()
    )

  data_read <-
    readr::read_csv(res, show_col_types = FALSE) |>
    tibble::as_tibble()

  testthat::expect_equal(
    data_read,
    dplyr::mutate(data_test_deltas, note = base::as.logical(note)),
    ignore_attr = TRUE
  )

  # Missing values are empty fields
  testthat::expect_match(base::readLines(res)[3], "^table_rows,Positions,,7,")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_v1_count_deltas() needs a table of changes", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    save_v1_count_deltas(
      data_deltas = dplyr::select(data_test_deltas, -delta),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      dir_output = withr::local_tempdir()
    ),
    regexp = "data_deltas"
  )
})
