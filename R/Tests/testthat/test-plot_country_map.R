#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_country_map() draws land and the country", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_border <-
    sf::st_sf(
      geometry = sf::st_sfc(
        sf::st_polygon(
          list(
            base::rbind(
              c(12.5, 48.8), c(18.5, 48.8), c(18.5, 50.9), c(12.5, 50.9),
              c(12.5, 48.8)
            )
          )
        ),
        crs = 4326
      )
    )

  res <-
    plot_country_map(
      data_country_border = data_border,
      list_extent = list(
        lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
      ),
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  vec_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    ) |>
    base::unname()

  testthat::expect_equal(vec_geoms, c("GeomPolygon", "GeomSf"))

  testthat::expect_equal(
    purrr::pluck(res, "coordinates", "limits"),
    list(x = c(-10, 32), y = c(35, 60))
  )

  testthat::expect_equal(
    purrr::pluck(ggplot2::get_labs(res), "x"),
    "Longitude"
  )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


testthat::test_that("plot_country_map() thins the longitude labels", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_border <-
    sf::st_sf(
      geometry = sf::st_sfc(
        sf::st_polygon(
          list(
            base::rbind(
              c(12.5, 48.8), c(18.5, 48.8), c(18.5, 50.9), c(12.5, 50.9),
              c(12.5, 48.8)
            )
          )
        ),
        crs = 4326
      )
    )

  list_overview <-
    list(lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60)

  res_default <-
    plot_country_map(
      data_country_border = data_border,
      list_extent = list_overview,
      list_figure_style = list_figure_style
    )

  res_thinned <-
    plot_country_map(
      data_country_border = data_border,
      list_extent = list_overview,
      list_figure_style = list_figure_style,
      n_breaks_lon = 3L
    )

  vec_lon_default <-
    ggplot2::ggplot_build(res_default) |>
    purrr::pluck("layout", "panel_params", 1L, "graticule") |>
    dplyr::filter(type %in% c("E", "W")) |>
    dplyr::pull(x_start)

  vec_lon_thinned <-
    ggplot2::ggplot_build(res_thinned) |>
    purrr::pluck("layout", "panel_params", 1L, "graticule") |>
    dplyr::filter(type %in% c("E", "W")) |>
    dplyr::pull(x_start)

  testthat::expect_equal(vec_lon_default, c(-10, 0, 10, 20, 30))

  testthat::expect_equal(vec_lon_thinned, c(-10, 10, 30))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_country_map() validates its arguments", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_country_map(
      data_country_border = tibble::tibble(a = 1),
      list_extent = list(
        lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "data_country_border"
  )

  testthat::expect_error(
    plot_country_map(
      data_country_border = sf::st_sf(
        geometry = sf::st_sfc(sf::st_point(c(14, 50)), crs = 4326)
      ),
      list_extent = list(
        lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
      ),
      list_figure_style = list_figure_style,
      n_breaks_lon = 0
    ),
    regexp = "n_breaks_lon"
  )

  testthat::expect_error(
    plot_country_map(
      data_country_border = sf::st_sf(
        geometry = sf::st_sfc(sf::st_point(c(14, 50)), crs = 4326)
      ),
      list_extent = list(
        lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
      ),
      list_figure_style = list_figure_style,
      n_breaks_lon = 2.5
    ),
    regexp = "n_breaks_lon"
  )
})
