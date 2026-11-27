#' @title Prepare a schema diagram in the colours of the website
#' @description
#' Replace the fixed colours and the font of a schema diagram drawn by
#' dbml-renderer with the colours and the font of the website.
#' @param text_svg
#' Character scalar. The SVG text that dbml-renderer wrote.
#' @param list_theme
#' Named list of character scalars: `header` (fill of the table
#' headers), `body` (fill of the table rows), `text` (fill of the column
#' text and of the link ends), `line` (stroke of the cell borders, the
#' table outlines and the links), all colours `#RRGGBB`, and `font` (the
#' font family, as written in CSS, for example
#' `"Inter, Helvetica, sans-serif"`).
#' @return
#' Character scalar: the SVG text with the colours and the font replaced.
#' @details
#' dbml-renderer 1.0.31 draws every diagram with the same attributes:
#' `fill="#1d71b8"` for the table headers, `fill="#e7e2dd"` for the rows,
#' `fill="#29235c"` for the text and the link ends, `stroke="#29235c"` for
#' the borders, outlines and links, and
#' `font-family="Helvetica,sans-Serif"`. Each of these attributes is
#' replaced exactly; the white header text and every other attribute stay
#' as they are. Aborts when one of these attributes does not occur in
#' `text_svg`, which means that the renderer changed its drawing, and when
#' `text_svg` is not a single text, `list_theme` lacks an element or holds
#' a colour that is not `#RRGGBB`.
#' @seealso [build_dbml_text()]
#' @examples
#' \dontrun{
#' text_svg_website <-
#'   prepare_diagram_svg(
#'     text_svg = text_svg,
#'     list_theme = list(
#'       header = "#8a554e",
#'       body = "#ffffff",
#'       text = "#242531",
#'       line = "#242531",
#'       font = "Inter, Helvetica, sans-serif"
#'     )
#'   )
#' }
prepare_diagram_svg <- function(
  text_svg,
  list_theme
) {
  assertthat::assert_that(
    base::is.character(text_svg),
    base::length(text_svg) == 1L,
    !base::is.na(text_svg),
    msg = "`text_svg` must be the SVG text as one character value."
  )

  vec_theme_names <-
    c("header", "body", "text", "line", "font")

  assertthat::assert_that(
    base::is.list(list_theme),
    base::all(vec_theme_names %in% base::names(list_theme)),
    base::all(
      purrr::map_lgl(
        .x = vec_theme_names,
        .f = ~ rlang::is_string(purrr::pluck(list_theme, .x))
      )
    ),
    msg = stringr::str_c(
      "`list_theme` must have the elements header, body, text, line and ",
      "font, each one text."
    )
  )

  vec_theme_colors <-
    purrr::map_chr(
      .x = c("header", "body", "text", "line"),
      .f = ~ base::as.character(purrr::chuck(list_theme, .x))
    )

  assertthat::assert_that(
    base::all(
      stringr::str_detect(vec_theme_colors, "^#[0-9A-Fa-f]{6}$")
    ),
    msg = "The colours of `list_theme` must be written as #RRGGBB."
  )

  text_font <-
    purrr::chuck(list_theme, "font")

  assertthat::assert_that(
    base::is.character(text_font),
    base::length(text_font) == 1L,
    !base::is.na(text_font),
    !stringr::str_detect(text_font, "\""),
    msg = "The font of `list_theme` must be one text without double quotes."
  )

  # The attributes of dbml-renderer 1.0.31 and their website values
  vec_replacements <-
    c(
      "fill=\"#1d71b8\"" = stringr::str_c(
        "fill=\"", vec_theme_colors[1], "\""
      ),
      "fill=\"#e7e2dd\"" = stringr::str_c(
        "fill=\"", vec_theme_colors[2], "\""
      ),
      "fill=\"#29235c\"" = stringr::str_c(
        "fill=\"", vec_theme_colors[3], "\""
      ),
      "stroke=\"#29235c\"" = stringr::str_c(
        "stroke=\"", vec_theme_colors[4], "\""
      ),
      "font-family=\"Helvetica,sans-Serif\"" = stringr::str_c(
        "font-family=\"", text_font, "\""
      )
    )

  vec_missing <-
    base::names(vec_replacements)[
      !stringr::str_detect(
        text_svg,
        stringr::fixed(base::names(vec_replacements))
      )
    ]

  if (
    base::length(vec_missing) > 0L
  ) {
    cli::cli_abort(
      c(
        "The SVG lacks {.val {vec_missing}}.",
        "i" = "dbml-renderer 1.0.31 writes these; a newer renderer may
        draw differently."
      )
    )
  }

  res <-
    purrr::reduce2(
      .x = base::names(vec_replacements),
      .y = base::unname(vec_replacements),
      .f = ~ stringr::str_replace_all(
        string = ..1,
        pattern = stringr::fixed(..2),
        replacement = ..3
      ),
      .init = text_svg
    )

  return(res)
}
