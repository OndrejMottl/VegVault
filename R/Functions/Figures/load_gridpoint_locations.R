#' @title Load the locations of gridpoints in a region
#' @description
#' Return the coordinates of the gridpoint datasets inside a region, for
#' the gridpoint figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees; see `resolve_figure_region()`).
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with the distinct `coord_long` and `coord_lat` (numeric) of the
#' gridpoint datasets inside the region, edges included, sorted by
#' longitude and latitude.
#' @details
#' The database is opened read-only.
#' @examples
#' \dontrun{
#' data_gridpoint_locations <-
#'   load_gridpoint_locations(
#'     path_database = path_database,
#'     list_region = list_region,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_gridpoint_locations <- function(
  path_database,
  list_region,
  list_build_manifest
) {
  validate_bounding_box(list_bounding_box = list_region)

  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  lon_min <-
    purrr::chuck(list_region, "lon_min")

  lon_max <-
    purrr::chuck(list_region, "lon_max")

  lat_min <-
    purrr::chuck(list_region, "lat_min")

  lat_max <-
    purrr::chuck(list_region, "lat_max")

  data_locations_raw <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res_locations <-
          dplyr::tbl(src = con, from = "Datasets") |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetTypeID"),
            by = "dataset_type_id"
          ) |>
          dplyr::filter(
            dataset_type == "gridpoints",
            coord_long >= !!lon_min,
            coord_long <= !!lon_max,
            coord_lat >= !!lat_min,
            coord_lat <= !!lat_max
          ) |>
          dplyr::distinct(coord_long, coord_lat) |>
          dplyr::collect()

        return(res_locations)
      },
      flag_read_only = TRUE
    )

  res <-
    data_locations_raw |>
    dplyr::mutate(
      coord_long = base::as.numeric(coord_long),
      coord_lat = base::as.numeric(coord_lat)
    ) |>
    dplyr::arrange(coord_long, coord_lat)

  return(res)
}
