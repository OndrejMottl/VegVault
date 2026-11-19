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
})
