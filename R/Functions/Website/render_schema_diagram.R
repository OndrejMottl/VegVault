#' @title Render one schema diagram in the colours of the website
#' @description
#' Draw a DBML description with dbml-renderer, put the diagram in the
#' colours and the font of the website, and write it as an SVG file.
#' @param text_dbml
#' Character scalar. The DBML text to draw, for example from
#' `build_dbml_text()`.
#' @param path_output
#' Character scalar. Path of the SVG file to write; an existing file is
#' replaced, and a missing folder is created.
#' @param list_theme
#' Named list. The colours and the font of the website, as
#' `prepare_diagram_svg()` takes them.
#' @param renderer
#' Character scalar. The npm package of the renderer with its version,
#' for example `"@softwaretechnik/dbml-renderer@1.0.31"`.
#' @param path_npx
#' Character scalar. Path of the `npx` command of Node.js. Default:
#' `Sys.which("npx")`.
#' @param data_table_colors
#' A data frame with the columns `table_name`, `fill` and `text` (header
#' colours of single tables, as `prepare_diagram_table_colors()` takes
#' them), or `NULL` (the default) for one header colour for all tables.
#' @return
#' `path_output`, invisibly.
#' @details
#' The DBML text is written to a temporary file and drawn with
#' `npx --yes <renderer> --input <file> --output <file>`; npx downloads
#' the renderer on its first use. The colours are replaced by
#' `prepare_diagram_svg()`, then the headers of the tables of
#' `data_table_colors` by `prepare_diagram_table_colors()`. Aborts, before
#' `path_output` is touched, when an argument is not a single text, when
#' the renderer fails or writes no file, and when
#' `prepare_diagram_svg()` or `prepare_diagram_table_colors()` refuses the
#' drawing.
#' @seealso [build_dbml_text()], [prepare_diagram_svg()]
#' @examples
#' \dontrun{
#' render_schema_diagram(
#'   text_dbml = text_dbml,
#'   path_output = here::here("Outputs", "Figures", "schema_diagram.svg"),
#'   list_theme = list_theme,
#'   renderer = "@softwaretechnik/dbml-renderer@1.0.31"
#' )
#' }
render_schema_diagram <- function(
  text_dbml,
  path_output,
  list_theme,
  renderer,
  path_npx = base::Sys.which("npx"),
  data_table_colors = NULL
) {
  assertthat::assert_that(
    base::is.null(data_table_colors) ||
      base::is.data.frame(data_table_colors),
    msg = "`data_table_colors` must be NULL or a data frame."
  )

  assertthat::assert_that(
    rlang::is_string(text_dbml),
    base::nzchar(text_dbml),
    msg = "`text_dbml` must be the DBML text as one non-empty value."
  )

  assertthat::assert_that(
    rlang::is_string(path_output),
    base::nzchar(path_output),
    msg = "`path_output` must be the path of the SVG file to write."
  )

  assertthat::assert_that(
    rlang::is_string(renderer),
    base::nzchar(renderer),
    msg = "`renderer` must name the npm package and version of the renderer."
  )

  assertthat::assert_that(
    rlang::is_string(base::unname(path_npx)),
    base::nzchar(path_npx),
    msg = "`path_npx` must be the path of npx (Node.js)."
  )

  dir_temp <-
    withr::local_tempdir(pattern = "schema_diagram_")

  path_dbml <-
    base::file.path(dir_temp, "diagram.dbml")

  path_svg <-
    base::file.path(dir_temp, "diagram.svg")

  readr::write_file(x = text_dbml, file = path_dbml)

  # A command that cannot be run gives status 127 rather than an error
  status_renderer <-
    base::tryCatch(
      expr = base::system2(
        command = path_npx,
        args = c(
          "--yes", renderer,
          "--input", base::shQuote(path_dbml),
          "--output", base::shQuote(path_svg)
        ),
        stdout = FALSE,
        stderr = FALSE
      ),
      error = function(cnd) 127L
    )

  if (
    status_renderer != 0L || !base::file.exists(path_svg)
  ) {
    cli::cli_abort(
      "dbml-renderer failed (status {status_renderer}) and drew no diagram
      for {.file {base::basename(path_output)}}."
    )
  }

  text_svg_theme <-
    prepare_diagram_svg(
      text_svg = readr::read_file(path_svg),
      list_theme = list_theme
    )

  text_svg_website <-
    if (
      base::is.null(data_table_colors)
    ) {
      text_svg_theme
    } else {
      prepare_diagram_table_colors(
        text_svg = text_svg_theme,
        data_table_colors = data_table_colors,
        color_header = purrr::chuck(list_theme, "header")
      )
    }

  base::dir.create(
    base::dirname(path_output),
    showWarnings = FALSE,
    recursive = TRUE
  )

  readr::write_file(x = text_svg_website, file = path_output)

  res <- path_output

  return(invisible(res))
}
