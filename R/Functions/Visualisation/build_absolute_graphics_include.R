#' @title Build a knitr image include with an absolute path
#' @description
#' Turn a path relative to the project root into the knitr object that
#' includes the image in a rendered document, so that website pages in
#' subfolders find images of the project.
#' @param path
#' Character scalar. Path of the image relative to the project root.
#' @return
#' The object of `knitr::include_graphics()` for the absolute path, with
#' `rel_path = FALSE`.
#' @examples
#' \dontrun{
#' build_absolute_graphics_include(
#'   path = "Outputs/Figures/schema_diagram.png"
#' )
#' }
build_absolute_graphics_include <- function(path) {
  knitr::include_graphics(
    here::here(path),
    rel_path = FALSE
  )
}
