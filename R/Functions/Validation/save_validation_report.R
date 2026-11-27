#' @title Save the validation report of a database build
#' @description
#' Write the results of the validation checks of one database build as a
#' table and as a short summary that a reviewer can read.
#' @param data_checks
#' A tibble in the format of `build_check_result()`: every check result of
#' the build.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @param dir_output
#' Character scalar. Folder that receives the report; it is created when
#' missing.
#' @return
#' Character vector of the two files written, so that the function can be
#' the command of a `{targets}` target with `format = "file"`:
#' \itemize{
#'   \item `validation_checks_<build id>.csv`: `data_checks`, one row per
#'     check and scope;
#'   \item `validation_summary_<build id>.md`: the build, whether it is
#'     eligible for release, the number of results per status, and every
#'     failed and flagged result.
#' }
#' @details
#' The build identifier comes from `build_validation_id()`, so the report
#' of another build never replaces this one; a report of the same build is
#' replaced. Missing values are written as empty fields. The release
#' eligibility is read from the row of check `release_eligibility`; without
#' that row the build counts as not eligible. Aborts when `data_checks`
#' does not have the columns of `build_check_result()`.
#' @examples
#' \dontrun{
#' save_validation_report(
#'   data_checks = data_checks,
#'   list_build_manifest = list_build_manifest,
#'   dir_output = here::here("Outputs", "Tables")
#' )
#' }
save_validation_report <- function(
  data_checks,
  list_build_manifest,
  dir_output
) {
  vec_columns <-
    c("check_id", "scope", "status", "observed", "threshold", "message")

  assertthat::assert_that(
    base::is.data.frame(data_checks),
    base::identical(base::names(data_checks), vec_columns),
    msg = stringr::str_c(
      "`data_checks` must be check results with the columns of ",
      "build_check_result()."
    )
  )

  assertthat::assert_that(
    base::is.character(dir_output),
    base::length(dir_output) == 1L,
    msg = "`dir_output` must be the path of a folder."
  )

  id_build <-
    build_validation_id(list_build_manifest = list_build_manifest)

  base::dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

  path_checks <-
    base::file.path(
      dir_output,
      stringr::str_c("validation_checks_", id_build, ".csv")
    )

  path_summary <-
    base::file.path(
      dir_output,
      stringr::str_c("validation_summary_", id_build, ".md")
    )

  readr::write_csv(x = data_checks, file = path_checks, na = "")

  flag_eligible <-
    data_checks |>
    dplyr::filter(check_id == "release_eligibility", status == "pass") |>
    base::nrow() > 0L

  vec_counts <-
    purrr::map_int(
      .x = c("pass", "fail", "flag"),
      .f = ~ base::sum(dplyr::pull(data_checks, status) == .x)
    )

  # One list line per result of the given status
  vec_lines_failed <-
    data_checks |>
    dplyr::filter(status == "fail") |>
    dplyr::mutate(
      line = stringr::str_c("- `", check_id, "` (", scope, "): ", message)
    ) |>
    dplyr::pull(line)

  vec_lines_flagged <-
    data_checks |>
    dplyr::filter(status == "flag") |>
    dplyr::mutate(
      line = stringr::str_c("- `", check_id, "` (", scope, "): ", message)
    ) |>
    dplyr::pull(line)

  vec_summary <-
    c(
      stringr::str_c(
        "# Validation of VegVault ",
        purrr::pluck(list_build_manifest, "version", "version")
      ),
      "",
      stringr::str_c("- Build: ", id_build),
      stringr::str_c(
        "- Profile: ", purrr::pluck(list_build_manifest, "profile"),
        "; commit ", purrr::pluck(list_build_manifest, "git_commit"),
        "; built ", purrr::pluck(list_build_manifest, "build_time_utc")
      ),
      stringr::str_c(
        "- Release eligible: ", base::ifelse(flag_eligible, "yes", "no")
      ),
      stringr::str_c(
        "- Results: ", vec_counts[1], " pass, ", vec_counts[2], " fail, ",
        vec_counts[3], " flag"
      ),
      "",
      "## Failed checks",
      "",
      if (base::length(vec_lines_failed) > 0L) vec_lines_failed else "None.",
      "",
      "## Flagged for review",
      "",
      if (base::length(vec_lines_flagged) > 0L) vec_lines_flagged else "None."
    )

  readr::write_lines(x = vec_summary, file = path_summary)

  res <-
    c(path_checks, path_summary)

  return(res)
}
