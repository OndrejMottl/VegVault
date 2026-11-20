#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("run_git_fixture_command() validates its input", {
  dir_repo <-
    withr::local_tempdir()

  testthat::expect_error(
    run_git_fixture_command(
      path_repo = base::file.path(dir_repo, "missing_folder"),
      vec_args = "status"
    ),
    regexp = "path_repo"
  )

  testthat::expect_error(
    run_git_fixture_command(
      path_repo = c(dir_repo, dir_repo),
      vec_args = "status"
    ),
    regexp = "path_repo"
  )

  testthat::expect_error(
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = character(0)
    ),
    regexp = "vec_args"
  )

  testthat::expect_error(
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("status", NA_character_)
    ),
    regexp = "vec_args"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("run_git_fixture_command() commits as the test user", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_repo <-
    withr::local_tempdir()

  res_init <-
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("init", "--quiet", "--initial-branch=main")
    )

  testthat::expect_type(res_init, "character")

  testthat::expect_true(base::dir.exists(base::file.path(dir_repo, ".git")))

  base::writeLines(text = "first", con = base::file.path(dir_repo, "a.R"))

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("commit", "--quiet", "-m", "first")
  )

  res_author <-
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("log", "--format=%an <%ae>")
    )

  testthat::expect_equal(res_author, "Test <test@example.com>")

  res_autocrlf <-
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("config", "--get", "core.autocrlf")
    )

  testthat::expect_equal(res_autocrlf, "false")
})

testthat::test_that("run_git_fixture_command() returns invisibly", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_repo <-
    withr::local_tempdir()

  testthat::expect_invisible(
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("init", "--quiet")
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("run_git_fixture_command() aborts when git fails", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_repo <-
    withr::local_tempdir()

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("init", "--quiet", "--initial-branch=main")
  )

  testthat::expect_error(
    run_git_fixture_command(
      path_repo = dir_repo,
      vec_args = c("checkout", "--quiet", "no_such_branch")
    ),
    regexp = "no_such_branch"
  )
})
