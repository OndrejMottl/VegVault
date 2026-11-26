#' @title Plot the workflow of the data assembly
#' @description
#' Draw the figure of the data assembly of the website: the data sources,
#' the repositories that process them and the database, as boxes with
#' logos, numbers and dashed links.
#' @param data_nodes
#' A data frame with one row per node and the columns `id` (integer,
#' unique, the number shown), `x` and `y` (centre), `width` and `height`
#' (size; for a node without a box, the area of its logo), `colour` (name
#' of a colour of `list_colors`), `box` (logical: draw the box; `FALSE` for
#' a node that is only its logo), `logo` (path of a PNG file or `NA`),
#' `logo_size` (width of the logo as a share of the figure width, or `NA`),
#' `label` (text shown instead of a logo, or `NA`) and `icon` (`NA` or
#' `"repository"` for a book symbol).
#' @param data_edges
#' A data frame with the columns `from` and `to`, ids of `data_nodes`: one
#' row per link, drawn from the right side of `from` to the left side of
#' `to`, or to the top of `to` when `to` has no box.
#' @param list_colors
#' Named list of colours `#RRGGBB`, with every name used in
#' `data_nodes$colour` and the names `white`, `black` and `grey`.
#' @param color_background
#' Character scalar. Name of the colour of `list_colors` behind the
#' figure. Default: `"white"`.
#' @param color_link
#' Character scalar. Name of the colour of `list_colors` of the links.
#' Default: `"grey"`.
#' @return
#' A ggplot object with fixed aspect ratio and no axes.
#' @details
#' A box is a rounded rectangle (`build_rounded_rectangle()`) outlined in
#' the colour of its node, with the node number in a white circle at its
#' left side and the logo, label or book symbol in the remaining space. A
#' node without a box shows its logo, with its number below it. Each link
#' is a dashed curved arrow in `color_link` between two connection dots,
#' which take the colour of their node. Boxes stay white on
#' `color_background`. Logos are drawn with `ggimage::geom_image()`.
#' Aborts when a column is missing, an id is repeated, a link names an
#' unknown node, a colour name is not in `list_colors`, or a logo file
#' does not exist.
#' @seealso [build_rounded_rectangle()]
#' @examples
#' \dontrun{
#' plot_workflow <-
#'   plot_assembly_workflow(
#'     data_nodes = data_nodes,
#'     data_edges = data_edges,
#'     list_colors = list_colors
#'   )
#' }
plot_assembly_workflow <- function(
  data_nodes,
  data_edges,
  list_colors,
  color_background = "white",
  color_link = "grey"
) {
  assertthat::assert_that(
    base::is.data.frame(data_nodes),
    base::is.data.frame(data_edges),
    base::is.list(list_colors),
    msg = "`data_nodes` and `data_edges` must be data frames, `list_colors`
    a list."
  )

  assertthat::assert_that(
    rlang::is_string(color_background),
    rlang::is_string(color_link),
    msg = "`color_background` and `color_link` must each name one colour."
  )

  vec_columns_missing <-
    c(
      base::setdiff(
        c(
          "id", "x", "y", "width", "height", "colour", "box", "logo",
          "logo_size", "label", "icon"
        ),
        base::names(data_nodes)
      ),
      base::setdiff(c("from", "to"), base::names(data_edges))
    )

  if (
    base::length(vec_columns_missing) > 0L
  ) {
    cli::cli_abort(
      "The nodes or links lack the column{?s} {.val {vec_columns_missing}}."
    )
  }

  vec_ids <-
    dplyr::pull(data_nodes, id)

  if (
    base::anyDuplicated(vec_ids) > 0L
  ) {
    cli::cli_abort("Every node `id` must be unique.")
  }

  vec_ids_unknown <-
    base::setdiff(
      c(dplyr::pull(data_edges, from), dplyr::pull(data_edges, to)),
      vec_ids
    )

  if (
    base::length(vec_ids_unknown) > 0L
  ) {
    cli::cli_abort("Links name the unknown node{?s} {.val {vec_ids_unknown}}.")
  }

  vec_colors_unknown <-
    base::setdiff(
      c(
        dplyr::pull(data_nodes, colour), "white", "black", "grey",
        color_background, color_link
      ),
      base::names(list_colors)
    )

  if (
    base::length(vec_colors_unknown) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_colors_unknown}} {?is/are} not in `list_colors`."
    )
  }

  vec_logos <-
    data_nodes |>
    dplyr::pull(logo) |>
    stats::na.omit() |>
    base::as.character()

  vec_logos_missing <-
    vec_logos[!base::file.exists(vec_logos)]

  if (
    base::length(vec_logos_missing) > 0L
  ) {
    cli::cli_abort(
      "Logo file{?s} not found: {.file {base::basename(vec_logos_missing)}}."
    )
  }

  col_white <- purrr::chuck(list_colors, "white")
  col_black <- purrr::chuck(list_colors, "black")
  col_grey <- purrr::chuck(list_colors, "grey")
  col_background <- purrr::chuck(list_colors, color_background)
  col_link <- purrr::chuck(list_colors, color_link)

  # Positions inside each node: the number sits at the left side of a box
  #   (or below a node without a box), the logo, label or symbol in the
  #   middle of the space to its right
  data_nodes_placed <-
    data_nodes |>
    dplyr::mutate(
      col_node = purrr::map_chr(
        .x = colour,
        .f = ~ purrr::chuck(list_colors, .x)
      ),
      number_x = dplyr::if_else(box, x - width / 2 + 0.3 * height, x),
      number_y = dplyr::if_else(box, y, y - height / 2 - 0.3),
      content_x = dplyr::if_else(
        box,
        (x - width / 2 + 0.6 * height + x + width / 2) / 2,
        x
      )
    )

  # An empty outline still needs its columns for the layers below
  data_outline_empty <-
    tibble::tibble(
      id = vec_ids[0],
      x = base::double(0),
      y = base::double(0)
    )

  data_boxes <-
    data_nodes_placed |>
    dplyr::filter(box) |>
    dplyr::mutate(
      outline = purrr::pmap(
        .l = base::list(x, y, width, height),
        .f = ~ build_rounded_rectangle(
          x = ..1, y = ..2, width = ..3, height = ..4, radius = 0.18 * ..4
        )
      )
    ) |>
    dplyr::select("id", "col_node", "outline") |>
    tidyr::unnest("outline") |>
    dplyr::bind_rows(
      dplyr::mutate(data_outline_empty, col_node = base::character(0))
    )

  # The book symbol of a repository: a cover, the page edge and a bookmark
  data_books <-
    dplyr::filter(data_nodes_placed, icon %in% "repository")

  data_book_covers <-
    data_books |>
    dplyr::mutate(
      outline = purrr::pmap(
        .l = base::list(content_x, y, height),
        .f = ~ build_rounded_rectangle(
          x = ..1, y = ..2, width = 0.42 * ..3, height = 0.55 * ..3,
          radius = 0.05 * ..3
        )
      )
    ) |>
    dplyr::select("id", "outline") |>
    tidyr::unnest("outline") |>
    dplyr::bind_rows(data_outline_empty)

  data_book_ribbons <-
    data_books |>
    dplyr::mutate(
      bottom = y - 0.275 * height,
      ribbon = purrr::pmap(
        .l = base::list(content_x, bottom, height),
        .f = ~ tibble::tibble(
          x = ..1 + c(-0.06, 0.06, 0.06, 0, -0.06) * ..3,
          y = ..2 + c(0.12, 0.12, -0.1, -0.05, -0.1) * ..3
        )
      )
    ) |>
    dplyr::select("id", "ribbon") |>
    tidyr::unnest("ribbon") |>
    dplyr::bind_rows(data_outline_empty)

  data_book_pages <-
    dplyr::mutate(
      data_books,
      page_x = content_x - 0.21 * height,
      page_xend = content_x + 0.21 * height,
      page_y = y - 0.15 * height
    )

  # Links from the right side of a node to the left side of the next one,
  #   or to the top of a node without a box
  data_links <-
    data_edges |>
    dplyr::left_join(
      dplyr::select(
        data_nodes_placed,
        from = "id", from_x = "x", from_y = "y", from_width = "width",
        from_box = "box", from_col = "col_node"
      ),
      by = "from"
    ) |>
    dplyr::left_join(
      dplyr::select(
        data_nodes_placed,
        to = "id", to_x = "x", to_y = "y", to_width = "width",
        to_height = "height", to_box = "box", to_col = "col_node"
      ),
      by = "to"
    ) |>
    dplyr::mutate(
      x_start = dplyr::if_else(from_box, from_x + from_width / 2, from_x),
      y_start = from_y,
      x_end = dplyr::if_else(to_box, to_x - to_width / 2, to_x),
      y_end = dplyr::if_else(to_box, to_y, to_y + to_height / 2)
    )

  data_dots <-
    dplyr::bind_rows(
      dplyr::distinct(
        data_links,
        x = x_start, y = y_start, col_dot = from_col
      ),
      data_links |>
        dplyr::filter(to_box) |>
        dplyr::distinct(x = x_end, y = y_end, col_dot = to_col)
    )

  data_logos <-
    dplyr::filter(data_nodes_placed, !base::is.na(logo))

  # One layer per logo, as each logo has its own size
  list_logo_layers <-
    purrr::map(
      .x = base::seq_len(base::nrow(data_logos)),
      .f = ~ ggimage::geom_image(
        data = dplyr::slice(data_logos, .x),
        mapping = ggplot2::aes(x = content_x, y = y, image = logo),
        size = dplyr::pull(data_logos, logo_size)[.x]
      )
    )

  res <-
    ggplot2::ggplot() +
    ggplot2::scale_colour_identity() +
    ggplot2::coord_fixed(clip = "off") +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(
        fill = col_background,
        colour = NA
      )
    ) +
    ggplot2::geom_curve(
      data = data_links,
      mapping = ggplot2::aes(
        x = x_start, y = y_start, xend = x_end, yend = y_end
      ),
      curvature = -0.15,
      linetype = "dashed",
      linewidth = 0.8,
      colour = col_link,
      arrow = grid::arrow(
        length = grid::unit(3, "mm"),
        type = "closed"
      ),
      arrow.fill = col_link
    ) +
    ggplot2::geom_polygon(
      data = data_boxes,
      mapping = ggplot2::aes(x = x, y = y, group = id, colour = col_node),
      fill = col_white,
      linewidth = 1.6
    ) +
    ggplot2::geom_point(
      data = data_dots,
      mapping = ggplot2::aes(x = x, y = y, colour = col_dot),
      shape = 21,
      size = 5,
      stroke = 2.2,
      fill = col_grey
    ) +
    ggplot2::geom_polygon(
      data = data_book_covers,
      mapping = ggplot2::aes(x = x, y = y, group = id),
      fill = NA,
      colour = col_black,
      linewidth = 1.8
    ) +
    ggplot2::geom_segment(
      data = data_book_pages,
      mapping = ggplot2::aes(
        x = page_x, y = page_y, xend = page_xend, yend = page_y
      ),
      colour = col_black,
      linewidth = 1.8
    ) +
    ggplot2::geom_polygon(
      data = data_book_ribbons,
      mapping = ggplot2::aes(x = x, y = y, group = id),
      fill = col_black,
      colour = col_black
    ) +
    ggplot2::geom_text(
      data = dplyr::filter(data_nodes_placed, !base::is.na(label)),
      mapping = ggplot2::aes(
        x = content_x, y = y, label = label, colour = col_node
      ),
      fontface = "bold",
      size = 9
    ) +
    list_logo_layers +
    ggplot2::geom_point(
      data = data_nodes_placed,
      mapping = ggplot2::aes(x = number_x, y = number_y),
      shape = 21,
      size = 11,
      stroke = 1,
      colour = col_grey,
      fill = col_white
    ) +
    ggplot2::geom_text(
      data = data_nodes_placed,
      mapping = ggplot2::aes(x = number_x, y = number_y, label = id),
      size = 6,
      colour = col_black
    )

  return(res)
}
