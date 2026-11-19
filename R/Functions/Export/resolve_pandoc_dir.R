#' @title Resolve the folder of the pandoc bundled with Quarto
#' @description
#' Return the folder of the `pandoc` executable that ships with Quarto, so
#' that documents rendered through `rmarkdown` use the same pandoc as the
#' website.
#' @param path_quarto
#' Character scalar. Path of the `quarto` executable. Default: `quarto` as
#' found on the `PATH` (`Sys.which()`), which is an empty string when it is
#' missing.
#' @return
#' Character scalar. The folder that holds `pandoc` (`pandoc.exe` on
#' Windows), with forward slashes: `<folder of quarto>/tools`.
#' @details
#' Aborts when `path_quarto` is empty or when the `tools` folder next to it
#' has no `pandoc` executable.
#' @examples
#' \dontrun{
#' dir_pandoc <- resolve_pandoc_dir()
#' }
resolve_pandoc_dir <- function(
  path_quarto = base::Sys.which("quarto")
) {
  assertthat::assert_that(
    base::is.character(path_quarto),
    base::length(path_quarto) == 1L,
    !base::is.na(path_quarto),
    msg = "`path_quarto` must be a character scalar."
  )

  # Sys.which() names its result after the command
  path_quarto_unnamed <-
    base::unname(path_quarto)

  if (
    !base::nzchar(path_quarto_unnamed)
  ) {
    cli::cli_abort(
      c(
        "Quarto was not found on the PATH.",
        "i" = "Install Quarto; its bundled pandoc renders the document."
      )
    )
  }

  dir_tools <-
    base::file.path(base::dirname(path_quarto_unnamed), "tools")

  vec_path_pandoc <-
    base::file.path(dir_tools, c("pandoc.exe", "pandoc"))

  if (
    !base::any(base::file.exists(vec_path_pandoc))
  ) {
    cli::cli_abort(
      "The {.file tools} folder of Quarto holds no pandoc executable."
    )
  }

  res <-
    base::normalizePath(dir_tools, winslash = "/")

  return(res)
}
