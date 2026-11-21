#' @title Diagnose the version row of a database
#' @description
#' Compare the version row of a built VegVault database with the version
#' configured for the build and with its build manifest, read-only.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @param list_version
#' Named list. The configured version record, with at least `version`:
#' normally the last entry of `database: versions` in `config.yml`.
#' @param path_producer_manifest
#' Character scalar. Path of the pin manifest of the producer artefacts,
#' `Data/Producers/producer_manifest.yml`.
#' @return
#' A tibble in the format of `build_check_result()`, check `version_row`,
#' with one row per field of the last row of `version_control` (the row
#' with the highest `id`):
#' \itemize{
#'   \item `version`: equals the configured version, and so does the
#'     version of the build manifest;
#'   \item `changelog`: present and not blank;
#'   \item `build_profile` and `git_commit`: equal those of the build
#'     manifest;
#'   \item `manifest_sha256`: equals the SHA-256 of the pin manifest.
#' }
#' A database without a version row gives one `fail` row with scope
#' `version_control`.
#' @details
#' The SHA-256 of the pin manifest is taken on its text with line endings
#' converted to LF (`compute_text_file_sha256()`), so Windows and Linux
#' checkouts agree. The row with the highest `id` is the version being
#' built, because the assembly writes the version rows in the order of
#' `config.yml`. Opens the database read-only. Aborts when the database is
#' not the one of the manifest or the pin manifest does not exist.
#' @examples
#' \dontrun{
#' diagnose_version_row(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   list_version = load_config_value(value = c("database", "versions")) |>
#'     purrr::pluck(-1),
#'   path_producer_manifest = here::here(
#'     "Data", "Producers", "producer_manifest.yml"
#'   )
#' )
#' }
diagnose_version_row <- function(
  path_database,
  list_build_manifest,
  list_version,
  path_producer_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  version_config <-
    purrr::pluck(list_version, "version")

  assertthat::assert_that(
    base::is.character(version_config),
    base::length(version_config) == 1L,
    !base::is.na(version_config),
    msg = "`list_version` must hold the configured `version` as text."
  )

  assertthat::assert_that(
    base::is.character(path_producer_manifest),
    base::length(path_producer_manifest) == 1L,
    base::file.exists(path_producer_manifest),
    msg = "`path_producer_manifest` must be the path of an existing file."
  )

  # The version being built has the highest id; vaultkeepr 0.1.0 took the
  #   last row of an unordered query instead
  data_row <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT id, version, changelog, build_profile, git_commit,",
        "manifest_sha256 FROM version_control ORDER BY id DESC LIMIT 1"
      ),
      flag_read_only = TRUE
    )

  if (
    base::nrow(data_row) == 0L
  ) {
    res <-
      build_check_result(
        check_id = "version_row",
        scope = "version_control",
        status = "fail",
        observed = 0L,
        threshold = 1L,
        message = stringr::str_c(
          "version_control has no row; the build must write the row of ",
          "the version it builds."
        )
      )

    return(res)
  }

  version_manifest <-
    purrr::pluck(
      list_build_manifest, "version", "version",
      .default = NA_character_
    )

  vec_observed <-
    c(
      version = purrr::chuck(data_row, "version"),
      changelog = purrr::chuck(data_row, "changelog"),
      build_profile = purrr::chuck(data_row, "build_profile"),
      git_commit = purrr::chuck(data_row, "git_commit"),
      manifest_sha256 = purrr::chuck(data_row, "manifest_sha256")
    )

  vec_expected <-
    c(
      version = version_config,
      changelog = NA_character_,
      build_profile = purrr::pluck(
        list_build_manifest, "profile",
        .default = NA_character_
      ),
      git_commit = purrr::pluck(
        list_build_manifest, "git_commit",
        .default = NA_character_
      ),
      manifest_sha256 = compute_text_file_sha256(
        path_file = path_producer_manifest
      )
    )

  # A comparison with a missing value counts as unequal
  vec_equal <-
    dplyr::coalesce(vec_observed == vec_expected, FALSE)

  vec_pass <-
    c(
      version = vec_equal[["version"]] &&
        dplyr::coalesce(version_manifest == version_config, FALSE),
      changelog = dplyr::coalesce(
        stringr::str_squish(vec_observed[["changelog"]]) != "",
        FALSE
      ),
      vec_equal[c("build_profile", "git_commit", "manifest_sha256")]
    )

  vec_messages <-
    c(
      version = stringr::str_c(
        "The version row records ", vec_observed[["version"]],
        ", the build manifest ", version_manifest,
        " and config.yml ", version_config, "."
      ),
      changelog = "The version row needs a changelog.",
      build_profile = "The version row must record the profile of the build.",
      git_commit = "The version row must record the commit of the build.",
      manifest_sha256 = stringr::str_c(
        "The version row must record the SHA-256 of the pin manifest the ",
        "build read."
      )
    )

  vec_status <-
    base::ifelse(vec_pass, "pass", "fail")

  res <-
    build_check_result(
      check_id = "version_row",
      scope = base::names(vec_observed),
      status = base::unname(vec_status),
      observed = base::unname(vec_observed),
      threshold = base::unname(vec_expected),
      message = base::ifelse(
        vec_pass,
        stringr::str_c("The ", base::names(vec_observed), " is as expected."),
        base::unname(vec_messages)
      )
    )

  return(res)
}
