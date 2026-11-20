#' @title Run a git command in a test repository
#' @description
#' Run one git command in a repository that a test creates, with a fixed
#' author identity and without line-ending conversion, so that commits
#' work on any machine and committed files keep the bytes the test wrote.
#' @param path_repo
#' Character scalar. Existing folder in which git runs (`git -C`).
#' @param vec_args
#' Character vector. The git arguments, for example
#' `c("commit", "--quiet", "-m", "first")`.
#' @return
#' Invisibly, a character vector with the lines git printed.
#' @details
#' Prepends `-c user.name=Test -c user.email=test@example.com
#' -c core.autocrlf=false` to every command and quotes every argument.
#' Aborts, naming the git arguments, when git is not available or exits
#' with a non-zero status. Meant for tests only; never point it at a real
#' checkout.
#' @examples
#' \dontrun{
#' run_git_fixture_command(
#'   path_repo = dir_repo,
#'   vec_args = c("init", "--quiet", "--initial-branch=main")
#' )
#' }
run_git_fixture_command <- function(
  path_repo,
  vec_args
) {
  assertthat::assert_that(
    base::is.character(path_repo),
    base::length(path_repo) == 1L,
    !base::is.na(path_repo),
    base::dir.exists(path_repo),
    msg = "`path_repo` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.character(vec_args),
    base::length(vec_args) > 0L,
    !base::anyNA(vec_args),
    msg = "`vec_args` must be a non-empty character vector without NA."
  )

  vec_git_identity <-
    c(
      "-c", "user.name=Test",
      "-c", "user.email=test@example.com",
      "-c", "core.autocrlf=false"
    )

  text_command <-
    stringr::str_flatten(vec_args, collapse = " ")

  vec_message_failed <-
    c(
      "git command failed: {.code git {text_command}}",
      "i" = "Folder: {.path {path_repo}}"
    )

  # git reports a failure as a non-zero status, which system2() turns into
  #   a warning; both that and a missing executable stop the test
  res <-
    base::tryCatch(
      expr = base::system2(
        command = "git",
        args = base::shQuote(
          c("-C", path_repo, vec_git_identity, vec_args)
        ),
        stdout = TRUE,
        stderr = TRUE
      ),
      warning = function(cnd) {
        cli::cli_abort(vec_message_failed)
      },
      error = function(cnd) {
        cli::cli_abort(vec_message_failed)
      }
    )

  return(invisible(res))
}
