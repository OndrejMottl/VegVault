#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("is_git_clean() validates its input", {
  testthat::expect_error(
    is_git_clean(path_project = c("a", "b")),
    regexp = "path_project"
  )

  testthat::expect_error(
    is_git_clean(
      path_project = base::file.path(base::tempdir(), "missing_folder")
    ),
    regexp = "path_project"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("is_git_clean() follows the state of a checkout", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_repo <-
    withr::local_tempdir()

  vec_git_identity <-
    c(
      "-c", "user.name=Test",
      "-c", "user.email=test@example.com",
      "-c", "core.autocrlf=false"
    )

  base::system2(
    command = "git",
    args = c("-C", base::shQuote(dir_repo), "init", "--quiet"),
    stdout = FALSE,
    stderr = FALSE
  )

  base::writeLines(text = "first", con = base::file.path(dir_repo, "a.R"))

  base::writeLines(
    text = "ignored.txt",
    con = base::file.path(dir_repo, ".gitignore")
  )

  base::system2(
    command = "git",
    args = c("-C", base::shQuote(dir_repo), "add", "--all"),
    stdout = FALSE,
    stderr = FALSE
  )

  base::system2(
    command = "git",
    args = c(
      "-C", base::shQuote(dir_repo), vec_git_identity,
      "commit", "--quiet", "-m", "first"
    ),
    stdout = FALSE,
    stderr = FALSE
  )

  res_committed <-
    is_git_clean(path_project = dir_repo)

  testthat::expect_type(res_committed, "logical")

  testthat::expect_length(res_committed, 1L)

  testthat::expect_true(res_committed)

  # An ignored file does not change the code that runs
  base::writeLines(
    text = "scratch",
    con = base::file.path(dir_repo, "ignored.txt")
  )

  testthat::expect_true(is_git_clean(path_project = dir_repo))

  # An untracked file would be sourced by the setup
  base::writeLines(text = "new", con = base::file.path(dir_repo, "b.R"))

  testthat::expect_false(is_git_clean(path_project = dir_repo))

  base::file.remove(base::file.path(dir_repo, "b.R"))

  testthat::expect_true(is_git_clean(path_project = dir_repo))

  # A modified tracked file
  base::writeLines(text = "second", con = base::file.path(dir_repo, "a.R"))

  testthat::expect_false(is_git_clean(path_project = dir_repo))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("is_git_clean() aborts outside a repository", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_outside <-
    withr::local_tempdir()

  testthat::expect_error(
    is_git_clean(path_project = dir_outside),
    regexp = "git status"
  )
})
