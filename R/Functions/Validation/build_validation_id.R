#' @title Build the identifier of a database build for its report
#' @description
#' Build the text that names the validation report of one database build,
#' from its build manifest, so that reports of different builds never
#' overwrite each other.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @return
#' Character scalar `<version>_<profile>_<commit>_<build time>`: the
#' database version, the profile, the first seven characters of the git
#' commit and the build time in UTC as `YYYYMMDDTHHMMSSZ`, for example
#' `2.0.0_default_1a2b3c4_20261121T101500Z`.
#' @details
#' Aborts when the manifest lacks one of the four fields or when the
#' version, profile or commit hold characters other than letters, digits,
#' dots, hyphens and underscores, which could not be part of a file name.
#' @examples
#' \dontrun{
#' build_validation_id(list_build_manifest = list_build_manifest)
#' }
build_validation_id <- function(list_build_manifest) {
  assertthat::assert_that(
    base::is.list(list_build_manifest),
    msg = "`list_build_manifest` must be a build manifest (a list)."
  )

  list_fields <-
    base::list(
      version = purrr::pluck(list_build_manifest, "version", "version"),
      profile = purrr::pluck(list_build_manifest, "profile"),
      git_commit = purrr::pluck(list_build_manifest, "git_commit"),
      build_time_utc = purrr::pluck(list_build_manifest, "build_time_utc")
    )

  vec_missing <-
    list_fields |>
    purrr::keep(
      .p = ~ !base::is.character(.x) || base::length(.x) != 1L ||
        base::is.na(.x) || .x == ""
    ) |>
    base::names()

  if (
    base::length(vec_missing) > 0L
  ) {
    cli::cli_abort(
      "The build manifest lacks {.field {vec_missing}}."
    )
  }

  vec_unsafe <-
    list_fields[c("version", "profile", "git_commit")] |>
    purrr::discard(.p = ~ stringr::str_detect(.x, "^[A-Za-z0-9._-]+$")) |>
    base::names()

  if (
    base::length(vec_unsafe) > 0L
  ) {
    cli::cli_abort(
      "{.field {vec_unsafe}} of the build manifest cannot be part of a
      file name."
    )
  }

  pattern_time <-
    "^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z$"

  time_build <-
    purrr::chuck(list_fields, "build_time_utc")

  if (
    !stringr::str_detect(time_build, pattern_time)
  ) {
    cli::cli_abort(
      "{.field build_time_utc} of the build manifest must be
      YYYY-MM-DDTHH:MM:SSZ."
    )
  }

  time_compact <-
    stringr::str_remove_all(time_build, "[-:]")

  res <-
    stringr::str_c(
      purrr::chuck(list_fields, "version"),
      purrr::chuck(list_fields, "profile"),
      stringr::str_sub(purrr::chuck(list_fields, "git_commit"), 1L, 7L),
      time_compact,
      sep = "_"
    )

  return(res)
}
