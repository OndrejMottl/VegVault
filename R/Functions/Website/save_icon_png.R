#' @title Save a Font Awesome icon as a PNG file
#' @description
#' Draw one icon of Font Awesome Free in one colour and write it as a PNG
#' file with a transparent background, for figures drawn with
#' `ggimage::geom_image()`.
#' @param icon
#' Character scalar. Name of a Font Awesome icon, as
#' `fontawesome::fa()` takes it, for example `"seedling"` or
#' `"r-project"`.
#' @param fill
#' Character scalar. Colour of the icon, `#RRGGBB`.
#' @param path_output
#' Character scalar. Path of the PNG file to write; an existing file is
#' replaced, and a missing folder is created.
#' @param height_px
#' Positive whole number. Height of the image in pixels; the width
#' follows the shape of the icon. Default: `256L`.
#' @return
#' `path_output`, invisibly.
#' @details
#' The SVG of `fontawesome::fa()`, in the solid style where an icon also
#' has an outlined one, is drawn by `magick`, which needs the rsvg
#' delegate of ImageMagick. Font Awesome Free icons are licensed
#' under CC BY 4.0, so a figure that uses them credits Font Awesome.
#' Aborts, before `path_output` is touched, when an argument is not of
#' the documented form or `icon` is not a Font Awesome icon.
#' @seealso [plot_diagram()]
#' @examples
#' \dontrun{
#' save_icon_png(
#'   icon = "seedling",
#'   fill = "#3ddc47",
#'   path_output = base::file.path(base::tempdir(), "seedling.png")
#' )
#' }
save_icon_png <- function(
  icon,
  fill,
  path_output,
  height_px = 256L
) {
  assertthat::assert_that(
    rlang::is_string(icon),
    base::nzchar(icon),
    msg = "`icon` must name one Font Awesome icon."
  )

  assertthat::assert_that(
    rlang::is_string(fill),
    stringr::str_detect(fill, "^#[0-9A-Fa-f]{6}$"),
    msg = "`fill` must be one colour written as #RRGGBB."
  )

  assertthat::assert_that(
    rlang::is_string(path_output),
    base::nzchar(path_output),
    msg = "`path_output` must be the path of the PNG file to write."
  )

  assertthat::assert_that(
    rlang::is_scalar_integerish(height_px),
    height_px > 0,
    msg = "`height_px` must be a positive whole number."
  )

  text_svg <-
    base::tryCatch(
      expr = fontawesome::fa(
        name = icon,
        fill = fill,
        height = stringr::str_c(height_px, "px"),
        prefer_type = "solid"
      ),
      error = function(cnd) {
        cli::cli_abort(
          "{.val {icon}} is not a Font Awesome icon.",
          parent = cnd
        )
      }
    )

  image_icon <-
    magick::image_read(base::charToRaw(base::as.character(text_svg)))

  base::dir.create(
    base::dirname(path_output),
    showWarnings = FALSE,
    recursive = TRUE
  )

  magick::image_write(image_icon, path = path_output, format = "png")

  res <- path_output

  return(invisible(res))
}
