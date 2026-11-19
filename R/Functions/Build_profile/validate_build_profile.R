#' @title Validate the build profile and its preconditions
#' @description
#' Check that the configuration profile of a database build agrees with its
#' `subset` settings and the state of the code, so that a regional
#' rehearsal database can never be built or labelled as a full or release
#' database, and a release is built only from committed code.
#' @param profile
#' Character scalar. The active configuration profile, the `profile` value
#' of `config.yml`: `"default"`, `"subset"` or `"release"`.
#' @param list_subset
#' Named list. The `subset` section of `config.yml`, with the logical
#' scalar `enabled` and, when enabled, `box_name`, `lon_min`, `lon_max`,
#' `lat_min`, `lat_max` and `database_file`.
#' @param flag_git_clean
#' Logical scalar. Whether the git checkout has no uncommitted or untracked
#' files (see `is_git_clean()`), measured before the build starts.
#' @return
#' `profile`, unchanged and invisibly.
#' @details
#' The subset must be enabled in the `subset` profile and disabled in
#' every other profile; in particular, the `release` profile refuses to
#' run with a bounding box. When enabled, the box is checked with
#' `validate_bounding_box()`, `box_name` must be a non-empty text value,
#' and `database_file` must stay under the data root
#' (`validate_subset_database_file()`). The `release` profile also
#' requires `flag_git_clean` to be `TRUE`, so that the commit recorded in
#' the build manifest is the code that built the database.
#' @examples
#' \dontrun{
#' validate_build_profile(
#'   profile = load_config_value(value = "profile"),
#'   list_subset = load_config_value(value = "subset"),
#'   flag_git_clean = is_git_clean()
#' )
#' }
validate_build_profile <- function(
  profile,
  list_subset,
  flag_git_clean
) {
  vec_profiles <-
    c("default", "subset", "release")

  assertthat::assert_that(
    base::is.character(profile),
    base::length(profile) == 1L,
    base::isTRUE(profile %in% vec_profiles),
    msg = "`profile` must be one of \"default\", \"subset\" or \"release\"."
  )

  assertthat::assert_that(
    base::is.list(list_subset),
    msg = "`list_subset` must be the `subset` section of config.yml."
  )

  assertthat::assert_that(
    assertthat::is.flag(flag_git_clean),
    !base::is.na(flag_git_clean),
    msg = "`flag_git_clean` must be TRUE or FALSE."
  )

  if (
    profile == "release" &&
      base::isFALSE(flag_git_clean)
  ) {
    cli::cli_abort(
      c(
        "The release profile refuses to run with uncommitted or untracked
        files in the checkout.",
        "i" = "Commit or remove them, so that the recorded commit is the
        code that builds the database."
      )
    )
  }

  flag_enabled <-
    purrr::pluck(list_subset, "enabled")

  if (
    !assertthat::is.flag(flag_enabled) ||
      base::is.na(flag_enabled)
  ) {
    cli::cli_abort(
      "{.field enabled} of the {.field subset} settings must be TRUE or
      FALSE."
    )
  }

  if (
    profile == "release" &&
      base::isTRUE(flag_enabled)
  ) {
    cli::cli_abort(
      c(
        "The release profile refuses to run with a subset bounding box.",
        "i" = "Set {.field enabled: false} in the {.field subset} section
        of the release profile."
      )
    )
  }

  if (
    profile == "subset" &&
      base::isFALSE(flag_enabled)
  ) {
    cli::cli_abort(
      "The subset profile needs {.field enabled: true} in its
      {.field subset} section."
    )
  }

  if (
    profile == "default" &&
      base::isTRUE(flag_enabled)
  ) {
    cli::cli_abort(
      c(
        "Only the subset profile may enable the {.field subset} box.",
        "i" = "Select it with {.envvar R_CONFIG_ACTIVE} = {.val subset}."
      )
    )
  }

  if (
    base::isTRUE(flag_enabled)
  ) {
    validate_bounding_box(list_bounding_box = list_subset)

    box_name <-
      purrr::pluck(list_subset, "box_name")

    if (
      !base::is.character(box_name) ||
        base::length(box_name) != 1L ||
        base::is.na(box_name) ||
        !base::nzchar(box_name)
    ) {
      cli::cli_abort(
        "{.field box_name} of the subset must be a non-empty text value."
      )
    }

    validate_subset_database_file(
      database_file = purrr::pluck(list_subset, "database_file")
    )
  }

  res <- profile

  return(invisible(res))
}
