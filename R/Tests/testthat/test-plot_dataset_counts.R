#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_dataset_counts() combines waffle and lollipop", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_counts <-
    tibble::tibble(
      dataset_type = c(
        "fossil_pollen_archive", "gridpoints", "traits",
        "vegetation_plot", "vegetation_plot"
      ),
      dataset_source_type = c(
        "FOSSILPOL", "gridpoints", "TRY", "BIEN", "sPlotOpen"
      ),
      n_datasets = c(4000L, 120000L, 30000L, 60000L, 90000L)
    )

  res <-
    plot_dataset_counts(
      data_dataset_counts = data_counts,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  # One cowplot layer per part
  testthat::expect_length(purrr::pluck(res, "layers"), 2L)

  vec_labels <-
    collect_grob_labels(grob = ggplot2::ggplotGrob(res))

  # 304,000 datasets: 304 squares of 1000 datasets
  testthat::expect_true("one square is 1000 Datasets" %in% vec_labels)

  testthat::expect_true("Neotoma - FOSSILPOL" %in% vec_labels)

  testthat::expect_false("FOSSILPOL" %in% vec_labels)

  testthat::expect_true(
    base::all(
      c(
        "vegetation plot", "gridpoints", "traits", "fossil pollen archive",
        "Number of Datasets"
      ) %in% vec_labels
    )
  )
})

testthat::test_that("plot_dataset_counts() leaves out missing sources", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  res <-
    plot_dataset_counts(
      data_dataset_counts = tibble::tibble(
        dataset_type = c("traits", "traits", "gridpoints"),
        dataset_source_type = c("TRY", NA, "gridpoints"),
        n_datasets = c(5L, 2L, 3L)
      ),
      list_figure_style = list_figure_style
    )

  # A lollipop for the missing source would be dropped with a warning
  testthat::expect_no_warning(
    grob_res <-
      ggplot2::ggplotGrob(res)
  )

  vec_labels <-
    collect_grob_labels(grob = grob_res)

  # The waffle counts all 10 datasets; the lollipops show named sources
  testthat::expect_true("one square is 1 Datasets" %in% vec_labels)

  testthat::expect_false("NA" %in% vec_labels)

  testthat::expect_true(base::all(c("TRY", "gridpoints") %in% vec_labels))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("plot_dataset_counts() draws a small database", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  # 11 datasets: with one square per 1000 datasets the waffle would be
  #   empty
  data_counts <-
    tibble::tibble(
      dataset_type = c("fossil_pollen_archive", "gridpoints", "traits"),
      dataset_source_type = c("FOSSILPOL", "gridpoints", "TRY"),
      n_datasets = c(2L, 8L, 1L)
    )

  res <-
    plot_dataset_counts(
      data_dataset_counts = data_counts,
      list_figure_style = list_figure_style
    )

  testthat::expect_no_error(ggplot2::ggplotGrob(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_dataset_counts() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_dataset_counts(
      data_dataset_counts = tibble::tibble(dataset_type = "traits"),
      list_figure_style = list_figure_style
    ),
    regexp = "n_datasets"
  )
})
