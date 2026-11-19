#' @title Build the cue of the export targets
#' @description
#' Turn the `export: rewrite` setting into the `{targets}` cue of the
#' targets that write export files.
#' @param flag_rewrite
#' Logical scalar. `TRUE` to write every export file again on the next
#' run.
#' @return
#' A `tar_cue` object: mode `"always"` when `flag_rewrite` is `TRUE`,
#' otherwise mode `"thorough"`.
#' @details
#' With the `"thorough"` cue, `{targets}` writes an export file again only
#' when it is needed: after a new build (a new build manifest), when the
#' export code changed, or when the file is missing or was changed (the
#' export targets have `format = "file"`). `flag_rewrite = TRUE` forces
#' every file to be written again, even when nothing changed.
#' @examples
#' \dontrun{
#' cue_export <-
#'   build_export_cue(
#'     flag_rewrite = load_config_value(value = c("export", "rewrite"))
#'   )
#' }
build_export_cue <- function(flag_rewrite) {
  assertthat::assert_that(
    assertthat::is.flag(flag_rewrite),
    !base::is.na(flag_rewrite),
    msg = "`flag_rewrite` must be TRUE or FALSE."
  )

  mode_cue <-
    if (
      base::isTRUE(flag_rewrite)
    ) {
      "always"
    } else {
      "thorough"
    }

  res <-
    targets::tar_cue(mode = mode_cue)

  return(res)
}
