#' @title Plot a diagram of boxes, texts, images and links
#' @description
#' Draw a diagram for the website from tables of its elements: rounded
#' boxes, texts, images, dashed links with connection dots, and numbers in
#' circles.
#' @param data_boxes
#' A data frame with one row per box and the columns `x` and `y` (centre),
#' `width`, `height`, `fill` and `colour` (names of colours of
#' `list_colors` for the fill and the outline; `NA` for none).
#' @param data_texts
#' A data frame with one row per text and the columns `x`, `y`, `label`,
#' `size` (in mm, as `ggplot2::geom_text()` takes it), `colour` (name of a
#' colour of `list_colors`), `font` (name of a font of `list_fonts`),
#' `fontface` (`"plain"`, `"bold"`, `"italic"` or `"bold.italic"`) and
#' `hjust` (0 left, 0.5 centre, 1 right). A label may hold line breaks.
#' @param data_images
#' A data frame with one row per image and the columns `x` and `y`
#' (centre), `path` (PNG file) and `size` (width of the image as a share
#' of the width of the diagram). May have no rows.
#' @param data_links
#' A data frame with one row per link and the columns `x`, `y`, `xend` and
#' `yend`. May have no rows.
#' @param data_numbers
#' A data frame with one row per number and the columns `x`, `y` and
#' `label`. May have no rows.
#' @param list_colors
#' Named list of colours `#RRGGBB`, with every colour name of `data_boxes`
#' and `data_texts`, `color_background` and the names `white`, `black` and
#' `grey`.
#' @param list_fonts
#' Named list of font families, with every name of `data_texts$font` and
#' the name `text` (used for the numbers).
#' @param x_lim,y_lim
#' Numeric vectors of length 2. The extent of the diagram, in the units of
#' the coordinates; saved at the same width and height in mm, one unit is
#' one mm.
#' @param color_background
#' Character scalar. Name of the colour of `list_colors` behind the
#' diagram. Default: `"white"`.
#' @return
#' A ggplot object with fixed aspect ratio, no axes and no margins.
#' @details
#' Layers are drawn in this order: links (dashed, `black`), boxes
#' (rounded rectangles of `build_rounded_rectangle()`, so a box hides the
#' links behind it), connection dots at both ends of each link (`grey`
#' with a `black` outline), images (`ggimage::geom_image()`), texts and
#' the numbers (`black` in `white` circles with a `grey` outline). Aborts
#' when a column is missing, a colour or font is not in its list, an image
#' file does not exist, or a limit is not two increasing numbers.
#' @seealso [build_rounded_rectangle()], [save_icon_png()]
#' @examples
#' \dontrun{
#' plot_extraction <-
#'   plot_diagram(
#'     data_boxes = data_boxes,
#'     data_texts = data_texts,
#'     data_images = data_images,
#'     data_links = data_links,
#'     data_numbers = data_numbers,
#'     list_colors = list_colors,
#'     list_fonts = base::list(text = "Inter", code = "Consolas"),
#'     x_lim = c(0, 180),
#'     y_lim = c(0, 230)
#'   )
#' }
plot_diagram <- function(
  data_boxes,
  data_texts,
  data_images,
  data_links,
  data_numbers,
  list_colors,
  list_fonts,
  x_lim,
  y_lim,
  color_background = "white"
) {
  list_data <-
    base::list(
      data_boxes = data_boxes,
      data_texts = data_texts,
      data_images = data_images,
      data_links = data_links,
      data_numbers = data_numbers
    )

  assertthat::assert_that(
    base::all(purrr::map_lgl(list_data, base::is.data.frame)),
    base::is.list(list_colors),
    base::is.list(list_fonts),
    msg = "The elements must be data frames, the colours and fonts lists."
  )

  assertthat::assert_that(
    base::is.numeric(x_lim),
    base::length(x_lim) == 2L,
    !base::anyNA(x_lim),
    x_lim[1] < x_lim[2],
    msg = "`x_lim` must be two increasing numbers."
  )

  assertthat::assert_that(
    base::is.numeric(y_lim),
    base::length(y_lim) == 2L,
    !base::anyNA(y_lim),
    y_lim[1] < y_lim[2],
    msg = "`y_lim` must be two increasing numbers."
  )

  assertthat::assert_that(
    rlang::is_string(color_background),
    msg = "`color_background` must name one colour."
  )

  list_columns <-
    base::list(
      data_boxes = c("x", "y", "width", "height", "fill", "colour"),
      data_texts = c(
        "x", "y", "label", "size", "colour", "font", "fontface", "hjust"
      ),
      data_images = c("x", "y", "path", "size"),
      data_links = c("x", "y", "xend", "yend"),
      data_numbers = c("x", "y", "label")
    )

  vec_columns_missing <-
    purrr::map2(
      .x = list_data,
      .y = list_columns,
      .f = ~ base::setdiff(.y, base::names(.x))
    ) |>
    purrr::list_c(ptype = base::character(0))

  if (
    base::length(vec_columns_missing) > 0L
  ) {
    cli::cli_abort(
      "The elements lack the column{?s} {.val {vec_columns_missing}}."
    )
  }

  vec_colors_unknown <-
    c(
      dplyr::pull(data_boxes, fill),
      dplyr::pull(data_boxes, colour),
      dplyr::pull(data_texts, colour),
      "white", "black", "grey", color_background
    ) |>
    stats::na.omit() |>
    base::setdiff(base::names(list_colors))

  if (
    base::length(vec_colors_unknown) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_colors_unknown}} {?is/are} not in `list_colors`."
    )
  }

  vec_fonts_unknown <-
    base::setdiff(
      c(dplyr::pull(data_texts, font), "text"),
      base::names(list_fonts)
    )

  if (
    base::length(vec_fonts_unknown) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_fonts_unknown}} {?is/are} not in `list_fonts`."
    )
  }

  vec_images <-
    base::as.character(dplyr::pull(data_images, path))

  vec_images_missing <-
    vec_images[!base::file.exists(vec_images)]

  if (
    base::length(vec_images_missing) > 0L
  ) {
    cli::cli_abort(
      "Image file{?s} not found: {.file {base::basename(vec_images_missing)}}."
    )
  }

  # Colour names to colours; a missing name stays missing (no outline)
  vec_colors <-
    base::unlist(list_colors)

  vec_fonts <-
    base::unlist(list_fonts)

  col_white <- purrr::chuck(list_colors, "white")
  col_black <- purrr::chuck(list_colors, "black")
  col_grey <- purrr::chuck(list_colors, "grey")

  data_box_outlines <-
    data_boxes |>
    dplyr::mutate(
      box_id = dplyr::row_number(),
      col_fill = base::unname(vec_colors[fill]),
      col_outline = base::unname(vec_colors[colour]),
      outline = purrr::pmap(
        .l = base::list(x, y, width, height),
        .f = ~ build_rounded_rectangle(
          x = ..1, y = ..2, width = ..3, height = ..4,
          radius = 0.15 * base::min(..3, ..4)
        )
      )
    ) |>
    dplyr::select("box_id", "col_fill", "col_outline", "outline") |>
    tidyr::unnest("outline") |>
    dplyr::bind_rows(
      tibble::tibble(
        box_id = base::integer(0),
        col_fill = base::character(0),
        col_outline = base::character(0),
        x = base::double(0),
        y = base::double(0)
      )
    )

  data_texts_drawn <-
    dplyr::mutate(
      data_texts,
      col_text = base::unname(vec_colors[colour]),
      family = base::unname(vec_fonts[font])
    )

  data_dots <-
    dplyr::bind_rows(
      dplyr::select(data_links, "x", "y"),
      dplyr::select(data_links, x = "xend", y = "yend")
    ) |>
    dplyr::distinct()

  # Image sizes as shares of the width: ggimage scales by the height of the
  #   panel unless told the shape of the diagram
  value_aspect <-
    base::diff(x_lim) / base::diff(y_lim)

  # One layer per image, as each image has its own size
  list_image_layers <-
    purrr::map(
      .x = base::seq_len(base::nrow(data_images)),
      .f = ~ ggimage::geom_image(
        data = dplyr::slice(data_images, .x),
        mapping = ggplot2::aes(x = x, y = y, image = path),
        size = dplyr::pull(data_images, size)[.x],
        asp = value_aspect
      )
    )

  res <-
    ggplot2::ggplot() +
    ggplot2::scale_colour_identity() +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_size_identity() +
    ggplot2::coord_fixed(
      xlim = x_lim,
      ylim = y_lim,
      expand = FALSE,
      clip = "off"
    ) +
    ggplot2::theme_void() +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(
        fill = purrr::chuck(list_colors, color_background),
        colour = NA
      ),
      plot.margin = ggplot2::margin(0, 0, 0, 0)
    ) +
    ggplot2::geom_segment(
      data = data_links,
      mapping = ggplot2::aes(x = x, y = y, xend = xend, yend = yend),
      linetype = "dashed",
      linewidth = 0.8,
      colour = col_black
    ) +
    ggplot2::geom_polygon(
      data = data_box_outlines,
      mapping = ggplot2::aes(
        x = x,
        y = y,
        group = box_id,
        fill = col_fill,
        colour = col_outline
      ),
      linewidth = 1.4
    ) +
    ggplot2::geom_point(
      data = data_dots,
      mapping = ggplot2::aes(x = x, y = y),
      shape = 21,
      size = 4,
      stroke = 1.6,
      colour = col_black,
      fill = col_grey
    ) +
    list_image_layers +
    ggplot2::geom_text(
      data = data_texts_drawn,
      mapping = ggplot2::aes(
        x = x,
        y = y,
        label = label,
        size = size,
        colour = col_text,
        family = family,
        fontface = fontface,
        hjust = hjust
      ),
      lineheight = 0.9
    ) +
    ggplot2::geom_point(
      data = data_numbers,
      mapping = ggplot2::aes(x = x, y = y),
      shape = 21,
      size = 10,
      stroke = 1,
      colour = col_grey,
      fill = col_white
    ) +
    ggplot2::geom_text(
      data = data_numbers,
      mapping = ggplot2::aes(x = x, y = y, label = label),
      size = 5,
      colour = col_black,
      family = purrr::chuck(list_fonts, "text")
    )

  return(res)
}
