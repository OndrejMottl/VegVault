#' @title Validate the profile of an upstream store
#' @description
#' Check that an upstream stage was built in the active configuration
#' profile, so that a stage never builds on the targets of a run in
#' another profile (for example a full build on a regional rehearsal).
#' @param profile_upstream
#' Character scalar. The profile the upstream stage records, normally its
#' public target `profile_build`.
#' @param profile
#' Character scalar. The active configuration profile, the `profile` value
#' of `config.yml`.
#' @param runner
#' Character scalar. The runner of the upstream stage, relative to the
#' project root, for example `"R/Analyses/01_Producer_import/00_run.R"`.
#' @return
#' `profile`, unchanged and invisibly.
#' @details
#' Both profiles must be one of the profiles that `validate_build_profile()`
#' accepts (`"default"`, `"subset"` and `"release"`); a missing or
#' mistyped profile aborts with its own message. When the two differ, the
#' message names the upstream stage (the folder of `runner`), both profiles
#' and the runner to execute in the active profile.
#' `validate_target_store_contract()` checks that the latest upstream run
#' finished, but one store serves every profile, so a store whose latest
#' run finished in another profile passes it; this function closes that
#' gap.
#' @seealso [validate_build_profile()], [load_target_store_value()]
#' @examples
#' \dontrun{
#' validate_upstream_profile(
#'   profile_upstream = profile_build_producer_import,
#'   profile = load_config_value(value = "profile"),
#'   runner = "R/Analyses/01_Producer_import/00_run.R"
#' )
#' }
validate_upstream_profile <- function(
  profile_upstream,
  profile,
  runner
) {
  vec_profiles <-
    c("default", "subset", "release")

  assertthat::assert_that(
    base::is.character(runner),
    base::length(runner) == 1L,
    !base::is.na(runner),
    base::nzchar(runner),
    msg = "`runner` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(profile),
    base::length(profile) == 1L,
    base::isTRUE(profile %in% vec_profiles),
    msg = "`profile` must be one of \"default\", \"subset\" or \"release\"."
  )

  name_stage <-
    base::basename(base::dirname(runner))

  if (
    !base::is.character(profile_upstream) ||
      base::length(profile_upstream) != 1L ||
      !base::isTRUE(profile_upstream %in% vec_profiles)
  ) {
    cli::cli_abort(
      c(
        "The store of stage {.val {name_stage}} records no valid profile.",
        "i" = "Run {.file {runner}} again in the {.val {profile}} profile."
      )
    )
  }

  if (
    profile_upstream != profile
  ) {
    cli::cli_abort(
      c(
        "Stage {.val {name_stage}} was built in the
        {.val {profile_upstream}} profile, and this run is in the
        {.val {profile}} profile.",
        "i" = "Run {.file {runner}} in the {.val {profile}} profile first."
      )
    )
  }

  res <- profile

  return(invisible(res))
}
