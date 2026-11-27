#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_world_borders_layer() returns a polygon layer", {
  res <-
    build_world_borders_layer(
      col_fill = "#999999",
      col_line = NA,
      linewidth = 0.05
    )

  testthat::expect_s3_class(purrr::pluck(res, "geom"), "GeomPolygon")

  testthat::expect_true(
    base::all(
      c("long", "lat", "group") %in% base::names(purrr::pluck(res, "data"))
    )
  )

  testthat::expect_false(purrr::pluck(res, "inherit.aes"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_world_borders_layer() works with facets", {
  plot_facetted <-
    ggplot2::ggplot(
      data = tibble::tibble(
        coord_long = c(14, 16),
        coord_lat = c(50, 49),
        panel = c("a", "b")
      ),
      mapping = ggplot2::aes(x = coord_long, y = coord_lat)
    ) +
    ggplot2::facet_wrap(facets = ggplot2::vars(panel)) +
    ggplot2::coord_quickmap(xlim = c(12, 19), ylim = c(48, 51)) +
    build_world_borders_layer(
      col_fill = "#999999",
      col_line = "#000000",
      linewidth = 0.05
    ) +
    ggplot2::geom_point()

  testthat::expect_length(purrr::pluck(plot_facetted, "layers"), 2L)

  testthat::expect_no_error(ggplot2::ggplotGrob(plot_facetted))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_world_borders_layer() validates arguments", {
  testthat::expect_error(
    build_world_borders_layer(
      col_fill = c("#999999", "#000000"),
      col_line = NA,
      linewidth = 0.05
    ),
    regexp = "col_fill"
  )

  testthat::expect_error(
    build_world_borders_layer(
      col_fill = "#999999",
      col_line = NA,
      linewidth = 0
    ),
    regexp = "linewidth"
  )
})
