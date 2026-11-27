#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_sqlite3_path() returns an existing file", {
  path_fake <-
    base::file.path(withr::local_tempdir(), "sqlite3.exe")

  base::writeLines(text = "fake", con = path_fake)

  res <-
    resolve_sqlite3_path(path_candidate = path_fake)

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(
    res,
    base::normalizePath(path_fake, winslash = "/")
  )
})

testthat::test_that("resolve_sqlite3_path() keeps names from Sys.which()", {
  path_fake <-
    base::file.path(withr::local_tempdir(), "sqlite3.exe")

  base::writeLines(text = "fake", con = path_fake)

  res <-
    resolve_sqlite3_path(
      path_candidate = c(sqlite3 = path_fake)
    )

  testthat::expect_null(base::names(res))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("resolve_sqlite3_path() aborts when it is missing", {
  testthat::expect_error(
    resolve_sqlite3_path(path_candidate = c(sqlite3 = "")),
    regexp = "winget"
  )

  testthat::expect_error(
    resolve_sqlite3_path(
      path_candidate = base::file.path(base::tempdir(), "no_sqlite3.exe")
    ),
    regexp = "sqlite3"
  )
})

testthat::test_that("resolve_sqlite3_path() validates its input", {
  testthat::expect_error(
    resolve_sqlite3_path(path_candidate = c("a", "b")),
    regexp = "path_candidate"
  )

  testthat::expect_error(
    resolve_sqlite3_path(path_candidate = NA_character_),
    regexp = "path_candidate"
  )
})
