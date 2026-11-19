#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_taxon_occurrences() maps one panel per bin", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_occurrences <-
    tibble::tibble(
      dataset_id = c(6L, 7L),
      dataset_type = c("vegetation plot", "fossil pollen archive"),
      coord_long = c(-100, -90),
      coord_lat = c(45, 50),
      age = c(0, 1000),
      age_bin_class = base::factor(
        c("contemporary", "paleo: 0 ka cal yr BP"),
        levels = c(
          "contemporary", "paleo: 0 ka cal yr BP", "paleo: 2.5 ka cal yr BP"
        )
      )
    )

  res <-
    plot_taxon_occurrences(
      data_taxon_occurrences = data_occurrences,
      list_region = list(
        lon_min = -135, lon_max = -60, lat_min = 22, lat_max = 60
      ),
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  testthat::expect_s3_class(purrr::pluck(res, "facet"), "FacetWrap")

  list_labs <-
    ggplot2::get_labs(res)

  testthat::expect_equal(purrr::pluck(list_labs, "x"), "Longitude")

  testthat::expect_equal(purrr::pluck(list_labs, "colour"), "Dataset type")

  vec_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    ) |>
    base::unname()

  testthat::expect_equal(
    vec_geoms,
    c("GeomPolygon", "GeomPoint", "GeomPoint")
  )

  testthat::expect_equal(
    purrr::pluck(res, "coordinates", "limits"),
    list(x = c(-135, -60), y = c(22, 60))
  )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_taxon_occurrences() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_taxon_occurrences(
      data_taxon_occurrences = tibble::tibble(coord_long = 1),
      list_region = list(
        lon_min = -135, lon_max = -60, lat_min = 22, lat_max = 60
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "age_bin_class"
  )
})
