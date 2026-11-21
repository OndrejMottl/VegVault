#' @title Diagnose whether a database build may be released
#' @description
#' Decide from the build manifest and the results of the other checks
#' whether a built VegVault database is eligible for release.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @param data_checks
#' A tibble in the format of `build_check_result()`: the results of the
#' other checks of the database.
#' @return
#' A tibble in the format of `build_check_result()` with one row, check
#' `release_eligibility` and scope `build`: `pass` with the observed value
#' `TRUE` when the build may be released, otherwise `flag` with `FALSE`
#' and every reason in the message.
#' @details
#' A build is eligible only when all of these hold:
#' \itemize{
#'   \item it used the `release` profile, with the subset disabled and a
#'     clean checkout;
#'   \item no check failed;
#'   \item the full `integrity_check` ran and passed, not only
#'     `quick_check`.
#' }
#' A development or subset build is marked not eligible even when every
#' check passes; that is a flag, not a failure, because such builds are
#' checked for other reasons.
#' @examples
#' \dontrun{
#' diagnose_release_eligibility(
#'   list_build_manifest = list_build_manifest,
#'   data_checks = data_checks_database
#' )
#' }
diagnose_release_eligibility <- function(
  list_build_manifest,
  data_checks
) {
  assertthat::assert_that(
    base::is.data.frame(data_checks),
    base::all(c("check_id", "scope", "status") %in% base::names(data_checks)),
    msg = stringr::str_c(
      "`data_checks` must be check results with the columns `check_id`, ",
      "`scope` and `status` (see build_check_result())."
    )
  )

  assertthat::assert_that(
    base::is.list(list_build_manifest),
    base::all(
      c("profile", "subset", "git_clean") %in% base::names(list_build_manifest)
    ),
    msg = stringr::str_c(
      "`list_build_manifest` must be a build manifest with `profile`, ",
      "`subset` and `git_clean` (see load_build_manifest())."
    )
  )

  profile <-
    purrr::chuck(list_build_manifest, "profile")

  flag_subset <-
    base::isTRUE(purrr::pluck(list_build_manifest, "subset", "enabled"))

  n_failed <-
    base::sum(dplyr::pull(data_checks, status) == "fail")

  flag_full_integrity <-
    data_checks |>
    dplyr::filter(
      check_id == "integrity",
      scope == "integrity_check",
      status == "pass"
    ) |>
    base::nrow() > 0L

  vec_reasons <-
    c(
      if (!base::identical(profile, "release")) {
        stringr::str_c("the build used the ", profile, " profile")
      },
      if (flag_subset) {
        "the subset was enabled"
      },
      if (!base::isTRUE(purrr::chuck(list_build_manifest, "git_clean"))) {
        "the checkout was not clean"
      },
      if (n_failed > 0L) {
        stringr::str_c(
          n_failed, " check", base::ifelse(n_failed == 1L, "", "s"),
          " failed"
        )
      },
      if (!flag_full_integrity) {
        "the full integrity_check did not run or did not pass"
      }
    )

  flag_eligible <-
    base::length(vec_reasons) == 0L

  res <-
    build_check_result(
      check_id = "release_eligibility",
      scope = "build",
      status = base::ifelse(flag_eligible, "pass", "flag"),
      observed = flag_eligible,
      threshold = TRUE,
      message = if (flag_eligible) {
        "The build is eligible for release."
      } else {
        stringr::str_c(
          "Not eligible for release: ",
          stringr::str_c(vec_reasons, collapse = "; "),
          "."
        )
      }
    )

  return(res)
}
