#' @title Resolve a project output folder
#' @description
#' Return the absolute path of an output folder of a pipeline stage, from
#' an `output_dir` setting of `config.yml`, which is relative to the
#' project root.
#' @param path_relative
#' Character scalar. The output folder relative to the project root, for
#' example `export: output_dir` of the active configuration profile.
#' @param section_name
#' Character scalar. Name of the `config.yml` section that holds the
#' setting (for example `"export"` or `"figures"`), used in messages.
#' @param path_project
#' Character scalar. The project root. Default: `here::here()`.
#' @return
#' Character scalar. The absolute output folder, with forward slashes. The
#' folder does not need to exist; the stage that writes to it creates it.
#' @details
#' Aborts when `path_relative` is not a non-empty text value, is an
#' absolute path or starts with a drive letter, or contains a `..`
#' segment, so outputs always stay inside the project.
#' @examples
#' \dontrun{
#' dir_export <-
#'   resolve_output_dir(
#'     path_relative = load_config_value(value = c("export", "output_dir")),
#'     section_name = "export"
#'   )
#' }
resolve_output_dir <- function(
  path_relative,
  section_name,
  path_project = here::here()
) {
  assertthat::assert_that(
    base::is.character(section_name),
    base::length(section_name) == 1L,
    !base::is.na(section_name),
    base::nzchar(section_name),
    msg = "`section_name` must be a non-empty character scalar."
  )

  if (
    !base::is.character(path_relative) ||
      base::length(path_relative) != 1L ||
      base::is.na(path_relative) ||
      !base::nzchar(path_relative)
  ) {
    cli::cli_abort(
      "{.field output_dir} of the {.field {section_name}} settings must be a
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
      "{.field output_dir} of the {.field {section_name}} settings must be a
      path relative to the project root."
    )
  }

  if (
    stringr::str_detect(path_relative, "(^|[/\\\\])[.][.]([/\\\\]|$)")
  ) {
    cli::cli_abort(
      "{.field output_dir} of the {.field {section_name}} settings must stay
      inside the project; a {.val ..} folder is not allowed."
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
