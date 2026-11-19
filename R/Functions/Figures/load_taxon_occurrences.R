#' @title Load the occurrences of one genus in a region
#' @description
#' Extract, with `vaultkeepr`, the vegetation plot and fossil pollen
#' samples of a region and age range with their taxa classified to genus,
#' keeping the rows of one genus, as in the first v1 `vaultkeepr` example.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees; see `resolve_figure_region()`).
#' @param age_min,age_max
#' Numeric scalars. The age range of the samples, in calibrated years
#' before present, edges included.
#' @param taxon_name
#' Character scalar. Name of the genus, for example `"Picea"`.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' The raw tibble of `vaultkeepr::extract_data()`: one row per sample and
#' genus record of `taxon_name`, with `dataset_id`, `dataset_type`,
#' `coord_long`, `coord_lat`, `sample_id`, `age`, `taxon_name` and
#' `value`.
#' @details
#' The warning of `vaultkeepr` that its classification is automatic is
#' expected and silenced; other warnings pass. `vaultkeepr` opens the
#' database read-write; this function only reads and always closes the
#' connection.
#' @examples
#' \dontrun{
#' data_taxon_occurrences_raw <-
#'   load_taxon_occurrences(
#'     path_database = path_database,
#'     list_region = list_region,
#'     age_min = 0,
#'     age_max = 12000,
#'     taxon_name = "Picea",
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_taxon_occurrences <- function(
  path_database,
  list_region,
  age_min,
  age_max,
  taxon_name,
  list_build_manifest
) {
  validate_bounding_box(list_bounding_box = list_region)

  assertthat::assert_that(
    base::is.numeric(age_min),
    base::is.numeric(age_max),
    base::length(age_min) == 1L,
    base::length(age_max) == 1L,
    base::is.finite(age_min),
    base::is.finite(age_max),
    age_min <= age_max,
    msg = "`age_min` and `age_max` must be numbers with `age_min` <= `age_max`."
  )

  assertthat::assert_that(
    base::is.character(taxon_name),
    base::length(taxon_name) == 1L,
    !base::is.na(taxon_name),
    msg = "`taxon_name` must be a character scalar."
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

  # vaultkeepr warns on every classification that it is automatic; the
  #   example classifies on purpose, so only that warning is silenced
  res <-
    base::withCallingHandlers(
      expr = vault_opened |>
        vaultkeepr::get_datasets() |>
        vaultkeepr::select_dataset_by_type(
          sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive")
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
          age_lim = c(age_min, age_max),
          verbose = FALSE
        ) |>
        vaultkeepr::get_taxa(classify_to = "genus") |>
        vaultkeepr::select_taxa_by_name(sel_taxa = taxon_name) |>
        vaultkeepr::extract_data(
          return_raw_data = TRUE,
          verbose = FALSE
        ),
      warning = function(cnd) {
        if (
          stringr::str_detect(
            base::conditionMessage(cnd),
            stringr::fixed("classification is being made using an automatic")
          )
        ) {
          base::invokeRestart("muffleWarning")
        }
      }
    )

  return(res)
}
