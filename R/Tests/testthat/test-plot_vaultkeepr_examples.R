#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_vaultkeepr_examples() combines three figures", {
  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  res <-
    plot_vaultkeepr_examples(
      fig_taxon_occurrences = plot_example +
        ggplot2::labs(title = "genus map"),
      fig_plot_climate = plot_example +
        ggplot2::labs(title = "climate map"),
      fig_trait_example = plot_example +
        ggplot2::labs(title = "trait panels")
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  # The genus map, and the row of climate map and trait panels
  testthat::expect_length(purrr::pluck(res, "layers"), 2L)

  vec_labels <-
    collect_grob_labels(grob = ggplot2::ggplotGrob(res))

  testthat::expect_true(
    base::all(
      c("genus map", "climate map", "trait panels") %in% vec_labels
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_vaultkeepr_examples() takes ggplot objects", {
  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  testthat::expect_error(
    plot_vaultkeepr_examples(
      fig_taxon_occurrences = "plot",
      fig_plot_climate = plot_example,
      fig_trait_example = plot_example
    ),
    regexp = "ggplot"
  )
})
