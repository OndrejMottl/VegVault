#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_waffle() returns a waffle chart", {
  data_counts <-
    tibble::tibble(
      dataset_type = c("traits", "gridpoints"),
      N = c(2500, 4100)
    )

  res <-
    plot_waffle(
      data_source = data_counts,
      var_name = dataset_type,
      one_point_is = 1e3,
      col_background = "#ffffff",
      col_lines = "#000000",
      data_point_name = "Datasets"
    )

  testthat::expect_true(ggplot2::is_ggplot(res))

  testthat::expect_equal(
    purrr::pluck(ggplot2::get_labs(res), "caption"),
    "One square is 1,000 Datasets"
  )

  testthat::expect_equal(
    dplyr::pull(purrr::pluck(res, "data"), N_work),
    c(2, 4)
  )

  testthat::expect_s3_class(
    purrr::pluck(res, "layers", 1L, "geom"),
    "GeomWaffle"
  )

  testthat::expect_no_error(ggplot2::ggplot_build(res))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("plot_waffle() keeps its settings over a base theme", {
  data_counts <-
    tibble::tibble(
      dataset_type = c("traits", "gridpoints"),
      N = c(2500, 4100)
    )

  res <-
    plot_waffle(
      data_source = data_counts,
      var_name = dataset_type,
      one_point_is = 1e3,
      col_background = "#123456",
      col_lines = "#000000",
      theme_base = ggplot2::theme_minimal(base_size = 21)
    )

  theme_res <-
    purrr::pluck(res, "theme")

  testthat::expect_true(ggplot2::is_theme(theme_res))

  # The base theme sets the text size; the waffle keeps its background and
  #   hides the axes
  testthat::expect_equal(
    purrr::pluck(
      ggplot2::calc_element(element = "text", theme = theme_res),
      "size"
    ),
    21
  )

  testthat::expect_equal(
    purrr::pluck(
      ggplot2::calc_element(element = "panel.background", theme = theme_res),
      "fill"
    ),
    "#123456"
  )

  testthat::expect_s3_class(
    ggplot2::calc_element(element = "axis.text.x", theme = theme_res),
    "ggplot2::element_blank"
  )
})

testthat::test_that("plot_waffle() adds no base theme by default", {
  data_counts <-
    tibble::tibble(
      dataset_type = c("traits", "gridpoints"),
      N = c(2500, 4100)
    )

  res <-
    plot_waffle(
      data_source = data_counts,
      var_name = dataset_type,
      col_background = "#ffffff",
      col_lines = "#000000"
    )

  # Without a base theme the session theme completes the plot, as the
  #   website expects
  testthat::expect_false(
    base::isTRUE(base::attributes(purrr::pluck(res, "theme"))[["complete"]])
  )
})

testthat::test_that("plot_waffle() sets the rows from the counts", {
  data_counts <-
    tibble::tibble(
      dataset_type = c("traits", "gridpoints"),
      N = c(20, 30)
    )

  res <-
    plot_waffle(
      data_source = data_counts,
      var_name = dataset_type,
      col_background = "#ffffff",
      col_lines = "#000000"
    )

  # floor(sqrt(50)) = 7 rows
  testthat::expect_equal(
    purrr::pluck(res, "layers", 1L, "geom_params", "n_rows"),
    7
  )
})
