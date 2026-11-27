#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_trait_example() combines three panels", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  res <-
    plot_trait_example(
      data_dataset_age_ranges = tibble::tibble(
        dataset_id = c(8L, 10L),
        age_min = c(7000, 6000),
        age_mean = c(9000, 8000),
        age_max = c(11000, 10000)
      ),
      data_taxa_per_sample = tibble::tibble(
        dataset_id = c(8L, 8L, 10L),
        sample_id = c(9L, 10L, 20L),
        coord_long = c(-70, -70, -60),
        coord_lat = c(-20, -20, -10),
        n_taxa = c(2L, 5L, 12L)
      ),
      data_trait_by_taxon = tibble::tibble(
        taxon_id_trait = c(2L, 5L, 7L),
        trait_value_mean = c(30, 20, 2)
      ),
      value_label = "Average Plant Height\nper genera",
      list_figure_style = list_figure_style
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  testthat::expect_length(purrr::pluck(res, "layers"), 3L)

  vec_labels <-
    collect_grob_labels(grob = ggplot2::ggplotGrob(res))

  testthat::expect_true(
    base::all(
      c(
        "Age (ka cal yr BP)", "Datasets", "N genera per Sample",
        "Average Plant Height\nper genera"
      ) %in% vec_labels
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_trait_example() validates its data", {
  list_figure_style <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(path_colors = here::here("colors.json"))
    )

  testthat::expect_error(
    plot_trait_example(
      data_dataset_age_ranges = tibble::tibble(dataset_id = 8L),
      data_taxa_per_sample = tibble::tibble(n_taxa = 2L),
      data_trait_by_taxon = tibble::tibble(trait_value_mean = 30),
      value_label = "Height",
      list_figure_style = list_figure_style
    ),
    regexp = "age_mean"
  )

  testthat::expect_error(
    plot_trait_example(
      data_dataset_age_ranges = tibble::tibble(
        dataset_id = 8L, age_min = 7000, age_mean = 9000, age_max = 11000
      ),
      data_taxa_per_sample = tibble::tibble(n_taxa = 2L),
      data_trait_by_taxon = tibble::tibble(trait_value_mean = 30),
      value_label = NA_character_,
      list_figure_style = list_figure_style
    ),
    regexp = "value_label"
  )
})
