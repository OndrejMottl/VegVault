#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_remote_artefact() reads an RDS file", {
  data_example <-
    tibble::tibble(taxon = c("Picea", "Quercus"), value = c(1, 2))

  path_source <-
    base::file.path(withr::local_tempdir(), "example_artefact.rds")

  readr::write_rds(x = data_example, file = path_source)

  url_source <-
    stringr::str_c(
      "file:///",
      base::normalizePath(path_source, winslash = "/")
    )

  res <-
    load_remote_artefact(sel_url = url_source)

  testthat::expect_equal(res, data_example)
})

testthat::test_that("load_remote_artefact() reads a qs2 file as .qs", {
  data_example <-
    tibble::tibble(taxon = c("Picea", "Quercus"), value = c(1, 2))

  path_source <-
    base::file.path(withr::local_tempdir(), "example_artefact.qs")

  qs2::qs_save(object = data_example, file = path_source)

  url_source <-
    stringr::str_c(
      "file:///",
      base::normalizePath(path_source, winslash = "/")
    )

  res <-
    load_remote_artefact(sel_url = url_source)

  testthat::expect_equal(res, data_example)
})
