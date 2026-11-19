#' @title Load fossil pollen records with the traits of their genera
#' @description
#' Extract, with `vaultkeepr`, the fossil pollen samples of a region and age
#' range with their taxa classified to genus, and the trait values of one
#' trait domain for those genera, as in the third v1 `vaultkeepr` example.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees; see `resolve_figure_region()`). It limits both the
#' fossil pollen and the trait datasets.
#' @param age_min,age_max
#' Numeric scalars. The age range of the fossil samples, in calibrated
#' years before present, edges included.
#' @param trait_domain_name
#' Character scalar. The trait domain as stored in the database, for
#' example `"Plant heigh"`.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' The raw tibble of `vaultkeepr::extract_data()`: fossil pollen rows with
#' `dataset_id`, `sample_id`, `age`, `taxon_id` (genus) and `value`, and
#' trait rows with `taxon_id_trait` (genus) and `trait_value`.
#' @details
#' The warning of `vaultkeepr` that its classification is automatic is
#' expected and silenced; other warnings pass. `vaultkeepr` opens the
#' database read-write; this function only reads and always closes the
#' connection.
#' @examples
#' \dontrun{
#' data_trait_example_raw <-
#'   load_trait_example(
#'     path_database = path_database,
#'     list_region = list_region,
#'     age_min = 6000,
#'     age_max = 12000,
#'     trait_domain_name = "Plant heigh",
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_trait_example <- function(
  path_database,
  list_region,
  age_min,
  age_max,
  trait_domain_name,
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
    base::is.character(trait_domain_name),
    base::length(trait_domain_name) == 1L,
    !base::is.na(trait_domain_name),
    msg = "`trait_domain_name` must be a character scalar."
  )

  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  vec_dataset_types <-
    c("fossil_pollen_archive", "traits")

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
          sel_dataset_type = vec_dataset_types
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
          sel_dataset_type = vec_dataset_types,
          verbose = FALSE
        ) |>
        vaultkeepr::get_samples() |>
        vaultkeepr::select_samples_by_age(
          age_lim = c(age_min, age_max),
          verbose = FALSE
        ) |>
        vaultkeepr::get_taxa(classify_to = "genus") |>
        vaultkeepr::get_traits(
          classify_to = "genus",
          verbose = FALSE
        ) |>
        vaultkeepr::select_traits_by_domain_name(
          sel_domain = trait_domain_name
        ) |>
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
