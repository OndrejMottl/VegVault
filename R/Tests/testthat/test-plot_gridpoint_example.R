#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_gridpoint_example() combines the three maps", {
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
    plot_gridpoint_example(
      data_country_border = data_border,
      data_gridpoint_locations = tibble::tibble(
        coord_long = c(14.1, 16.1, 18),
        coord_lat = c(50.1, 49.6, 49)
      ),
      data_gridpoint_links = tibble::tibble(
        sample_id = c(1L, 2L, 9L),
        coord_long_plot = c(14, 16, 17),
        coord_lat_plot = c(50, 49.5, 49),
        coord_long_gridpoint = c(14.1, 16.1, NA),
        coord_lat_gridpoint = c(50.1, 49.6, NA)
      ),
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_overview = list(
        lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
      ),
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  # The column of overview and gridpoint map, and the link map
  testthat::expect_length(purrr::pluck(res, "layers"), 2L)

  vec_labels <-
    collect_grob_labels(grob = ggplot2::ggplotGrob(res))

  # Three maps, each with its own axis titles
  testthat::expect_equal(base::sum(vec_labels == "Longitude"), 3L)

  testthat::expect_equal(base::sum(vec_labels == "Latitude"), 3L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_gridpoint_example() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  list_region <-
    list(lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1)

  testthat::expect_error(
    plot_gridpoint_example(
      data_country_border = tibble::tibble(a = 1),
      data_gridpoint_locations = tibble::tibble(
        coord_long = 14, coord_lat = 50
      ),
      data_gridpoint_links = tibble::tibble(sample_id = 1L),
      list_region = list_region,
      list_overview = list_region,
      list_figure_style = list_figure_style
    ),
    regexp = "data_country_border"
  )
})
