#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_coloured_facet_strips() colours the strips", {
  plot_facetted <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:4, y = 1:4, panel = c("a", "a", "b", "b")),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::facet_wrap(facets = ggplot2::vars(panel), nrow = 1) +
    ggplot2::geom_point()

  res <-
    build_coloured_facet_strips(
      sel_plot = plot_facetted,
      sel_palette = c("#ff0000", "#0000ff"),
      direction = "horizontal",
      return_raw = TRUE
    )

  testthat::expect_s3_class(res, "gtable")

  data_layout <-
    purrr::pluck(res, "layout") |>
    tibble::as_tibble() |>
    dplyr::mutate(index_grob = dplyr::row_number()) |>
    dplyr::filter(stringr::str_detect(name, "strip-t")) |>
    dplyr::arrange(l)

  # Fill of the strip background, panel by panel from left to right
  vec_fills <-
    purrr::map_chr(
      .x = dplyr::pull(data_layout, index_grob),
      .f = ~ {
        grob_strip <-
          purrr::pluck(res, "grobs", .x, "grobs", 1L)

        index_rect <-
          base::which(
            stringr::str_detect(
              purrr::pluck(grob_strip, "childrenOrder"),
              "rect"
            )
          )

        purrr::pluck(grob_strip, "children", index_rect, "gp", "fill")
      }
    )

  testthat::expect_equal(vec_fills, c("#ff0000", "#0000ff"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_coloured_facet_strips() draws by default", {
  plot_facetted <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:4, y = 1:4, panel = c("a", "a", "b", "b")),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::facet_wrap(facets = ggplot2::vars(panel), nrow = 1) +
    ggplot2::geom_point()

  testthat::expect_invisible(
    build_coloured_facet_strips(
      sel_plot = plot_facetted,
      sel_palette = c("#ff0000", "#0000ff")
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_coloured_facet_strips() checks the direction", {
  plot_facetted <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:4, y = 1:4, panel = c("a", "a", "b", "b")),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::facet_wrap(facets = ggplot2::vars(panel), nrow = 1) +
    ggplot2::geom_point()

  testthat::expect_error(
    build_coloured_facet_strips(
      sel_plot = plot_facetted,
      sel_palette = c("#ff0000", "#0000ff"),
      direction = "diagonal",
      return_raw = TRUE
    ),
    regexp = "should be one of"
  )
})
