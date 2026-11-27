#' @title Resolve the producer mode of a build profile
#' @description
#' Check the `producers: mode` setting against the build profile and return
#' it. The mode decides how `resolve_producer_artefact()` finds the files of
#' every producer artefact.
#' @param profile
#' Character scalar. The build profile, as returned by
#' `validate_build_profile()`.
#' @param mode
#' Character scalar. `producers: mode` of `config.yml`: `"dev"` or
#' `"release"`.
#' @return
#' Character scalar: `mode`, unchanged.
#' @details
#' Aborts when `mode` is not `"dev"` or `"release"`, and when the `release`
#' profile has another mode than `"release"`: a published build reads only
#' tagged, checksum-verified artefacts. The other profiles may use either
#' mode.
#' @examples
#' \dontrun{
#' resolve_producer_mode(
#'   profile = "default",
#'   mode = load_config_value(value = c("producers", "mode"))
#' )
#' }
resolve_producer_mode <- function(
  profile,
  mode
) {
  assertthat::assert_that(
    base::is.character(profile),
    base::length(profile) == 1L,
    !base::is.na(profile),
    msg = "`profile` must be a character scalar."
  )

  assertthat::assert_that(
    base::is.character(mode),
    base::length(mode) == 1L,
    base::isTRUE(mode %in% c("dev", "release")),
    msg = "`mode` must be \"dev\" or \"release\"."
  )

  if (
    profile == "release" && mode != "release"
  ) {
    cli::cli_abort(
      c(
        "The release profile reads only tagged producer artefacts.",
        "x" = "{.code producers: mode} is {.val {mode}}; it must be
          {.val release}."
      )
    )
  }

  res <- mode

  return(res)
}
