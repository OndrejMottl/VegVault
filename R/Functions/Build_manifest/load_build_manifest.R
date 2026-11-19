#' @title Load the build manifest of a VegVault database
#' @description
#' Read a build manifest written by `save_build_manifest()`, check its
#' format, and optionally check that it still describes a given database
#' file and was built with an expected profile.
#' @param path_manifest
#' Character scalar. Path of the manifest file.
#' @param path_database
#' Character scalar or `NULL` (default). When given, the database file
#' must exist and match the manifest in file name, size and modification
#' time (to the second).
#' @param profile_expected
#' Character scalar or `NULL` (default). When given, the profile recorded
#' in the manifest must equal it, e.g. `"release"` before a release. A
#' release manifest must also record a clean checkout.
#' @return
#' Named list with the manifest fields: `manifest_version`, `database`
#' (`file_name`, `size_bytes`, `modified_time_utc`), `profile`, `subset`,
#' `version`, `producer_pins`, `git_commit`, `git_clean` and
#' `build_time_utc`.
#' @details
#' Aborts when the file is missing, when a field is missing, when
#' `manifest_version` is not 1, or when one of the optional checks fails.
#' A database that differs from its manifest was changed after the build,
#' so stages that rely on the manifest must not use it. Messages never
#' contain the database path.
#' @examples
#' \dontrun{
#' list_manifest <-
#'   load_build_manifest(
#'     path_manifest = path_build_manifest,
#'     path_database = resolve_database_path(),
#'     profile_expected = "release"
#'   )
#' }
load_build_manifest <- function(
  path_manifest,
  path_database = NULL,
  profile_expected = NULL
) {
  assertthat::assert_that(
    base::is.character(path_manifest),
    base::length(path_manifest) == 1L,
    !base::is.na(path_manifest),
    base::nzchar(path_manifest),
    msg = "`path_manifest` must be a non-empty character scalar."
  )

  if (
    !base::file.exists(path_manifest)
  ) {
    cli::cli_abort(
      c(
        "No build manifest {.file {base::basename(path_manifest)}}.",
        "i" = "Build the database first; the build writes its manifest."
      )
    )
  }

  list_manifest <-
    yaml::read_yaml(file = path_manifest)

  vec_fields <-
    c(
      "manifest_version", "database", "profile", "subset", "version",
      "producer_pins", "git_commit", "git_clean", "build_time_utc"
    )

  vec_fields_missing <-
    vec_fields[!vec_fields %in% base::names(list_manifest)]

  if (
    base::length(vec_fields_missing) > 0L
  ) {
    cli::cli_abort(
      "The build manifest has no {.field {vec_fields_missing}}."
    )
  }

  if (
    !base::isTRUE(purrr::chuck(list_manifest, "manifest_version") == 1L)
  ) {
    cli::cli_abort(
      "Only {.field manifest_version} 1 can be read."
    )
  }

  if (
    !base::is.null(path_database)
  ) {
    assertthat::assert_that(
      base::is.character(path_database),
      base::length(path_database) == 1L,
      msg = "`path_database` must be NULL or a character scalar."
    )

    # Messages omit the path, because database paths are private
    if (
      !base::file.exists(path_database)
    ) {
      cli::cli_abort(
        "The database file of the build manifest does not exist."
      )
    }

    if (
      base::basename(path_database) !=
        purrr::chuck(list_manifest, "database", "file_name")
    ) {
      cli::cli_abort(
        "The database file name differs from the file name in the build
        manifest."
      )
    }

    flag_size_equal <-
      base::isTRUE(
        base::as.numeric(base::file.size(path_database)) ==
          purrr::chuck(list_manifest, "database", "size_bytes")
      )

    flag_time_equal <-
      base::isTRUE(
        base::format(
          base::file.mtime(path_database),
          format = "%Y-%m-%dT%H:%M:%SZ",
          tz = "UTC"
        ) ==
          purrr::chuck(list_manifest, "database", "modified_time_utc")
      )

    if (
      !flag_size_equal ||
        !flag_time_equal
    ) {
      cli::cli_abort(
        c(
          "The database was changed after the build that wrote its
          manifest (size or modification time differ).",
          "i" = "Rebuild the database, or do not use it for this stage."
        )
      )
    }
  }

  if (
    !base::is.null(profile_expected)
  ) {
    assertthat::assert_that(
      base::is.character(profile_expected),
      base::length(profile_expected) == 1L,
      msg = "`profile_expected` must be NULL or a character scalar."
    )

    profile_built <-
      purrr::chuck(list_manifest, "profile")

    if (
      !base::identical(profile_built, profile_expected)
    ) {
      cli::cli_abort(
        "The database was built with the {.val {profile_built}} profile,
        not {.val {profile_expected}}."
      )
    }

    if (
      profile_expected == "release" &&
        !base::isTRUE(purrr::chuck(list_manifest, "git_clean"))
    ) {
      cli::cli_abort(
        "The release manifest records a build from a checkout with
        uncommitted or untracked files."
      )
    }
  }

  res <- list_manifest

  return(res)
}
