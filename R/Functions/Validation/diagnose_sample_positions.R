#' @title Diagnose the positions and links of the samples
#' @description
#' Check, in a built VegVault database and read-only, that every sample
#' that is not a gridpoint and has coordinates and an age has the position
#' of its dataset coordinates and age, and count the samples whose
#' position has no link, per dataset type and source type.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `sample_positions`, with one row per dataset type and source type other
#' than gridpoints, scope `<dataset type> / <source type>`, sorted by
#' scope. A row fails when a sample with coordinates and an age has no
#' position, or a position that differs from its dataset coordinates or
#' its age; the observed value is the number of such samples. Otherwise it
#' is a `flag` when samples have a position without a link, with their
#' number as the observed value, and passes when none does. The message
#' gives the number of samples and each count above zero, including the
#' samples without coordinates or age, which get no position.
#' @details
#' The gridpoint stage gives every sample with coordinates and an age the
#' position of exactly these values (`prepare_link_positions()`), so a
#' missing or different position is a build error. A position without a
#' link can be legitimate, for example a fossil sample older than every
#' gridpoint age plus the link age difference, so it is flagged for review
#' (VegVault issue 96). Samples without coordinates or age are already
#' reported by
#' `diagnose_missing_coordinates()` and `diagnose_sample_ages()`. Opens the
#' database read-only. Aborts when the database is not the one of the
#' manifest.
#' @seealso [diagnose_link_distances()]
#' @examples
#' \dontrun{
#' diagnose_sample_positions(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_sample_positions <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  # Whether each position has a link, through the primary key of
  #   PositionLink; then one row per sample that is not a gridpoint
  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "WITH linked AS (SELECT p.position_id, p.coord_long, p.coord_lat,",
        "p.age, EXISTS (SELECT 1 FROM PositionLink AS pl",
        "WHERE pl.position_id = p.position_id) AS has_link",
        "FROM Positions AS p)",
        "SELECT COALESCE(t.dataset_type, '(none)') || ' / ' ||",
        "COALESCE(st.dataset_source_type, '(none)') AS scope,",
        "COUNT(*) AS n_samples,",
        "COALESCE(SUM(d.coord_long IS NULL OR d.coord_lat IS NULL",
        "OR s.age IS NULL), 0) AS n_unplaced,",
        "COALESCE(SUM(d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL",
        "AND s.age IS NOT NULL AND sp.position_id IS NULL), 0)",
        "AS n_no_position,",
        "COALESCE(SUM(sp.position_id IS NOT NULL AND (l.position_id IS NULL",
        "OR l.coord_long IS NOT d.coord_long",
        "OR l.coord_lat IS NOT d.coord_lat OR l.age IS NOT s.age)), 0)",
        "AS n_wrong_position,",
        "COALESCE(SUM(l.has_link = 0), 0) AS n_no_link",
        "FROM Samples AS s",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id",
        "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
        "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
        "LEFT JOIN DatasetSourceTypeID AS st",
        "ON st.data_source_type_id = d.data_source_type_id",
        "LEFT JOIN SamplePosition AS sp ON sp.sample_id = s.sample_id",
        "LEFT JOIN linked AS l ON l.position_id = sp.position_id",
        "WHERE COALESCE(t.dataset_type, '') <> 'gridpoints'",
        "GROUP BY 1"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::starts_with("n_"),
        .fns = base::as.integer
      ),
      n_failed = n_no_position + n_wrong_position,
      status = dplyr::case_when(
        n_failed > 0L ~ "fail",
        n_no_link > 0L ~ "flag",
        .default = "pass"
      ),
      observed = dplyr::case_when(
        status == "fail" ~ n_failed,
        status == "flag" ~ n_no_link,
        .default = 0L
      ),
      message = stringr::str_c(
        n_samples,
        dplyr::if_else(n_samples == 1L, " sample", " samples"),
        dplyr::if_else(
          n_no_position > 0L,
          stringr::str_c(
            "; with coordinates and age but no position: ", n_no_position
          ),
          ""
        ),
        dplyr::if_else(
          n_wrong_position > 0L,
          stringr::str_c(
            "; position differs from the dataset coordinates or the ",
            "sample age: ", n_wrong_position
          ),
          ""
        ),
        dplyr::if_else(
          n_no_link > 0L,
          stringr::str_c("; position without a link: ", n_no_link),
          ""
        ),
        dplyr::if_else(
          n_unplaced > 0L,
          stringr::str_c(
            "; without coordinates or age: ", n_unplaced,
            " (no position expected)"
          ),
          ""
        ),
        "."
      )
    ) |>
    dplyr::arrange(scope)

  res <-
    build_check_result(
      check_id = "sample_positions",
      scope = dplyr::pull(data_counts, scope),
      status = dplyr::pull(data_counts, status),
      observed = dplyr::pull(data_counts, observed),
      threshold = 0L,
      message = dplyr::pull(data_counts, message)
    )

  return(res)
}
