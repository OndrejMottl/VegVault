#' @title Load the current git commit of the project
#' @description
#' Return the full hash of the commit checked out in a git repository,
#' recorded in the build manifest as the code that built the database.
#' @param path_project
#' Character scalar. A folder inside the git repository. Defaults to the
#' project root.
#' @return
#' Character scalar. The 40-character hexadecimal commit hash.
#' @details
#' Calls the `git` executable. Aborts when `git` is not available, when
#' `path_project` is not inside a git repository, or when the repository
#' has no commit yet.
#' @examples
#' \dontrun{
#' git_commit <- load_git_commit()
#' }
load_git_commit <- function(path_project = here::here()) {
  assertthat::assert_that(
    base::is.character(path_project),
    base::length(path_project) == 1L,
    !base::is.na(path_project),
    base::dir.exists(path_project),
    msg = "`path_project` must be the path of an existing folder."
  )

  vec_message_failed <-
    c(
      "Could not read the git commit of the project.",
      "i" = "Run the build from a git checkout with at least one commit."
    )

  # git reports a failure as a non-zero status, which system2() turns into
  #   a warning; both that and a missing executable stop the build
  vec_output <-
    base::tryCatch(
      expr = base::system2(
        command = "git",
        args = c(
          "-C",
          base::shQuote(path_project),
          "rev-parse",
          "--verify",
          "HEAD"
        ),
        stdout = TRUE,
        stderr = FALSE
      ),
      warning = function(cnd) {
        cli::cli_abort(vec_message_failed)
      },
      error = function(cnd) {
        cli::cli_abort(vec_message_failed)
      }
    )

  res <-
    stringr::str_trim(vec_output)

  if (
    base::length(res) != 1L ||
      !stringr::str_detect(res, "^[0-9a-f]{40}$")
  ) {
    cli::cli_abort(vec_message_failed)
  }

  return(res)
}
