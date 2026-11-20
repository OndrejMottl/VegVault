#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("is_git_commit_in_ref() validates its input", {
  dir_repo <-
    withr::local_tempdir()

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = c(dir_repo, dir_repo),
      ref_base = "main"
    ),
    regexp = "path_project"
  )

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = base::file.path(dir_repo, "missing_folder"),
      ref_base = "main"
    ),
    regexp = "path_project"
  )

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = c("main", "feature")
    ),
    regexp = "ref_base"
  )

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = ""
    ),
    regexp = "ref_base"
  )

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = NA_character_
    ),
    regexp = "ref_base"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("is_git_commit_in_ref() follows the branch history", {
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

  base::writeLines(text = "first", con = base::file.path(dir_repo, "a.R"))

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("commit", "--quiet", "-m", "first")
  )

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("checkout", "--quiet", "-b", "feature")
  )

  base::writeLines(text = "second", con = base::file.path(dir_repo, "a.R"))

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("commit", "--quiet", "--all", "-m", "second")
  )

  # The feature commit is not on main
  res_feature_in_main <-
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = "main"
    )

  testthat::expect_type(res_feature_in_main, "logical")

  testthat::expect_length(res_feature_in_main, 1L)

  testthat::expect_false(res_feature_in_main)

  testthat::expect_true(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = "feature"
    )
  )

  # The main commit is an ancestor of the feature branch
  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("checkout", "--quiet", "main")
  )

  testthat::expect_true(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = "feature"
    )
  )

  testthat::expect_true(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = "main"
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("is_git_commit_in_ref() aborts on an unknown ref", {
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

  base::writeLines(text = "first", con = base::file.path(dir_repo, "a.R"))

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = dir_repo,
    vec_args = c("commit", "--quiet", "-m", "first")
  )

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = dir_repo,
      ref_base = "origin/no_such_branch"
    ),
    regexp = "origin/no_such_branch"
  )
})

testthat::test_that("is_git_commit_in_ref() aborts outside a repository", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_outside <-
    withr::local_tempdir()

  testthat::expect_error(
    is_git_commit_in_ref(
      path_project = dir_outside,
      ref_base = "main"
    ),
    regexp = "git"
  )
})
