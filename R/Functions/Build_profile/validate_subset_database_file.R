#' @title Validate the database file of the subset profile
#' @description
#' Check that the disposable database of the regional `subset` profile is
#' named by a relative path that stays under the data root, so that a
#' rehearsal build can never write to a database outside it.
#' @param database_file
#' Character scalar. The `database_file` value of the `subset` section of
#' `config.yml`, relative to the data root.
#' @return
#' `database_file`, unchanged and invisibly.
#' @details
#' Aborts when the value is not a non-empty text value, when it is an
#' absolute path or starts with a drive letter, or when it contains a `..`
#' segment, which could lead out of the data root.
#' @examples
#' \dontrun{
#' validate_subset_database_file(
#'   database_file = "Temp/Subset/VegVault_subset.sqlite"
#' )
#' }
validate_subset_database_file <- function(database_file) {
  if (
    !base::is.character(database_file) ||
      base::length(database_file) != 1L ||
      base::is.na(database_file) ||
      !base::nzchar(database_file)
  ) {
    cli::cli_abort(
      "{.field database_file} of the subset must be a non-empty text
      value."
    )
  }

  # A leading slash, backslash or drive letter (also "D:file") leaves the
  #   data root
  if (
    stringr::str_detect(database_file, "^([A-Za-z]:|[/\\\\])")
  ) {
    cli::cli_abort(
      "{.field database_file} of the subset must be a relative path; it
      is resolved under the data root."
    )
  }

  if (
    stringr::str_detect(database_file, "(^|[/\\\\])[.][.]([/\\\\]|$)")
  ) {
    cli::cli_abort(
      "{.field database_file} of the subset must stay under the data root;
      a {.val ..} folder is not allowed."
    )
  }

  res <- database_file

  return(invisible(res))
}
