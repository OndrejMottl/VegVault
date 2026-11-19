#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_coverage() combines map and histogram", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  data_sample_ages <-
    tibble::tibble(
      dataset_id = c(1L, 2L, 7L, 7L, 8L),
      dataset_type = c(
        "vegetation_plot", "vegetation_plot", "fossil_pollen_archive",
        "fossil_pollen_archive", "fossil_pollen_archive"
      ),
      coord_long = c(14, 16, -90, -90, -70),
      coord_lat = c(50, 49.5, 50, 50, -20),
      age = c(0, 0, 1000, 6000, 7000)
    )

  res <-
    plot_sample_coverage(
      data_dataset_sample_ages = data_sample_ages,
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  # The legend row and the row of map and histogram
  testthat::expect_length(purrr::pluck(res, "layers"), 2L)

  vec_labels <-
    collect_grob_labels(grob = ggplot2::ggplotGrob(res))

  # Map, histogram and the shared legend with types shown with spaces
  testthat::expect_true(
    base::all(
      c(
        "Longitude", "Age (ka cal yr BP)", "Number of Samples",
        "Dataset Type", "vegetation plot", "fossil pollen archive"
      ) %in% vec_labels
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_sample_coverage() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_sample_coverage(
      data_dataset_sample_ages = tibble::tibble(dataset_id = 1L),
      list_figure_style = list_figure_style
    ),
    regexp = "coord_long"
  )
})
