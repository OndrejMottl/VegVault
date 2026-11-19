#' @title Save a manuscript figure
#' @description
#' Write a plot to a file in the figure folder, with the size given by the
#' figure settings and the figure style.
#' @param plot
#' A ggplot object or a grid grob (for example a gtable) to save.
#' @param dir_figures
#' Character scalar. The figure folder (see `resolve_output_dir()`);
#' created when missing.
#' @param list_figure_file
#' Named list with `file_name` (a file name without folders, ending in
#' `.pdf` or `.png`), `width` (a name of `image_width` of the figure
#' style) and `height` (a positive number in the units of the figure
#' style), for example `figures: files: datasets` of `config.yml`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`; its `image_width`,
#' `image_units` and `colors: white` (the background) are used.
#' @return
#' Character scalar: the path of the written file, so that the function
#' can be the command of a `{targets}` target with `format = "file"`.
#' @details
#' The file is always written, replacing an existing one: in the pipeline,
#' `{targets}` decides when a figure is saved again. Aborts before writing
#' when a setting is missing or invalid.
#' @examples
#' \dontrun{
#' path_figure <-
#'   save_manuscript_figure(
#'     plot = fig_datasets,
#'     dir_figures = dir_figures,
#'     list_figure_file = list(
#'       file_name = "fig_datasets.pdf", width = "full", height = 120
#'     ),
#'     list_figure_style = list_figure_style
#'   )
#' }
save_manuscript_figure <- function(
  plot,
  dir_figures,
  list_figure_file,
  list_figure_style
) {
  assertthat::assert_that(
    ggplot2::is_ggplot(plot) || grid::is.grob(plot),
    msg = "`plot` must be a ggplot object or a grid grob."
  )

  assertthat::assert_that(
    base::is.character(dir_figures),
    base::length(dir_figures) == 1L,
    !base::is.na(dir_figures),
    base::nzchar(dir_figures),
    msg = "`dir_figures` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.list(list_figure_file),
    base::is.list(list_figure_style),
    msg = "`list_figure_file` and `list_figure_style` must be lists."
  )

  file_name <-
    purrr::pluck(list_figure_file, "file_name")

  # A plain file name, so the figure stays in the figure folder
  if (
    !base::is.character(file_name) ||
      base::length(file_name) != 1L ||
      !stringr::str_detect(file_name, "^[A-Za-z0-9_.-]+[.](pdf|png)$") ||
      stringr::str_detect(file_name, "[.][.]")
  ) {
    cli::cli_abort(
      "{.field file_name} must be a plain file name ending in {.val .pdf}
      or {.val .png}."
    )
  }

  name_width <-
    purrr::pluck(list_figure_file, "width")

  vec_image_width <-
    purrr::pluck(list_figure_style, "image_width")

  if (
    !base::is.character(name_width) ||
      base::length(name_width) != 1L ||
      !name_width %in% base::names(vec_image_width)
  ) {
    cli::cli_abort(
      "The figure width {.val {name_width}} is not one of
      {.val {base::names(vec_image_width)}}."
    )
  }

  height <-
    purrr::pluck(list_figure_file, "height")

  if (
    !is_positive_number(height)
  ) {
    cli::cli_abort(
      "The figure {.field height} must be a positive number."
    )
  }

  path_figure <-
    base::file.path(dir_figures, file_name)

  base::dir.create(
    path = dir_figures,
    recursive = TRUE,
    showWarnings = FALSE
  )

  ggplot2::ggsave(
    filename = path_figure,
    plot = plot,
    width = purrr::chuck(vec_image_width, name_width),
    height = height,
    units = purrr::chuck(list_figure_style, "image_units"),
    bg = purrr::chuck(list_figure_style, "colors", "white")
  )

  res <- path_figure

  return(res)
}
