#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_manuscript_figure() writes the figure file", {
  dir_figures <-
    base::file.path(withr::local_tempdir(), "Figures")

  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  res <-
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig_example.pdf", width = "single", height = 60
      ),
      list_figure_style = list(
        image_width = c(single = 89, full = 247),
        image_units = "mm",
        colors = list(white = "#ffffff")
      )
    )

  testthat::expect_equal(res, base::file.path(dir_figures, "fig_example.pdf"))

  testthat::expect_true(base::file.exists(res))

  testthat::expect_gt(base::file.size(res), 0)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_manuscript_figure() uses the configured size", {
  dir_figures <-
    withr::local_tempdir()

  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  path_png <-
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig_example.png", width = "single", height = 60
      ),
      list_figure_style = list(
        image_width = c(single = 89, full = 247),
        image_units = "mm",
        colors = list(white = "#ffffff")
      )
    )

  vec_png_header <-
    base::readBin(path_png, what = "raw", n = 24L)

  # Width and height in pixels are bytes 17 to 24 of a PNG file; ggsave
  #   uses 300 dpi
  n_width_px <-
    base::sum(base::as.integer(vec_png_header[17:20]) * 256^(3:0))

  n_height_px <-
    base::sum(base::as.integer(vec_png_header[21:24]) * 256^(3:0))

  # The device may truncate or round the pixel count
  testthat::expect_lte(base::abs(n_width_px - 89 / 25.4 * 300), 1)

  testthat::expect_lte(base::abs(n_height_px - 60 / 25.4 * 300), 1)
})

testthat::test_that("save_manuscript_figure() replaces an existing file", {
  dir_figures <-
    withr::local_tempdir()

  path_old <-
    base::file.path(dir_figures, "fig_example.pdf")

  base::writeLines(text = "old", con = path_old)

  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  save_manuscript_figure(
    plot = plot_example,
    dir_figures = dir_figures,
    list_figure_file = list(
      file_name = "fig_example.pdf", width = "full", height = 60
    ),
    list_figure_style = list(
      image_width = c(full = 247),
      image_units = "mm",
      colors = list(white = "#ffffff")
    )
  )

  vec_header <-
    base::readBin(path_old, what = "raw", n = 4L)

  testthat::expect_equal(base::rawToChar(vec_header), "%PDF")
})

testthat::test_that("save_manuscript_figure() saves a grob", {
  dir_figures <-
    withr::local_tempdir()

  grob_example <-
    ggplot2::ggplotGrob(
      ggplot2::ggplot(
        data = tibble::tibble(x = 1:3, y = 1:3),
        mapping = ggplot2::aes(x = x, y = y)
      ) +
        ggplot2::geom_point()
    )

  res <-
    save_manuscript_figure(
      plot = grob_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig_grob.pdf", width = "full", height = 60
      ),
      list_figure_style = list(
        image_width = c(full = 247),
        image_units = "mm",
        colors = list(white = "#ffffff")
      )
    )

  testthat::expect_true(base::file.exists(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_manuscript_figure() validates the settings", {
  dir_figures <-
    withr::local_tempdir()

  plot_example <-
    ggplot2::ggplot(
      data = tibble::tibble(x = 1:3, y = 1:3),
      mapping = ggplot2::aes(x = x, y = y)
    ) +
    ggplot2::geom_point()

  list_style <-
    list(
      image_width = c(full = 247),
      image_units = "mm",
      colors = list(white = "#ffffff")
    )

  testthat::expect_error(
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig.pdf", width = "triple", height = 60
      ),
      list_figure_style = list_style
    ),
    regexp = "triple"
  )

  testthat::expect_error(
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "../fig.pdf", width = "full", height = 60
      ),
      list_figure_style = list_style
    ),
    regexp = "file_name"
  )

  testthat::expect_error(
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig.svg", width = "full", height = 60
      ),
      list_figure_style = list_style
    ),
    regexp = "file_name"
  )

  testthat::expect_error(
    save_manuscript_figure(
      plot = plot_example,
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig.pdf", width = "full", height = -1
      ),
      list_figure_style = list_style
    ),
    regexp = "height"
  )

  testthat::expect_error(
    save_manuscript_figure(
      plot = "plot",
      dir_figures = dir_figures,
      list_figure_file = list(
        file_name = "fig.pdf", width = "full", height = 60
      ),
      list_figure_style = list_style
    ),
    regexp = "plot"
  )

  testthat::expect_length(base::list.files(dir_figures), 0L)
})
