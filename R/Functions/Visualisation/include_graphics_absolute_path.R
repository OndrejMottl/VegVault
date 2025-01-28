include_graphics_absolute_path <- function(path) {
  knitr::include_graphics(
    here::here(path),
    rel_path = FALSE
  )
}