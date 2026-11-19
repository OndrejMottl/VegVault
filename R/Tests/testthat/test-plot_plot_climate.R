#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_plot_climate() maps plots coloured by value", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_climate <-
    tibble::tibble(
      sample_id = c(1L, 2L),
      coord_long = c(14, 16),
      coord_lat = c(50, 49.5),
      n_taxa = c(2L, 3L),
      abiotic_variable_unit = c("\u00b0C", "\u00b0C"),
      abiotic_value = c(8.5, 9)
    )

  res <-
    plot_plot_climate(
      data_plot_climate = data_climate,
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      abiotic_variable_label = "MAT",
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  list_labs <-
    ggplot2::get_labs(res)

  testthat::expect_equal(purrr::pluck(list_labs, "colour"), "MAT (\u00b0C)")

  testthat::expect_equal(purrr::pluck(list_labs, "x"), "Longitude")

  vec_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    ) |>
    base::unname()

  testthat::expect_equal(
    vec_geoms,
    c(
      "GeomPolygon", "GeomVline", "GeomHline", "GeomPolygon", "GeomPoint",
      "GeomPoint"
    )
  )

  # Graticule every 2 degrees of longitude and 0.5 degrees of latitude
  testthat::expect_equal(
    purrr::pluck(res, "layers", 2L, "data", "xintercept"),
    c(12, 14, 16, 18)
  )

  testthat::expect_equal(
    purrr::pluck(res, "layers", 3L, "data", "yintercept"),
    c(48.5, 49, 49.5, 50, 50.5, 51)
  )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_plot_climate() needs one unit", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_plot_climate(
      data_plot_climate = tibble::tibble(
        coord_long = c(14, 16),
        coord_lat = c(50, 49.5),
        abiotic_variable_unit = c("\u00b0C", "K"),
        abiotic_value = c(8.5, 280)
      ),
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      abiotic_variable_label = "MAT",
      list_figure_style = list_figure_style
    ),
    regexp = "unit"
  )

  testthat::expect_error(
    plot_plot_climate(
      data_plot_climate = tibble::tibble(coord_long = 14),
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      abiotic_variable_label = "MAT",
      list_figure_style = list_figure_style
    ),
    regexp = "abiotic_value"
  )
})
