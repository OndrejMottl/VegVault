#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_export_dir() resolves under the project", {
  dir_project <-
    withr::local_tempdir()

  res <-
    resolve_export_dir(
      path_relative = "Outputs/Data/VegVault/Flat_files",
      path_project = dir_project
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(
    res,
    base::normalizePath(
      base::file.path(dir_project, "Outputs/Data/VegVault/Flat_files"),
      winslash = "/",
      mustWork = FALSE
    )
  )

  # The folder is only resolved, not created
  testthat::expect_false(base::dir.exists(res))
})

testthat::test_that("resolve_export_dir() reads the project setting", {
  res <-
    resolve_export_dir()

  testthat::expect_true(
    stringr::str_starts(
      res,
      base::normalizePath(here::here(), winslash = "/")
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("resolve_export_dir() stays inside the project", {
  dir_project <-
    withr::local_tempdir()

  vec_outside <-
    c(
      "D:/Exports",
      "D:\\Exports",
      "/home/exports",
      "D:Exports",
      "../Exports",
      "Outputs/../../Exports"
    )

  purrr::walk(
    .x = vec_outside,
    .f = ~ testthat::expect_error(
      resolve_export_dir(path_relative = .x, path_project = dir_project),
      regexp = "output_dir"
    )
  )
})

testthat::test_that("resolve_export_dir() validates its input", {
  testthat::expect_error(
    resolve_export_dir(path_relative = "", path_project = "."),
    regexp = "output_dir"
  )

  testthat::expect_error(
    resolve_export_dir(path_relative = c("a", "b"), path_project = "."),
    regexp = "output_dir"
  )

  testthat::expect_error(
    resolve_export_dir(path_relative = "a", path_project = 1),
    regexp = "path_project"
  )
})
