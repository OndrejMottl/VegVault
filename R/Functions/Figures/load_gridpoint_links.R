#' @title Load vegetation plots and their linked gridpoints in a region
#' @description
#' Extract, with `vaultkeepr`, the modern vegetation plots and gridpoints
#' of a region together with one abiotic variable, as in the v1 gridpoint
#' figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees; see `resolve_figure_region()`).
#' @param abiotic_variable_name
#' Character scalar. Name of the abiotic variable, for example `"bio1"`.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' The raw tibble of `vaultkeepr::extract_data()`: one row per vegetation
#' plot sample of age 0 in the region, and one row per gridpoint sample
#' linked to one of them, with the gridpoint's `sample_id_link` (the
#' linked plot sample) and the variable's `abiotic_value`.
#' @details
#' Uses the `vaultkeepr` defaults for links (nearest gridpoint within
#' 50 km and 5000 years). `vaultkeepr` opens the database read-write; this
#' function only reads and always closes the connection. Aborts (through
#' `vaultkeepr`) when the region has no vegetation plots or no gridpoints.
#' @examples
#' \dontrun{
#' data_gridpoint_links_raw <-
#'   load_gridpoint_links(
#'     path_database = path_database,
#'     list_region = list_region,
#'     abiotic_variable_name = "bio1",
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_gridpoint_links <- function(
  path_database,
  list_region,
  abiotic_variable_name,
  list_build_manifest
) {
  validate_bounding_box(list_bounding_box = list_region)

  assertthat::assert_that(
    base::is.character(abiotic_variable_name),
    base::length(abiotic_variable_name) == 1L,
    !base::is.na(abiotic_variable_name),
    msg = "`abiotic_variable_name` must be a character scalar."
  )

  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  vault_opened <-
    vaultkeepr::open_vault(path = path_database, verbose = FALSE)

  # vaultkeepr leaves its connection open
  base::on.exit(
    DBI::dbDisconnect(conn = purrr::chuck(vault_opened, "db_con")),
    add = TRUE
  )

  res <-
    vault_opened |>
    vaultkeepr::get_datasets() |>
    vaultkeepr::select_dataset_by_type(
      sel_dataset_type = c("vegetation_plot", "gridpoints")
    ) |>
    vaultkeepr::select_dataset_by_geo(
      lat_lim = c(
        purrr::chuck(list_region, "lat_min"),
        purrr::chuck(list_region, "lat_max")
      ),
      long_lim = c(
        purrr::chuck(list_region, "lon_min"),
        purrr::chuck(list_region, "lon_max")
      ),
      verbose = FALSE
    ) |>
    vaultkeepr::get_samples() |>
    vaultkeepr::select_samples_by_age(
      age_lim = c(0, 0),
      verbose = FALSE
    ) |>
    vaultkeepr::get_abiotic_data(verbose = FALSE) |>
    vaultkeepr::select_abiotic_var_by_name(
      sel_var_name = abiotic_variable_name
    ) |>
    vaultkeepr::extract_data(
      return_raw_data = TRUE,
      verbose = FALSE
    )

  return(res)
}
