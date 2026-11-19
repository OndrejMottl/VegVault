#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_age_ranges() draws ages and ranges", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_ranges <-
    tibble::tibble(
      dataset_name = c("fossilpol_1001", "fossilpol_1001"),
      sample_id = c(7L, 8L),
      age = c(1000, 6000),
      age_iteration_min = c(900, 5800),
      age_iteration_max = c(1200, 6500)
    )

  res <-
    plot_sample_age_ranges(
      data_sample_age_ranges = data_ranges,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  list_labs <-
    ggplot2::get_labs(res)

  testthat::expect_equal(
    purrr::pluck(list_labs, "caption"),
    "Dataset: fossilpol_1001"
  )

  testthat::expect_equal(
    purrr::pluck(list_labs, "y"),
    "Sample age (ka cal yr BP)"
  )

  vec_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    ) |>
    base::unname()

  testthat::expect_equal(vec_geoms, c("GeomSegment", "GeomPoint"))

  # Next multiple of 5000 above 6500 (x) and 6000 (y)
  testthat::expect_equal(
    purrr::pluck(res, "coordinates", "limits"),
    list(x = c(0, 10000), y = c(0, 10000))
  )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_age_ranges() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_sample_age_ranges(
      data_sample_age_ranges = tibble::tibble(
        dataset_name = c("a", "b"),
        sample_id = 1:2,
        age = c(1, 2),
        age_iteration_min = c(1, 2),
        age_iteration_max = c(1, 2)
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "one dataset"
  )

  testthat::expect_error(
    plot_sample_age_ranges(
      data_sample_age_ranges = tibble::tibble(age = 1),
      list_figure_style = list_figure_style
    ),
    regexp = "age_iteration_min"
  )
})
