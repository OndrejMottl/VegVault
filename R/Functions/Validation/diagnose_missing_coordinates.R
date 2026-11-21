#' @title Diagnose datasets without coordinates
#' @description
#' Count the datasets without coordinates in a built VegVault database,
#' read-only, per dataset type and source type, so that a reviewer sees
#' how many datasets cannot be linked to gridpoints.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `missing_coordinates`, with one row per dataset type and source type,
#' scope `<dataset type> / <source type>`, sorted by scope. A row passes
#' when every dataset has both coordinates; otherwise it is a `flag` with
#' the number of datasets without them as the observed value and the
#' number of datasets as the threshold.
#' @details
#' A dataset without a longitude or a latitude has no position, so its
#' samples get no climate link. Some sources publish records without a
#' location, and the trait producers set coordinates outside -180 to 180
#' and -90 to 90 to missing, so these datasets are flagged for review, not
#' failed. A missing type or source is reported as `(none)`. Opens the
#' database read-only. Aborts only when the database is not the one of the
#' manifest.
#' @examples
#' \dontrun{
#' diagnose_missing_coordinates(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_missing_coordinates <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT COALESCE(t.dataset_type, '(none)') || ' / ' ||",
        "COALESCE(st.dataset_source_type, '(none)') AS scope,",
        "COUNT(*) AS n_datasets,",
        "SUM(d.coord_long IS NULL OR d.coord_lat IS NULL) AS n_missing",
        "FROM Datasets AS d",
        "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
        "LEFT JOIN DatasetSourceTypeID AS st",
        "ON st.data_source_type_id = d.data_source_type_id",
        "GROUP BY 1"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::arrange(scope)

  res <-
    build_check_result(
      check_id = "missing_coordinates",
      scope = dplyr::pull(data_counts, scope),
      status = dplyr::if_else(
        dplyr::pull(data_counts, n_missing) == 0L,
        "pass",
        "flag"
      ),
      observed = dplyr::pull(data_counts, n_missing),
      threshold = dplyr::pull(data_counts, n_datasets),
      message = stringr::str_c(
        "Datasets of ", dplyr::pull(data_counts, scope),
        " without coordinates: ", dplyr::pull(data_counts, n_missing),
        " of ", dplyr::pull(data_counts, n_datasets),
        "; their samples get no climate link."
      )
    )

  return(res)
}
