#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_plot_sizes() draws a histogram of sizes", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_sizes <-
    tibble::tibble(
      sample_id = 1:4,
      sample_size = c(100, 400, 100, NA),
      sample_size_unit = c(base::rep("square meters", 3L), NA)
    )

  res <-
    plot_plot_sizes(
      data_plot_sizes = data_sizes,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  list_labs <-
    ggplot2::get_labs(res)

  testthat::expect_equal(
    purrr::pluck(list_labs, "x"),
    "Plot size (square meters)"
  )

  testthat::expect_equal(purrr::pluck(list_labs, "y"), "Number of Samples")

  testthat::expect_s3_class(
    purrr::pluck(res, "layers", 1L, "geom"),
    "GeomBar"
  )

  # The sample without a size is left out
  testthat::expect_equal(base::nrow(purrr::pluck(res, "data")), 3L)

  # Empty bins are left out without a warning about infinite values
  testthat::expect_no_warning(ggplot2::ggplotGrob(res))
})

testthat::test_that("plot_plot_sizes() labels both axes as powers of ten", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  res <-
    plot_plot_sizes(
      data_plot_sizes = tibble::tibble(
        sample_id = 1:2,
        sample_size = c(0.1, 1e5),
        sample_size_unit = c("square meters", "square meters")
      ),
      list_figure_style = list_figure_style
    )

  vec_labels_x <-
    ggplot2::get_guide_data(plot = res, aesthetic = "x") |>
    dplyr::pull(.label) |>
    purrr::map_chr(.f = ~ base::deparse(.x))

  testthat::expect_true(
    base::all(stringr::str_detect(vec_labels_x, "^10\\^-?[0-9]+$"))
  )

  # A wider right margin keeps the label at the right end inside the figure
  unit_margin <-
    purrr::chuck(res, "theme", "plot.margin")

  testthat::expect_equal(base::as.numeric(unit_margin), c(0.1, 0.5, 0, 0.1))

  testthat::expect_equal(base::unique(grid::unitType(unit_margin)), "cm")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_plot_sizes() needs sizes in one unit", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_plot_sizes(
      data_plot_sizes = tibble::tibble(
        sample_id = 1:2,
        sample_size = c(100, 1),
        sample_size_unit = c("square meters", "hectares")
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "unit"
  )

  testthat::expect_error(
    plot_plot_sizes(
      data_plot_sizes = tibble::tibble(
        sample_id = 1L,
        sample_size = NA_real_,
        sample_size_unit = NA_character_
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "No sample"
  )

  testthat::expect_error(
    plot_plot_sizes(
      data_plot_sizes = tibble::tibble(sample_size = 1),
      list_figure_style = list_figure_style
    ),
    regexp = "sample_size_unit"
  )
})
