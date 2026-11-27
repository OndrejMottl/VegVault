#' @title Combine the three vaultkeepr example figures
#' @description
#' Arrange the genus occurrence map above the plot climate map and the
#' trait panels, as in the merged v1 `vaultkeepr` figure.
#' @param fig_taxon_occurrences
#' A ggplot object from `plot_taxon_occurrences()`.
#' @param fig_plot_climate
#' A ggplot object from `plot_plot_climate()`.
#' @param fig_trait_example
#' A ggplot object from `plot_trait_example()`.
#' @return
#' A ggplot object made by `cowplot::plot_grid()`.
#' @examples
#' \dontrun{
#' fig_vaultkeepr_examples <-
#'   plot_vaultkeepr_examples(
#'     fig_taxon_occurrences = fig_na_picea,
#'     fig_plot_climate = fig_cz_jsdm,
#'     fig_trait_example = fig_la_traits
#'   )
#' }
plot_vaultkeepr_examples <- function(
  fig_taxon_occurrences,
  fig_plot_climate,
  fig_trait_example
) {
  assertthat::assert_that(
    ggplot2::is_ggplot(fig_taxon_occurrences),
    ggplot2::is_ggplot(fig_plot_climate),
    ggplot2::is_ggplot(fig_trait_example),
    msg = stringr::str_c(
      "`fig_taxon_occurrences`, `fig_plot_climate` and `fig_trait_example` ",
      "must be ggplot objects."
    )
  )

  fig_climate_traits <-
    cowplot::plot_grid(
      plotlist = list(fig_plot_climate, fig_trait_example),
      nrow = 1,
      rel_widths = c(1.1, 1)
    )

  res <-
    cowplot::plot_grid(
      plotlist = list(fig_taxon_occurrences, fig_climate_traits),
      nrow = 2,
      rel_heights = c(1.5, 1)
    )

  return(res)
}
