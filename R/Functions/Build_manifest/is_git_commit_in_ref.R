#' @title Is the checked-out commit contained in a git reference
#' @description
#' Report whether the commit checked out in a git repository is reachable
#' from a reference such as `origin/2.0.0`, that is, whether it is the
#' commit of that reference or one of its ancestors. A commit that exists
#' only on a feature branch disappears from the shared history after a
#' squash merge, so a record that cites it cannot be reproduced later.
#' @param path_project
#' Character scalar. A folder inside the git repository. Defaults to the
#' project root.
#' @param ref_base
#' Character scalar. A reference git can resolve to a commit: a branch, a
#' remote-tracking branch such as `"origin/2.0.0"`, a tag or a commit hash.
#' @return
#' Logical scalar. `TRUE` when `HEAD` is reachable from `ref_base`,
#' `FALSE` otherwise.
#' @details
#' Runs `git merge-base --is-ancestor HEAD <ref_base>`. A remote-tracking
#' reference is only as recent as the last `git fetch`, so a commit merged
#' after that fetch is reported as not contained. Calls the `git`
#' executable and aborts when it is not available, when `path_project` is
#' not inside a git repository or when `ref_base` does not resolve to a
#' commit.
#' @examples
#' \dontrun{
#' is_git_commit_in_ref(ref_base = "origin/2.0.0")
#' }
is_git_commit_in_ref <- function(
  path_project = here::here(),
  ref_base
) {
  assertthat::assert_that(
    base::is.character(path_project),
    base::length(path_project) == 1L,
    !base::is.na(path_project),
    base::dir.exists(path_project),
    msg = "`path_project` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.character(ref_base),
    base::length(ref_base) == 1L,
    !base::is.na(ref_base),
    base::nzchar(ref_base),
    msg = "`ref_base` must be a non-empty character scalar."
  )

  # With stdout and stderr discarded, system2() returns git's exit status:
  #   rev-parse gives 0 for a commit; merge-base --is-ancestor gives 0 for
  #   an ancestor, 1 for a commit that is not one, and another value for an
  #   error. A missing executable is an error or a warning.
  status_ref <-
    base::tryCatch(
      expr = base::system2(
        command = "git",
        args = c(
          "-C",
          base::shQuote(path_project),
          "rev-parse",
          "--verify",
          "--quiet",
          base::shQuote(stringr::str_c(ref_base, "^{commit}"))
        ),
        stdout = FALSE,
        stderr = FALSE
      ),
      warning = function(cnd) {
        -1L
      },
      error = function(cnd) {
        -1L
      }
    )

  if (
    !base::identical(base::as.integer(status_ref), 0L)
  ) {
    cli::cli_abort(
      c(
        "git cannot resolve {.val {ref_base}} to a commit.",
        "i" = stringr::str_c(
          "Check that {.path {path_project}} is a git checkout, that git ",
          "is installed and that `ref_base` exists (run {.code git fetch} ",
          "for a remote-tracking branch)."
        )
      )
    )
  }

  status_ancestor <-
    base::tryCatch(
      expr = base::system2(
        command = "git",
        args = c(
          "-C",
          base::shQuote(path_project),
          "merge-base",
          "--is-ancestor",
          "HEAD",
          base::shQuote(ref_base)
        ),
        stdout = FALSE,
        stderr = FALSE
      ),
      warning = function(cnd) {
        -1L
      },
      error = function(cnd) {
        -1L
      }
    )

  if (
    !base::as.integer(status_ancestor) %in% c(0L, 1L)
  ) {
    cli::cli_abort(
      c(
        "git could not compare HEAD with {.val {ref_base}}.",
        "i" = "Folder: {.path {path_project}}"
      )
    )
  }

  res <-
    base::identical(base::as.integer(status_ancestor), 0L)

  return(res)
}
