#' @title Is the git checkout of the project clean
#' @description
#' Report whether a git checkout has no uncommitted changes and no
#' untracked files, so that its commit hash fully describes the code that
#' runs. Recorded in the build manifest; a release build requires it.
#' @param path_project
#' Character scalar. A folder inside the git repository. Defaults to the
#' project root.
#' @param vec_paths
#' Character vector or `NULL` (default). Paths relative to `path_project`
#' that limit the check, for example `c("R/Functions/Contracts",
#' "Data/Contracts")`. `NULL` checks the whole checkout.
#' @return
#' Logical scalar. `TRUE` when `git status --porcelain` lists nothing,
#' `FALSE` when any tracked file is modified, staged or deleted, or when
#' an untracked file that git does not ignore exists. With `vec_paths`,
#' only changes under those paths count.
#' @details
#' Untracked files count as changes, because the project setup sources
#' every file under `R/Functions/`, committed or not. Files ignored through
#' `.gitignore` do not count. A path in `vec_paths` that does not exist
#' holds no changes. Calls the `git` executable and aborts when it is not
#' available or `path_project` is not inside a git repository.
#' @examples
#' \dontrun{
#' flag_git_clean <- is_git_clean()
#' }
is_git_clean <- function(
  path_project = here::here(),
  vec_paths = NULL
) {
  assertthat::assert_that(
    base::is.character(path_project),
    base::length(path_project) == 1L,
    !base::is.na(path_project),
    base::dir.exists(path_project),
    msg = "`path_project` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.null(vec_paths) ||
      (
        base::is.character(vec_paths) &&
          base::length(vec_paths) > 0L &&
          !base::anyNA(vec_paths)
      ),
    msg = stringr::str_c(
      "`vec_paths` must be NULL or a non-empty character vector ",
      "without NA."
    )
  )

  # git takes the paths after `--`, relative to the folder given by `-C`
  vec_args_paths <-
    if (
      base::is.null(vec_paths)
    ) {
      base::character(0)
    } else {
      c("--", base::shQuote(vec_paths))
    }

  vec_message_failed <-
    c(
      "Could not read the git status of the project.",
      "i" = "Run the build from a git checkout."
    )

  # git reports a failure as a non-zero status, which system2() turns into
  #   a warning; both that and a missing executable stop the build
  vec_changes <-
    base::tryCatch(
      expr = base::system2(
        command = "git",
        args = c(
          "-C",
          base::shQuote(path_project),
          "status",
          "--porcelain",
          vec_args_paths
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
    base::length(vec_changes) == 0L

  return(res)
}
