#' @title Prepare the header colours of the tables of a schema diagram
#' @description
#' Give the header of each named table of a schema diagram its own fill
#' and text colour, so that the tables of one section of the database
#' share a colour.
#' @param text_svg
#' Character scalar. The SVG text of a schema diagram in the colours of
#' the website, as returned by `prepare_diagram_svg()`.
#' @param data_table_colors
#' A data frame with the columns `table_name`, `fill` and `text`: one row
#' per table, with its header fill and header text colour, both
#' `#RRGGBB`.
#' @param color_header
#' Character scalar. The header fill the diagram has now, `#RRGGBB`.
#' @param color_header_text
#' Character scalar. The header text colour the diagram has now,
#' `#RRGGBB`. Default: white, `"#ffffff"`.
#' @return
#' Character scalar: the SVG text with the headers of the named tables
#' recoloured.
#' @details
#' dbml-renderer draws each table as a group
#' `<g id="<table name>" class="node"><title>table name</title> ... </g>`.
#' Within the group of a named table, the attribute `fill` of the header
#' polygon (`color_header`) and of the header text (`<text ...>` elements
#' with `color_header_text`) are replaced; rows, column text, links and
#' every other table stay as they are. A table of `data_table_colors`
#' that the diagram does not show is skipped, so one table list serves the
#' full diagram and the diagrams of single sections. Table names are
#' matched whole, so `Alpha` does not recolour `AlphaValue`. Aborts when an
#' argument is not of the documented form, a colour is not `#RRGGBB`, a
#' table is named twice, or a table that the diagram shows has no header
#' in `color_header` (colours are matched as written, so `#8A554E` does not
#' find `#8a554e`).
#' @seealso [prepare_diagram_svg()], [render_schema_diagram()]
#' @examples
#' \dontrun{
#' text_svg_sections <-
#'   prepare_diagram_table_colors(
#'     text_svg = text_svg_website,
#'     data_table_colors = tibble::tibble(
#'       table_name = "TraitsValue", fill = "#156064", text = "#ffffff"
#'     ),
#'     color_header = "#8a554e"
#'   )
#' }
prepare_diagram_table_colors <- function(
  text_svg,
  data_table_colors,
  color_header,
  color_header_text = "#ffffff"
) {
  assertthat::assert_that(
    rlang::is_string(text_svg),
    msg = "`text_svg` must be the SVG text as one character value."
  )

  assertthat::assert_that(
    base::is.data.frame(data_table_colors),
    base::all(
      c("table_name", "fill", "text") %in% base::names(data_table_colors)
    ),
    msg = "`data_table_colors` must have the columns table_name, fill, text."
  )

  vec_colors <-
    c(
      dplyr::pull(data_table_colors, fill),
      dplyr::pull(data_table_colors, text),
      color_header,
      color_header_text
    )

  assertthat::assert_that(
    base::is.character(vec_colors),
    base::all(stringr::str_detect(vec_colors, "^#[0-9A-Fa-f]{6}$")),
    msg = "Every colour must be written as #RRGGBB."
  )

  vec_table_names <-
    dplyr::pull(data_table_colors, table_name)

  if (
    base::anyDuplicated(vec_table_names) > 0L
  ) {
    cli::cli_abort("A table of `data_table_colors` is named twice.")
  }

  pattern_header_fill <-
    stringr::fixed(stringr::str_c("fill=\"", color_header, "\""))

  # Only <text> elements carry the header text colour; the rows are polygons
  pattern_header_text <-
    stringr::str_c(
      "(<text[^>]*?)fill=\"", stringr::str_escape(color_header_text), "\""
    )

  # The node group of each named table that the diagram shows, recoloured:
  #   the header polygon and the header text, not the rows
  data_groups <-
    tibble::tibble(
      table_name = vec_table_names,
      fill = dplyr::pull(data_table_colors, fill),
      text = dplyr::pull(data_table_colors, text)
    ) |>
    dplyr::mutate(
      pattern_group = stringr::str_c(
        "<g id=\"[^\"]*\" class=\"node\">\\s*<title>",
        stringr::str_escape(table_name),
        "</title>.*?</g>"
      ),
      text_group = stringr::str_extract(
        text_svg,
        stringr::regex(pattern_group, dotall = TRUE)
      )
    ) |>
    dplyr::filter(!base::is.na(text_group))

  # A shown table without the header fill would keep its colour unnoticed
  vec_tables_no_header <-
    data_groups |>
    dplyr::filter(
      !stringr::str_detect(text_group, pattern_header_fill)
    ) |>
    dplyr::pull(table_name)

  if (
    base::length(vec_tables_no_header) > 0L
  ) {
    cli::cli_abort(
      "The header fill {.val {color_header}} is not in the diagram for
      table{?s} {.val {vec_tables_no_header}}."
    )
  }

  data_groups <-
    data_groups |>
    dplyr::mutate(
      text_group_new = text_group |>
        stringr::str_replace_all(
          pattern = pattern_header_fill,
          replacement = stringr::str_c("fill=\"", fill, "\"")
        ) |>
        stringr::str_replace_all(
          pattern = pattern_header_text,
          replacement = stringr::str_c("\\1fill=\"", text, "\"")
        )
    )

  res <-
    purrr::reduce2(
      .x = dplyr::pull(data_groups, text_group),
      .y = dplyr::pull(data_groups, text_group_new),
      .f = ~ stringr::str_replace(..1, stringr::fixed(..2), ..3),
      .init = text_svg
    )

  return(res)
}
