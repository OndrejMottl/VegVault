#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_age_histogram() shows each own count", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  # First bin (0 to 1000 years): 3 vegetation plots (one after 1950) and
  #   2 fossil pollen samples; second bin: 1 fossil pollen sample
  data_ages <-
    tibble::tibble(
      dataset_type = c(
        base::rep("vegetation plot", 3L),
        base::rep("fossil pollen archive", 3L)
      ),
      age = c(0, 10, -50, 100, 900, 1500)
    )

  res <-
    plot_sample_age_histogram(
      data_sample_ages = data_ages,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  # The larger count of a bin in the first layer, the smaller in front
  testthat::expect_length(purrr::pluck(res, "layers"), 2L)

  data_layer_first <-
    ggplot2::layer_data(plot = res, i = 1L)

  data_layer_second <-
    ggplot2::layer_data(plot = res, i = 2L)

  testthat::expect_equal(
    base::expm1(dplyr::pull(data_layer_first, ymax)),
    c(3, 1)
  )

  testthat::expect_equal(dplyr::pull(data_layer_first, x), c(500, 1500))

  testthat::expect_equal(
    base::expm1(dplyr::pull(data_layer_second, ymax)),
    2
  )

  testthat::expect_equal(dplyr::pull(data_layer_second, x), 500)

  # Every bar starts at zero: the bars are overlaid, not stacked
  testthat::expect_equal(
    c(
      dplyr::pull(data_layer_first, ymin),
      dplyr::pull(data_layer_second, ymin)
    ),
    c(0, 0, 0)
  )

  list_labs <-
    ggplot2::get_labs(res)

  testthat::expect_equal(
    purrr::pluck(list_labs, "y"),
    "Samples per 1,000 years"
  )

  testthat::expect_equal(purrr::pluck(list_labs, "x"), "Age (ka cal yr BP)")

  testthat::expect_equal(purrr::pluck(list_labs, "fill"), "Dataset Type")

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})

testthat::test_that("plot_sample_age_histogram() names the bin width", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  res <-
    plot_sample_age_histogram(
      data_sample_ages = tibble::tibble(
        dataset_type = c("vegetation plot", "vegetation plot"),
        age = c(100, 700)
      ),
      list_figure_style = list_figure_style,
      bin_width = 500
    )

  testthat::expect_equal(
    purrr::pluck(ggplot2::get_labs(res), "y"),
    "Samples per 500 years"
  )

  data_layer <-
    ggplot2::layer_data(plot = res, i = 1L)

  testthat::expect_equal(dplyr::pull(data_layer, x), c(250, 750))

  testthat::expect_equal(
    base::expm1(dplyr::pull(data_layer, ymax)),
    c(1, 1)
  )
})

testthat::test_that("plot_sample_age_histogram() leaves out missing ages", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  res <-
    plot_sample_age_histogram(
      data_sample_ages = tibble::tibble(
        dataset_type = c("vegetation plot", "vegetation plot"),
        age = c(100, NA)
      ),
      list_figure_style = list_figure_style
    )

  testthat::expect_equal(
    base::expm1(dplyr::pull(ggplot2::layer_data(plot = res, i = 1L), ymax)),
    1
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_age_histogram() validates its arguments", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_ages <-
    tibble::tibble(
      dataset_type = "vegetation plot",
      age = 100
    )

  testthat::expect_error(
    plot_sample_age_histogram(
      data_sample_ages = tibble::tibble(dataset_type = "vegetation plot"),
      list_figure_style = list_figure_style
    ),
    regexp = "age"
  )

  testthat::expect_error(
    plot_sample_age_histogram(
      data_sample_ages = data_ages,
      list_figure_style = "style"
    ),
    regexp = "list_figure_style"
  )

  testthat::expect_error(
    plot_sample_age_histogram(
      data_sample_ages = data_ages,
      list_figure_style = list_figure_style,
      bin_width = 0
    ),
    regexp = "bin_width"
  )

  testthat::expect_error(
    plot_sample_age_histogram(
      data_sample_ages = data_ages,
      list_figure_style = list_figure_style,
      age_max = c(1, 2)
    ),
    regexp = "age_max"
  )

  testthat::expect_error(
    plot_sample_age_histogram(
      data_sample_ages = tibble::tibble(
        dataset_type = "vegetation plot",
        age = NA_real_
      ),
      list_figure_style = list_figure_style
    ),
    regexp = "No sample"
  )
})
