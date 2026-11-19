#' @title Collect the text labels drawn by a grob
#' @description
#' Walk a grid grob, gTree or gtable and return the labels of all text
#' grobs in it, so that tests can check what a combined figure draws.
#' @param grob
#' A grid grob, for example the result of `ggplot2::ggplotGrob()`.
#' @return
#' Character vector of the labels, in drawing order.
collect_grob_labels <- function(grob) {
  vec_labels_own <-
    if (
      base::inherits(grob, "text")
    ) {
      base::as.character(purrr::pluck(grob, "label"))
    } else {
      base::character(0)
    }

  list_grobs_inner <-
    c(
      purrr::pluck(grob, "children", .default = list()),
      purrr::pluck(grob, "grobs", .default = list())
    )

  vec_labels_inner <-
    purrr::map(.x = list_grobs_inner, .f = collect_grob_labels) |>
    base::unlist()

  res <-
    c(vec_labels_own, vec_labels_inner)

  return(res)
}
