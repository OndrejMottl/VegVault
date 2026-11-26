list_colors_diagram <-
  base::list(
    white = "#ffffff",
    black = "#242531",
    grey = "#999999",
    beige_light = "#e6b482",
    brown_light = "#bc7052"
  )

list_fonts_diagram <-
  base::list(text = "sans", code = "mono")

data_boxes_diagram <-
  tibble::tibble(
    x = c(2, 8),
    y = c(2, 2),
    width = c(3, 3),
    height = c(2, 2),
    fill = c("beige_light", "white"),
    colour = c("black", NA)
  )

data_texts_diagram <-
  tibble::tibble(
    x = c(2, 7),
    y = c(2, 2),
    label = c("Which taxa?", "get_taxa()"),
    size = c(4, 3),
    colour = "black",
    font = c("text", "code"),
    fontface = c("plain", "bold"),
    hjust = c(0.5, 0)
  )

data_links_diagram <-
  tibble::tibble(x = 2, y = 1, xend = 8, yend = 1)

data_numbers_diagram <-
  tibble::tibble(x = 1, y = 2.5, label = "3")

data_images_none <-
  tibble::tibble(
    x = base::double(0),
    y = base::double(0),
    path = base::character(0),
    size = base::double(0)
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_diagram() returns a drawable plot", {
  path_image <-
    base::file.path(withr::local_tempdir(), "logo.png")

  grDevices::png(filename = path_image, width = 40L, height = 20L)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  grDevices::dev.off()

  res <-
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = data_texts_diagram,
      data_images = tibble::tibble(x = 5, y = 3, path = path_image, size = 0.1),
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    )

  testthat::expect_s3_class(res, "ggplot")

  testthat::expect_no_error(ggplot2::ggplot_build(res))

  testthat::expect_true(
    purrr::some(
      .x = purrr::pluck(res, "layers"),
      .p = ~ base::inherits(purrr::pluck(.x, "geom"), "GeomImage")
    )
  )
})

testthat::test_that("plot_diagram() draws without images and links", {
  res <-
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = data_texts_diagram,
      data_images = data_images_none,
      data_links = dplyr::slice(data_links_diagram, 0),
      data_numbers = dplyr::slice(data_numbers_diagram, 0),
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    )

  testthat::expect_no_error(ggplot2::ggplot_build(res))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("plot_diagram() gives the elements their colours", {
  res <-
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = data_texts_diagram,
      data_images = data_images_none,
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4),
      color_background = "brown_light"
    )

  vec_layer_geoms <-
    purrr::map_chr(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::class(purrr::pluck(.x, "geom"))[1]
    )

  # Boxes: the fill of each box, and an outline only where one is named
  data_box_layer <-
    ggplot2::layer_data(
      res,
      base::which(vec_layer_geoms == "GeomPolygon")[1]
    ) |>
    dplyr::distinct(group, fill, colour) |>
    dplyr::arrange(group)

  testthat::expect_equal(
    dplyr::pull(data_box_layer, fill),
    c("#e6b482", "#ffffff")
  )

  testthat::expect_equal(
    dplyr::pull(data_box_layer, colour),
    c("#242531", NA)
  )

  # Texts: the font of each text, by its kind
  data_text_layer <-
    ggplot2::layer_data(
      res,
      base::which(vec_layer_geoms == "GeomText")[1]
    )

  testthat::expect_equal(
    dplyr::pull(data_text_layer, family),
    c("sans", "mono")
  )

  testthat::expect_equal(
    dplyr::pull(data_text_layer, colour),
    c("#242531", "#242531")
  )

  # Links: one dashed segment, with a dot at each end
  data_link_layer <-
    ggplot2::layer_data(
      res,
      base::which(vec_layer_geoms == "GeomSegment")
    )

  testthat::expect_equal(base::nrow(data_link_layer), 1L)

  testthat::expect_equal(dplyr::pull(data_link_layer, linetype), "dashed")

  data_point_layers <-
    purrr::map(
      .x = base::which(vec_layer_geoms == "GeomPoint"),
      .f = ~ ggplot2::layer_data(res, .x)
    )

  testthat::expect_equal(
    base::unname(purrr::map_int(data_point_layers, base::nrow)),
    c(2L, 1L)
  )

  # Background
  grob_res <-
    ggplot2::ggplotGrob(res)

  grob_background <-
    purrr::pluck(
      grob_res,
      "grobs",
      base::which(purrr::pluck(grob_res, "layout", "name") == "background")
    )

  testthat::expect_equal(
    purrr::pluck(grob_background, "gp", "fill"),
    "#bc7052"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_diagram() needs its columns", {
  testthat::expect_error(
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = dplyr::select(data_texts_diagram, -"hjust"),
      data_images = data_images_none,
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    ),
    regexp = "hjust"
  )
})

testthat::test_that("plot_diagram() refuses unknown colours and fonts", {
  testthat::expect_error(
    plot_diagram(
      data_boxes = dplyr::mutate(data_boxes_diagram, fill = "orange"),
      data_texts = data_texts_diagram,
      data_images = data_images_none,
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    ),
    regexp = "orange"
  )

  testthat::expect_error(
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = dplyr::mutate(data_texts_diagram, font = "title"),
      data_images = data_images_none,
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    ),
    regexp = "title"
  )
})

testthat::test_that("plot_diagram() needs the image files and limits", {
  testthat::expect_error(
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = data_texts_diagram,
      data_images = tibble::tibble(
        x = 5,
        y = 3,
        path = base::file.path(withr::local_tempdir(), "missing.png"),
        size = 0.1
      ),
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = c(0, 10),
      y_lim = c(0, 4)
    ),
    regexp = "missing.png"
  )

  testthat::expect_error(
    plot_diagram(
      data_boxes = data_boxes_diagram,
      data_texts = data_texts_diagram,
      data_images = data_images_none,
      data_links = data_links_diagram,
      data_numbers = data_numbers_diagram,
      list_colors = list_colors_diagram,
      list_fonts = list_fonts_diagram,
      x_lim = 10,
      y_lim = c(0, 4)
    ),
    regexp = "x_lim"
  )
})
