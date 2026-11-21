#' @title Validate that no check of a database build failed
#' @description
#' Stop the validation stage when any check of the database failed, after
#' its report is written.
#' @param data_checks
#' A tibble in the format of `build_check_result()`: every check result of
#' the build.
#' @param vec_paths_report
#' Character vector. The files of the saved report (see
#' `save_validation_report()`); their names are given in the error
#' message, and passing them makes `{targets}` run this check after the
#' report is written.
#' @return
#' `TRUE`, invisibly, when no result has the status `fail`. Flagged results
#' do not stop the stage; they are listed in the report for review.
#' @details
#' Aborts with one line per failed result (check and scope) and the file
#' names of the report, never their folders.
#' @examples
#' \dontrun{
#' validate_database_checks(
#'   data_checks = data_checks,
#'   vec_paths_report = file_validation_report
#' )
#' }
validate_database_checks <- function(
  data_checks,
  vec_paths_report
) {
  assertthat::assert_that(
    base::is.data.frame(data_checks),
    base::all(c("check_id", "scope", "status") %in% base::names(data_checks)),
    msg = stringr::str_c(
      "`data_checks` must be check results with the columns `check_id`, ",
      "`scope` and `status` (see build_check_result())."
    )
  )

  data_failed <-
    dplyr::filter(data_checks, status == "fail")

  if (
    base::nrow(data_failed) > 0L
  ) {
    vec_failed <-
      stringr::str_c(
        dplyr::pull(data_failed, check_id), " (",
        dplyr::pull(data_failed, scope), ")"
      ) |>
      rlang::set_names(nm = ~ base::rep("x", base::length(.x)))

    vec_files <-
      base::basename(vec_paths_report)

    cli::cli_abort(
      c(
        "{base::nrow(data_failed)} validation check{?s} of the database
        failed:",
        vec_failed,
        "i" = "See the report {.file {vec_files}}."
      )
    )
  }

  res <-
    TRUE

  return(base::invisible(res))
}
