#' @title Load the project colours
#' @description
#' Read the colour file of the project (`colors.json`, shared with the
#' website) as a named list of hexadecimal colours.
#' @param path_colors
#' Character scalar. Path of the JSON file: one object whose names are
#' colour roles in lower camel case (for example `brownLight`) and whose
#' values are colours `#RRGGBB` or `#RRGGBBAA`.
#' @return
#' A named list of character scalars, one per colour, with the names in
#' lower snake case (`brownLight` becomes `brown_light`) and the values as
#' in the file.
#' @details
#' Aborts when the file does not exist, is not a JSON object of text
#' values, or holds a value that is not a hexadecimal colour.
#' @examples
#' \dontrun{
#' list_colors <-
#'   load_figure_colors(path_colors = here::here("colors.json"))
#' }
load_figure_colors <- function(path_colors) {
  assertthat::assert_that(
    base::is.character(path_colors),
    base::length(path_colors) == 1L,
    !base::is.na(path_colors),
    base::file.exists(path_colors),
    msg = "`path_colors` must be the path of an existing JSON file."
  )

  list_colors_raw <-
    jsonlite::fromJSON(txt = path_colors, simplifyVector = FALSE)

  is_named_text <-
    base::is.list(list_colors_raw) &&
    base::length(list_colors_raw) > 0L &&
    !base::is.null(base::names(list_colors_raw)) &&
    base::all(
      purrr::map_lgl(
        .x = list_colors_raw,
        .f = ~ base::is.character(.x) && base::length(.x) == 1L
      )
    )

  if (
    !is_named_text
  ) {
    cli::cli_abort(
      "The colour file must be one JSON object of named colour values."
    )
  }

  vec_not_colours <-
    list_colors_raw |>
    purrr::discard(
      .p = ~ stringr::str_detect(
        .x,
        "^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"
      )
    ) |>
    base::names()

  if (
    base::length(vec_not_colours) > 0L
  ) {
    cli::cli_abort(
      "Not a hexadecimal colour in the colour file: {.val {vec_not_colours}}."
    )
  }

  # Lower camel case to lower snake case: "brownLight" -> "brown_light"
  vec_names_snake <-
    base::names(list_colors_raw) |>
    stringr::str_replace_all(
      pattern = "([a-z0-9])([A-Z])",
      replacement = "\\1_\\2"
    ) |>
    stringr::str_to_lower()

  res <-
    list_colors_raw |>
    purrr::set_names(nm = vec_names_snake)

  return(res)
}
