#' @title Load the border of a country
#' @description
#' Download the outline of one country from GADM (through `geodata`), as
#' in the v1 gridpoint figure, and return it as a simple-features object.
#' @param country_code
#' Character scalar. The three-letter ISO code of the country, for example
#' `"CZE"`.
#' @param dir_cache
#' Character scalar. An existing folder where `geodata` keeps the
#' download; a file already there is read instead of downloaded again.
#' @return
#' An `sf` object with the country outline (GADM level 0, low resolution).
#' @details
#' Needs internet access unless the file is in `dir_cache`. Aborts when
#' the country cannot be loaded.
#' @examples
#' \dontrun{
#' data_country_border <-
#'   load_country_border(
#'     country_code = "CZE",
#'     dir_cache = base::tempdir()
#'   )
#' }
load_country_border <- function(
  country_code,
  dir_cache
) {
  assertthat::assert_that(
    base::is.character(country_code),
    base::length(country_code) == 1L,
    !base::is.na(country_code),
    stringr::str_detect(country_code, "^[A-Z]{3}$"),
    msg = "`country_code` must be a three-letter ISO code, such as \"CZE\"."
  )

  assertthat::assert_that(
    base::is.character(dir_cache),
    base::length(dir_cache) == 1L,
    !base::is.na(dir_cache),
    base::dir.exists(dir_cache),
    msg = "`dir_cache` must be an existing folder."
  )

  # geodata returns NULL, with a message, when the download fails
  spat_border <-
    geodata::gadm(
      country = country_code,
      level = 0,
      path = dir_cache,
      resolution = 2
    )

  if (
    base::is.null(spat_border)
  ) {
    cli::cli_abort(
      "The border of {.val {country_code}} could not be loaded from GADM."
    )
  }

  res <-
    sf::st_as_sf(spat_border)

  return(res)
}
