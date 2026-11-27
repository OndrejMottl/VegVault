list_colors_workflow <-
  base::list(
    white = "#ffffff",
    black = "#242531",
    grey = "#999999",
    purple_light = "#aa6da3",
    green_dark = "#5f634f"
  )

data_edges_workflow <-
  tibble::tibble(from = c(1L, 2L, 3L), to = c(3L, 3L, 4L))


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("plot_assembly_workflow() returns a drawable plot", {
  path_logo <-
    base::file.path(withr::local_tempdir(), "logo.png")

  grDevices::png(filename = path_logo, width = 40L, height = 20L)
  graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new()
  grDevices::dev.off()

  data_nodes <-
    tibble::tibble(
      id = 1:4,
      x = c(2, 2, 8, 8),
      y = c(6, 2, 4, 0),
      width = c(3, 3, 3, 2),
      height = c(2, 2, 2, 2),
      colour = c("purple_light", "green_dark", "black", "black"),
      box = c(TRUE, TRUE, TRUE, FALSE),
      logo = c(path_logo, NA, NA, path_logo),
      logo_size = c(0.1, NA, NA, 0.1),
      label = c(NA, "HWSD v2.2", NA, NA),
      icon = c(NA, NA, "repository", NA)
    )

  res <-
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = data_edges_workflow,
      list_colors = list_colors_workflow
    )

  testthat::expect_s3_class(res, "ggplot")

  testthat::expect_no_error(ggplot2::ggplot_build(res))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("plot_assembly_workflow() draws one arrow per link", {
  data_nodes <-
    tibble::tibble(
      id = 1:4,
      x = c(2, 2, 8, 8),
      y = c(6, 2, 4, 0),
      width = c(3, 3, 3, 3),
      height = c(2, 2, 2, 2),
      colour = c("purple_light", "green_dark", "black", "black"),
      box = TRUE,
      logo = NA_character_,
      logo_size = NA_real_,
      label = c("A", "B", "C", "D"),
      icon = NA_character_
    )

  res <-
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = data_edges_workflow,
      list_colors = list_colors_workflow
    )

  list_curve_layers <-
    purrr::keep(
      .x = purrr::pluck(res, "layers"),
      .p = ~ base::inherits(purrr::pluck(.x, "geom"), "GeomCurve")
    )

  testthat::expect_length(list_curve_layers, 1L)

  testthat::expect_equal(
    base::nrow(purrr::pluck(list_curve_layers, 1L, "data")),
    3L
  )

  # The arrow to node 3 ends at its left side, x = 8 - 3 / 2
  index_curve_layer <-
    purrr::detect_index(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::inherits(purrr::pluck(.x, "geom"), "GeomCurve")
    )

  testthat::expect_equal(
    dplyr::pull(ggplot2::layer_data(res, index_curve_layer), xend)[1],
    6.5
  )
})

testthat::test_that("plot_assembly_workflow() takes the background colour", {
  data_nodes <-
    tibble::tibble(
      id = 1:2,
      x = c(2, 8),
      y = c(2, 2),
      width = 3,
      height = 2,
      colour = "black",
      box = TRUE,
      logo = NA_character_,
      logo_size = NA_real_,
      label = c("A", "B"),
      icon = NA_character_
    )

  res <-
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = tibble::tibble(from = 1L, to = 2L),
      list_colors = c(
        list_colors_workflow,
        base::list(brown_light = "#bc7052")
      ),
      color_background = "brown_light",
      color_link = "black"
    )

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

  index_curve_layer <-
    purrr::detect_index(
      .x = purrr::pluck(res, "layers"),
      .f = ~ base::inherits(purrr::pluck(.x, "geom"), "GeomCurve")
    )

  testthat::expect_equal(
    dplyr::pull(ggplot2::layer_data(res, index_curve_layer), colour),
    "#242531"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("plot_assembly_workflow() refuses unknown nodes", {
  data_nodes <-
    tibble::tibble(
      id = 1:2,
      x = c(2, 8),
      y = c(2, 2),
      width = 3,
      height = 2,
      colour = "black",
      box = TRUE,
      logo = NA_character_,
      logo_size = NA_real_,
      label = c("A", "B"),
      icon = NA_character_
    )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = tibble::tibble(from = 1L, to = 5L),
      list_colors = list_colors_workflow
    ),
    regexp = "5"
  )
})

testthat::test_that("plot_assembly_workflow() refuses unknown colours", {
  data_nodes <-
    tibble::tibble(
      id = 1L,
      x = 2,
      y = 2,
      width = 3,
      height = 2,
      colour = "orange",
      box = TRUE,
      logo = NA_character_,
      logo_size = NA_real_,
      label = "A",
      icon = NA_character_
    )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = tibble::tibble(from = integer(0), to = integer(0)),
      list_colors = list_colors_workflow
    ),
    regexp = "orange"
  )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = dplyr::mutate(data_nodes, colour = "black"),
      data_edges = tibble::tibble(from = integer(0), to = integer(0)),
      list_colors = list_colors_workflow,
      color_background = "brown_light"
    ),
    regexp = "brown_light"
  )
})

testthat::test_that("plot_assembly_workflow() needs the logo files", {
  data_nodes <-
    tibble::tibble(
      id = 1L,
      x = 2,
      y = 2,
      width = 3,
      height = 2,
      colour = "black",
      box = TRUE,
      logo = base::file.path(withr::local_tempdir(), "missing.png"),
      logo_size = 0.1,
      label = NA_character_,
      icon = NA_character_
    )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = tibble::tibble(from = integer(0), to = integer(0)),
      list_colors = list_colors_workflow
    ),
    regexp = "missing.png"
  )
})

testthat::test_that("plot_assembly_workflow() needs its columns and ids", {
  data_nodes <-
    tibble::tibble(
      id = c(1L, 1L),
      x = c(2, 8),
      y = c(2, 2),
      width = 3,
      height = 2,
      colour = "black",
      box = TRUE,
      logo = NA_character_,
      logo_size = NA_real_,
      label = c("A", "B"),
      icon = NA_character_
    )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = data_nodes,
      data_edges = tibble::tibble(from = integer(0), to = integer(0)),
      list_colors = list_colors_workflow
    ),
    regexp = "id"
  )

  testthat::expect_error(
    plot_assembly_workflow(
      data_nodes = dplyr::select(data_nodes, -"icon"),
      data_edges = tibble::tibble(from = integer(0), to = integer(0)),
      list_colors = list_colors_workflow
    ),
    regexp = "icon"
  )
})
