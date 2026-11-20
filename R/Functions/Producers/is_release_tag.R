#' @title Test whether a value is a release tag
#' @description
#' Check that a value is one semantic-version tag of the form
#' `v<major>.<minor>.<patch>`, the only form a release build accepts for a
#' producer artefact.
#' @param tag
#' Any R object.
#' @return
#' Logical scalar: `TRUE` for a character scalar such as `"v2.0.0"`,
#' otherwise `FALSE` (also for branch names such as `"main"`, for suffixed
#' tags such as `"v1.0.0-zenodo"`, for `NA` and for `NULL`).
#' @examples
#' \dontrun{
#' is_release_tag(tag = "v2.0.0")
#' }
is_release_tag <- function(tag) {
  res <-
    base::is.character(tag) &&
    base::length(tag) == 1L &&
    !base::is.na(tag) &&
    # \z is the absolute end; $ would also match before a final newline
    stringr::str_detect(tag, "^v[0-9]+[.][0-9]+[.][0-9]+\\z")

  return(res)
}
