#' @title Resolve the folder of the flat-file export
#' @description
#' Return the absolute path of the folder that receives the flat-file
#' export, from the `export: output_dir` setting of `config.yml`, which is
#' relative to the project root.
#' @param path_relative
#' Character scalar. The export folder relative to the project root.
#' Default: `export: output_dir` of the active configuration profile.
#' @param path_project
#' Character scalar. The project root. Default: `here::here()`.
#' @return
#' Character scalar. The absolute export folder, with forward slashes. The
#' folder does not need to exist; the export creates it.
#' @details
#' Aborts when `path_relative` is not a non-empty text value, is an
#' absolute path or starts with a drive letter, or contains a `..`
#' segment, so the export always stays inside the project.
#' @examples
#' \dontrun{
#' dir_export <- resolve_export_dir()
#' }
resolve_export_dir <- function(
  path_relative = load_config_value(value = c("export", "output_dir")),
  path_project = here::here()
) {
  if (
    !base::is.character(path_relative) ||
      base::length(path_relative) != 1L ||
      base::is.na(path_relative) ||
      !base::nzchar(path_relative)
  ) {
    cli::cli_abort(
      "{.field output_dir} of the {.field export} settings must be a
      non-empty text value."
    )
  }

  assertthat::assert_that(
    base::is.character(path_project),
    base::length(path_project) == 1L,
    !base::is.na(path_project),
    msg = "`path_project` must be a character scalar."
  )

  # A leading slash, backslash or drive letter (also "D:folder") leaves
  #   the project
  if (
    stringr::str_detect(path_relative, "^([A-Za-z]:|[/\\\\])")
  ) {
    cli::cli_abort(
      "{.field output_dir} of the {.field export} settings must be a path
      relative to the project root."
    )
  }

  if (
    stringr::str_detect(path_relative, "(^|[/\\\\])[.][.]([/\\\\]|$)")
  ) {
    cli::cli_abort(
      "{.field output_dir} of the {.field export} settings must stay inside
      the project; a {.val ..} folder is not allowed."
    )
  }

  res <-
    base::normalizePath(
      base::file.path(path_project, path_relative),
      winslash = "/",
      mustWork = FALSE
    )

  return(res)
}
