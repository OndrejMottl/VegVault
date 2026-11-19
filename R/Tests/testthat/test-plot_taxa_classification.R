#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_taxa_classification() draws labelled counts", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_counts <-
    tibble::tibble(
      taxon_level = c(
        "total taxa", "species", "genus", "family", "not classified"
      ),
      n_taxa = c(1000L, 600L, 200L, 50L, 100L)
    )

  res <-
    plot_taxa_classification(
      data_taxa_classification_counts = data_counts,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  testthat::expect_equal(
    purrr::pluck(ggplot2::get_labs(res), "y"),
    "Number of Taxa"
  )

  vec_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    ) |>
    base::unname()

  testthat::expect_equal(
    vec_geoms,
    c("GeomSegment", "GeomPoint", "GeomLabel")
  )

  # The levels keep the order of the data
  testthat::expect_equal(
    base::levels(dplyr::pull(purrr::pluck(res, "data"), taxon_level)),
    c("total taxa", "species", "genus", "family", "not classified")
  )

  testthat::expect_equal(
    purrr::pluck(res, "coordinates", "limits", "y"),
    c(0, 1200)
  )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_taxa_classification() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_taxa_classification(
      data_taxa_classification_counts = tibble::tibble(n_taxa = 1L),
      list_figure_style = list_figure_style
    ),
    regexp = "taxon_level"
  )
})
