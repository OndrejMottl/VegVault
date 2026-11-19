#' @title Validate that the requested configuration profile was loaded
#' @description
#' Check that the profile requested through `R_CONFIG_ACTIVE` is the one
#' `config.yml` actually provided. `{config}` silently falls back to the
#' `default` profile for an unknown name, so a mistyped `subset` would
#' otherwise run a full build against the live database.
#' @param profile_loaded
#' Character scalar. The `profile` value of the loaded configuration.
#' Default: read with `load_config_value()`.
#' @param profile_requested
#' Character scalar. The requested profile. Default: the value of the
#' `R_CONFIG_ACTIVE` environment variable, the project's profile switch,
#' or `"default"` when it is unset or empty.
#' @return
#' `profile_loaded`, unchanged and invisibly.
#' @details
#' Aborts when the two differ, naming both. Called once by the project
#' setup, so every stage, pipeline and test run is covered.
#' @examples
#' \dontrun{
#' validate_config_profile()
#' }
validate_config_profile <- function(
  profile_loaded = load_config_value(value = "profile"),
  profile_requested = base::Sys.getenv("R_CONFIG_ACTIVE", unset = "default")
) {
  assertthat::assert_that(
    base::is.character(profile_loaded),
    base::length(profile_loaded) == 1L,
    !base::is.na(profile_loaded),
    msg = "`profile_loaded` must be a character scalar."
  )

  assertthat::assert_that(
    base::is.character(profile_requested),
    base::length(profile_requested) == 1L,
    !base::is.na(profile_requested),
    msg = "`profile_requested` must be a character scalar."
  )

  # `{config}` reads an empty R_CONFIG_ACTIVE as the default profile
  profile_requested_resolved <-
    if (
      base::nzchar(profile_requested)
    ) {
      profile_requested
    } else {
      "default"
    }

  if (
    !base::identical(profile_loaded, profile_requested_resolved)
  ) {
    cli::cli_abort(
      c(
        "{.envvar R_CONFIG_ACTIVE} asks for the profile
        {.val {profile_requested_resolved}}, but {.file config.yml}
        provided {.val {profile_loaded}}.",
        "i" = "Use one of the profiles defined in {.file config.yml}; an
        unknown name silently falls back to the default profile."
      )
    )
  }

  res <- profile_loaded

  return(invisible(res))
}
