#' @title Build rows of the validation report
#' @description
#' Build rows of the validation report of a VegVault database in its one
#' format: one row per check and scope, with a status, the observed value,
#' the threshold and a message.
#' @param check_id
#' Character scalar. Identifier of the check, for example `"schema"` or
#' `"foreign_keys"`.
#' @param scope
#' Character vector. What each row covers, for example a table, a variable
#' or a field of the version row.
#' @param status
#' Character vector. `"pass"`, `"fail"` or `"flag"`. A failed check blocks
#' the release; a flagged one asks a reviewer for a judgement.
#' @param observed
#' Vector of observed values, stored as text. Default: missing.
#' @param threshold
#' Vector of thresholds or expected values, stored as text. Default:
#' missing.
#' @param message
#' Character vector. What the row means, in one sentence.
#' @return
#' A tibble with the character columns `check_id`, `scope`, `status`,
#' `observed`, `threshold` and `message`, one row per element of the
#' longest argument; arguments of length one are recycled.
#' @details
#' Aborts when `check_id` is not one non-empty text value, when a status is
#' not one of the three allowed values, or when the arguments have
#' different lengths other than one.
#' @examples
#' \dontrun{
#' build_check_result(
#'   check_id = "foreign_keys",
#'   scope = "database",
#'   status = "pass",
#'   observed = 0L,
#'   threshold = 0L,
#'   message = "Every foreign key has its parent row."
#' )
#' }
build_check_result <- function(
  check_id,
  scope,
  status,
  observed = NA_character_,
  threshold = NA_character_,
  message
) {
  assertthat::assert_that(
    base::is.character(check_id),
    base::length(check_id) == 1L,
    !base::is.na(check_id),
    base::nchar(check_id) > 0L,
    msg = "`check_id` must be one non-empty text value."
  )

  vec_status_allowed <-
    c("pass", "fail", "flag")

  assertthat::assert_that(
    base::is.character(status),
    base::length(status) > 0L,
    base::all(status %in% vec_status_allowed),
    msg = "`status` must hold only \"pass\", \"fail\" or \"flag\"."
  )

  # tibble() recycles length-one columns and refuses other mismatches
  res <-
    tibble::tibble(
      check_id = check_id,
      scope = base::as.character(scope),
      status = status,
      observed = base::as.character(observed),
      threshold = base::as.character(threshold),
      message = base::as.character(message)
    )

  return(res)
}
