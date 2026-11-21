#' @title Diagnose the integrity of a database file
#' @description
#' Run SQLite's `integrity_check`, or the shorter `quick_check`, on a built
#' VegVault database, read-only, and report the result as a row of the
#' validation report.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param flag_quick_check
#' Logical scalar. If `FALSE` (default), run the full `integrity_check`.
#' If `TRUE`, run `quick_check`, which skips the comparison of each index
#' with its table and the `UNIQUE` constraints; a database checked this way
#' is not eligible for release (see `diagnose_release_eligibility()`).
#' @return
#' A tibble in the format of `build_check_result()` with one row, check
#' `integrity` and scope `integrity_check` or `quick_check`: `pass` when
#' SQLite returns the single value `ok`, `fail` otherwise. The message
#' gives the runtime in seconds and, on failure, the first problems SQLite
#' reports.
#' @details
#' `integrity_check` reads the whole file and verifies the b-trees, every
#' index against its table and the `UNIQUE`, `CHECK` and `NOT NULL`
#' constraints. It does not check foreign keys (see
#' `diagnose_foreign_keys()`). A file SQLite cannot read fails with the
#' error as the message. Opens the database read-only. Aborts only when
#' the database is not the one of the manifest.
#' @examples
#' \dontrun{
#' diagnose_database_integrity(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_database_integrity <- function(
  path_database,
  list_build_manifest,
  flag_quick_check = FALSE
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  assertthat::assert_that(
    base::is.logical(flag_quick_check),
    base::length(flag_quick_check) == 1L,
    !base::is.na(flag_quick_check),
    msg = "`flag_quick_check` must be TRUE or FALSE."
  )

  name_check <-
    base::ifelse(flag_quick_check, "quick_check", "integrity_check")

  time_start <-
    base::Sys.time()

  # A file SQLite cannot read is a failed check, not an error of the stage
  data_problems <-
    tryCatch(
      run_with_database(
        path_database = path_database,
        fn = DBI::dbGetQuery,
        statement = stringr::str_c("PRAGMA ", name_check),
        flag_read_only = TRUE
      ),
      error = function(cnd) cnd
    )

  seconds <-
    base::difftime(base::Sys.time(), time_start, units = "secs") |>
    base::as.numeric() |>
    base::round(digits = 1L)

  vec_problems <-
    if (
      rlang::is_condition(data_problems)
    ) {
      base::conditionMessage(data_problems) |>
        stringr::str_squish()
    } else {
      dplyr::pull(data_problems, 1L)
    }

  flag_ok <-
    base::identical(vec_problems, "ok")

  res <-
    if (
      flag_ok
    ) {
      build_check_result(
        check_id = "integrity",
        scope = name_check,
        status = "pass",
        observed = "ok",
        threshold = "ok",
        message = stringr::str_c(
          name_check, " returned ok in ", seconds, " s."
        )
      )
    } else {
      build_check_result(
        check_id = "integrity",
        scope = name_check,
        status = "fail",
        observed = base::length(vec_problems),
        threshold = "ok",
        message = stringr::str_c(
          name_check, " found ", base::length(vec_problems),
          " problems in ", seconds, " s; the first: ",
          stringr::str_c(utils::head(vec_problems, n = 5L), collapse = "; ")
        )
      )
    }

  return(res)
}
