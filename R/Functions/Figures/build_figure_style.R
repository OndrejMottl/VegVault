#' @title Build the style of the manuscript figures
#' @description
#' Combine the manuscript settings of `config.yml` and the project colours
#' into one list that every manuscript plot function takes: the ggplot2
#' theme, sizes, colours and palettes.
#' @param list_graphical
#' Named list. The `graphical: manuscript` section of `config.yml`, with
#' the numeric scalars `text_size`, `line_size`, `point_size` and
#' `text_wrap_width`, the text `image_units`, the named list `image_width`
#' (widths in `image_units`) and the named list `colors` of colours that
#' replace or add to the project colours.
#' @param list_colors
#' Named list of colours, as returned by `load_figure_colors()`. Together
#' with `colors` of `list_graphical`, it must hold `black`, `white`,
#' `grey`, `green_light`, `green_dark`, `purple_light` and `blue_dark`.
#' @return
#' A named list with:
#' \itemize{
#'   \item `theme`: a complete ggplot2 theme (`theme_minimal()` with the
#'     text, line and background settings of the v1 manuscript figures);
#'   \item `text_size`, `line_size`, `point_size`, `text_wrap_width` and
#'     `image_units`, as in `list_graphical`;
#'   \item `image_width`: a named numeric vector of figure widths;
#'   \item `colors`: the project colours with the manuscript colours of
#'     `list_graphical` applied (these win when a name is in both);
#'   \item `palettes`: named character vectors `dataset_type` (keys
#'     `vegetation plot`, `fossil pollen archive`, `traits`, `gridpoints`)
#'     and `dataset_source_type` (keys `BIEN`, `sPlotOpen`,
#'     `Neotoma - FOSSILPOL`, `TRY`, `gridpoints`), the colours of v1.
#' }
#' @details
#' The theme keeps the look of the v1 manuscript figures
#' (R/03_Visualisation/01_manuscript/00_Config_mns.R) instead of the
#' project default `theme_classic()`. Aborts when a required setting or
#' colour is missing.
#' @examples
#' \dontrun{
#' list_figure_style <-
#'   build_figure_style(
#'     list_graphical = load_config_value(
#'       value = c("graphical", "manuscript")
#'     ),
#'     list_colors = load_figure_colors(
#'       path_colors = here::here("colors.json")
#'     )
#'   )
#' }
build_figure_style <- function(
  list_graphical,
  list_colors
) {
  assertthat::assert_that(
    base::is.list(list_graphical),
    msg = stringr::str_c(
      "`list_graphical` must be the `graphical: manuscript` section of ",
      "config.yml (a list)."
    )
  )

  assertthat::assert_that(
    base::is.list(list_colors),
    msg = stringr::str_c(
      "`list_colors` must be a named list of colours ",
      "(see load_figure_colors())."
    )
  )

  vec_settings_numeric <-
    c("text_size", "line_size", "point_size", "text_wrap_width")

  vec_settings_missing <-
    c(vec_settings_numeric, "image_units", "image_width", "colors") |>
    base::setdiff(base::names(list_graphical))

  if (
    base::length(vec_settings_missing) > 0L
  ) {
    cli::cli_abort(
      "Missing manuscript settings: {.field {vec_settings_missing}}."
    )
  }

  vec_settings_invalid <-
    vec_settings_numeric |>
    purrr::discard(
      .p = ~ is_positive_number(purrr::chuck(list_graphical, .x))
    )

  if (
    base::length(vec_settings_invalid) > 0L
  ) {
    cli::cli_abort(
      "Manuscript settings must be positive numbers:
      {.field {vec_settings_invalid}}."
    )
  }

  image_units <-
    purrr::chuck(list_graphical, "image_units")

  list_image_width <-
    purrr::chuck(list_graphical, "image_width")

  list_colors_graphical <-
    purrr::chuck(list_graphical, "colors")

  is_image_width_valid <-
    base::is.list(list_image_width) &&
    base::length(list_image_width) > 0L &&
    !base::is.null(base::names(list_image_width)) &&
    base::all(
      purrr::map_lgl(.x = list_image_width, .f = is_positive_number)
    )

  if (
    !base::is.character(image_units) ||
      base::length(image_units) != 1L ||
      !is_image_width_valid ||
      !base::is.list(list_colors_graphical)
  ) {
    cli::cli_abort(
      "Manuscript settings {.field image_units} must be a text value,
      {.field image_width} a named list of positive numbers and
      {.field colors} a list of colours."
    )
  }

  # The manuscript colours win over the project colours of the same name
  list_colors_all <-
    utils::modifyList(x = list_colors, val = list_colors_graphical)

  vec_colors_missing <-
    c(
      "black", "white", "grey", "green_light", "green_dark", "purple_light",
      "blue_dark"
    ) |>
    base::setdiff(base::names(list_colors_all))

  if (
    base::length(vec_colors_missing) > 0L
  ) {
    cli::cli_abort(
      "Missing figure colours: {.field {vec_colors_missing}}."
    )
  }

  text_size <-
    purrr::chuck(list_graphical, "text_size")

  line_size <-
    purrr::chuck(list_graphical, "line_size")

  col_black <-
    purrr::chuck(list_colors_all, "black")

  col_white <-
    purrr::chuck(list_colors_all, "white")

  col_grey <-
    purrr::chuck(list_colors_all, "grey")

  # The theme of the v1 manuscript figures
  #   (R/03_Visualisation/01_manuscript/00_Config_mns.R)
  theme_manuscript <-
    ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(
        size = text_size,
        colour = col_black
      ),
      line = ggplot2::element_line(
        linewidth = line_size,
        colour = col_black
      ),
      axis.text = ggplot2::element_text(
        colour = col_black,
        size = text_size
      ),
      axis.title = ggplot2::element_text(
        colour = col_black,
        size = text_size
      ),
      panel.grid.major = ggplot2::element_line(
        colour = col_grey,
        linewidth = line_size
      ),
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(
        fill = col_white,
        colour = col_white
      ),
      panel.background = ggplot2::element_rect(
        fill = col_white,
        colour = col_grey
      ),
      plot.margin = ggplot2::margin(
        t = 0.1,
        r = 0.1,
        b = 0,
        l = 0,
        unit = "cm"
      )
    )

  col_green_light <-
    purrr::chuck(list_colors_all, "green_light")

  col_green_dark <-
    purrr::chuck(list_colors_all, "green_dark")

  col_purple_light <-
    purrr::chuck(list_colors_all, "purple_light")

  col_blue_dark <-
    purrr::chuck(list_colors_all, "blue_dark")

  # Palettes of v1; the source types are keyed by the labels shown in the
  #   figures, so FOSSILPOL appears as "Neotoma - FOSSILPOL"
  list_palettes <-
    list(
      dataset_type = c(
        "vegetation plot" = col_green_light,
        "fossil pollen archive" = col_purple_light,
        "traits" = col_blue_dark,
        "gridpoints" = col_green_dark
      ),
      dataset_source_type = c(
        "BIEN" = col_green_light,
        "sPlotOpen" = col_green_light,
        "Neotoma - FOSSILPOL" = col_purple_light,
        "TRY" = col_blue_dark,
        "gridpoints" = col_green_dark
      )
    )

  res <-
    list(
      theme = theme_manuscript,
      text_size = text_size,
      line_size = line_size,
      point_size = purrr::chuck(list_graphical, "point_size"),
      text_wrap_width = purrr::chuck(list_graphical, "text_wrap_width"),
      image_units = image_units,
      image_width = base::unlist(list_image_width),
      colors = list_colors_all,
      palettes = list_palettes
    )

  return(res)
}
