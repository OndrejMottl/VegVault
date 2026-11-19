#' @title Save the build manifest of a VegVault database
#' @description
#' Write a small YAML file that describes a finished database build: the
#' database file name, size and modification time, the configuration
#' profile and subset box, the database version, the producer pins, the
#' git commit and whether the checkout was clean, and the build time.
#' Later stages depend on this file instead of on the database, so
#' `{targets}` never hashes the database itself.
#' @param path_database
#' Character scalar. Path of the built SQLite database; the file must
#' exist.
#' @param profile
#' Character scalar. The configuration profile of the build (see
#' `validate_build_profile()`).
#' @param list_subset
#' Named list. The `subset` section of `config.yml`.
#' @param list_version
#' Named list. The version record of the database, with the text values
#' `version`, `update_date` and `changelog`, normally the last entry of
#' `database: versions` in `config.yml`.
#' @param list_producer_pins
#' List. The pinned producer artefacts the build used, as recorded by the
#' producer-import stage. Default: an empty list.
#' @param git_commit
#' Character scalar. The 40-character commit hash of the code that built
#' the database (see `load_git_commit()`).
#' @param flag_git_clean
#' Logical scalar. Whether that checkout had no uncommitted or untracked
#' files when the build started (see `is_git_clean()`).
#' @param time_build
#' A `POSIXct` scalar. The time the build finished. Default: now.
#' @param path_manifest
#' Character scalar. Where to write the manifest. Default: next to the
#' database (see `resolve_build_manifest_path()`).
#' @return
#' Character scalar, invisibly: `path_manifest`, so that the function can
#' be the command of a `{targets}` target with `format = "file"`.
#' @details
#' The profile, subset and clean flag are checked with
#' `validate_build_profile()` before anything is written, so no release
#' manifest can describe a build from uncommitted code. An existing
#' manifest is replaced, because the manifest always describes the current
#' database file. Only the file name of the database is recorded, never its
#' path, because database paths are private. Times are written in UTC as
#' `YYYY-MM-DDTHH:MM:SSZ`. The file starts with `manifest_version: 1`;
#' `load_build_manifest()` reads it back.
#' @examples
#' \dontrun{
#' path_manifest <-
#'   save_build_manifest(
#'     path_database = resolve_database_path(),
#'     profile = load_config_value(value = "profile"),
#'     list_subset = load_config_value(value = "subset"),
#'     list_version = load_config_value(value = c("database", "versions")) |>
#'       purrr::pluck(-1),
#'     git_commit = load_git_commit(),
#'     flag_git_clean = is_git_clean()
#'   )
#' }
save_build_manifest <- function(
  path_database,
  profile,
  list_subset,
  list_version,
  list_producer_pins = list(),
  git_commit,
  flag_git_clean,
  time_build = base::Sys.time(),
  path_manifest = resolve_build_manifest_path(path_database = path_database)
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  # The message omits the path, because database paths are private
  if (
    !base::file.exists(path_database)
  ) {
    cli::cli_abort(
      c(
        "The database file does not exist, so no build manifest is written.",
        "i" = "Save the manifest only after the build has finished."
      )
    )
  }

  validate_build_profile(
    profile = profile,
    list_subset = list_subset,
    flag_git_clean = flag_git_clean
  )

  vec_version_fields <-
    c("version", "update_date", "changelog")

  assertthat::assert_that(
    base::is.list(list_version),
    base::all(vec_version_fields %in% base::names(list_version)),
    msg = stringr::str_c(
      "`list_version` must be a list with `version`, `update_date` ",
      "and `changelog`."
    )
  )

  assertthat::assert_that(
    base::is.list(list_producer_pins),
    msg = "`list_producer_pins` must be a list (empty if none)."
  )

  assertthat::assert_that(
    base::is.character(git_commit),
    base::length(git_commit) == 1L,
    base::isTRUE(stringr::str_detect(git_commit, "^[0-9a-f]{40}$")),
    msg = "`git_commit` must be a 40-character commit hash."
  )

  assertthat::assert_that(
    base::inherits(time_build, "POSIXct"),
    base::length(time_build) == 1L,
    !base::is.na(time_build),
    msg = "`time_build` must be one date-time (POSIXct)."
  )

  assertthat::assert_that(
    base::is.character(path_manifest),
    base::length(path_manifest) == 1L,
    !base::is.na(path_manifest),
    base::nzchar(path_manifest),
    msg = "`path_manifest` must be a non-empty character scalar."
  )

  format_time_utc <- "%Y-%m-%dT%H:%M:%SZ"

  list_manifest <-
    list(
      manifest_version = 1L,
      database = list(
        file_name = base::basename(path_database),
        size_bytes = base::as.numeric(base::file.size(path_database)),
        modified_time_utc = base::format(
          base::file.mtime(path_database),
          format = format_time_utc,
          tz = "UTC"
        )
      ),
      profile = profile,
      subset = list_subset,
      version = list_version,
      producer_pins = list_producer_pins,
      git_commit = git_commit,
      git_clean = flag_git_clean,
      build_time_utc = base::format(
        time_build,
        format = format_time_utc,
        tz = "UTC"
      )
    )

  # 15 significant digits keep a file size of hundreds of gigabytes exact;
  #   the yaml default of 7 would round it
  yaml::write_yaml(
    x = list_manifest,
    file = path_manifest,
    precision = 15L
  )

  res <- path_manifest

  return(invisible(res))
}
