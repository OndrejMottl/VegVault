#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_git_commit() validates its input", {
  testthat::expect_error(
    load_git_commit(path_project = c("a", "b")),
    regexp = "path_project"
  )

  testthat::expect_error(
    load_git_commit(
      path_project = base::file.path(base::tempdir(), "missing_folder")
    ),
    regexp = "path_project"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_git_commit() returns the project commit", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  res <-
    load_git_commit(path_project = here::here())

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^[0-9a-f]{40}$")
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_git_commit() aborts outside a repository", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_outside <-
    withr::local_tempdir()

  testthat::expect_error(
    load_git_commit(path_project = dir_outside),
    regexp = "git commit"
  )
})
