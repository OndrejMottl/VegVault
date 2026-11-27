#' @title Diagnose datasets without a named data source
#' @description
#' Count the datasets without a named data source in a built VegVault
#' database, read-only, per dataset type and source type, and compare each
#' count with the number accepted in the configuration, so that a build
#' cannot lose the link between datasets and the providers of their
#' records without notice.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param list_accepted
#' List of accepted counts, from `validation: missing_data_sources:
#' accepted` of `config.yml`. Each entry is a named list with `scope`
#' (`<dataset type> / <source type>`), `n_datasets` (the accepted number
#' of datasets without a named data source, a whole number of at least 1)
#' and `reason` (why they have none). Every scope is listed once. Default:
#' none.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `missing_data_sources`, with one row per dataset type and source type,
#' scope `<dataset type> / <source type>`, sorted by scope. The observed
#' value is the number of datasets without a named data source and the
#' threshold the accepted number (0 for a scope not listed). A row passes
#' when the two are equal; otherwise it is a `flag`. The message gives the
#' number of datasets and, for a listed scope, the reason.
#' @details
#' A dataset has no named data source when its `data_source_id` is missing
#' or points to a data source whose `data_source_desc` is missing or blank:
#' its records cannot be traced to the provider who measured them. Some
#' records name no provider (BIEN trait records without a project PI), so
#' a count that differs from the accepted one is flagged for review, not
#' failed: more such datasets may mean lost links, fewer a changed source.
#' A missing type or source type is reported as `(none)`. An accepted
#' scope that is not in the database gives no row. Opens the database
#' read-only. Aborts when the database is not the one of the manifest or
#' when `list_accepted` is malformed.
#' @seealso [diagnose_missing_coordinates()], [build_check_result()]
#' @examples
#' \dontrun{
#' diagnose_missing_data_sources(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   list_accepted = load_config_value(
#'     value = c("validation", "missing_data_sources", "accepted")
#'   )
#' )
#' }
diagnose_missing_data_sources <- function(
  path_database,
  list_build_manifest,
  list_accepted = base::list()
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  msg_accepted <-
    stringr::str_c(
      "`list_accepted` must be a list of entries, each with a non-empty ",
      "`scope` and `reason` and a whole number `n_datasets` of at least 1, ",
      "every scope listed once."
    )

  assertthat::assert_that(
    base::is.list(list_accepted),
    msg = msg_accepted
  )

  vec_entry_valid <-
    purrr::map_lgl(
      .x = list_accepted,
      .f = ~ base::is.list(.x) &&
        rlang::is_string(purrr::pluck(.x, "scope")) &&
        rlang::is_string(purrr::pluck(.x, "reason")) &&
        base::isTRUE(assertthat::is.count(purrr::pluck(.x, "n_datasets")))
    )

  assertthat::assert_that(
    base::all(vec_entry_valid),
    msg = msg_accepted
  )

  data_accepted <-
    tibble::tibble(
      scope = purrr::map_chr(.x = list_accepted, .f = "scope"),
      n_accepted = purrr::map_int(.x = list_accepted, .f = "n_datasets"),
      reason = purrr::map_chr(.x = list_accepted, .f = "reason")
    )

  assertthat::assert_that(
    base::all(base::nzchar(base::trimws(dplyr::pull(data_accepted, scope)))),
    base::all(base::nzchar(base::trimws(dplyr::pull(data_accepted, reason)))),
    !base::any(base::duplicated(dplyr::pull(data_accepted, scope))),
    msg = msg_accepted
  )

  # A missing id, an id without its row (also failed by the foreign key
  #   check) and a source without a description all name no provider
  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT COALESCE(t.dataset_type, '(none)') || ' / ' ||",
        "COALESCE(st.dataset_source_type, '(none)') AS scope,",
        "COUNT(*) AS n_datasets,",
        "SUM(s.data_source_id IS NULL OR s.data_source_desc IS NULL",
        "OR TRIM(s.data_source_desc) = '') AS n_missing",
        "FROM Datasets AS d",
        "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
        "LEFT JOIN DatasetSourceTypeID AS st",
        "ON st.data_source_type_id = d.data_source_type_id",
        "LEFT JOIN DatasetSourcesID AS s",
        "ON s.data_source_id = d.data_source_id",
        "GROUP BY 1"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::arrange(scope)

  data_compared <-
    data_counts |>
    dplyr::left_join(
      data_accepted,
      by = dplyr::join_by(scope),
      relationship = "one-to-one"
    ) |>
    dplyr::mutate(
      n_accepted = dplyr::coalesce(n_accepted, 0L),
      text_counts = stringr::str_c(
        "Datasets of ", scope, " without a named data source: ",
        n_missing, " of ", n_datasets
      ),
      message = dplyr::case_when(
        n_missing == 0L & n_accepted == 0L ~ stringr::str_c(
          "Every dataset of ", scope, " names its data source (",
          n_datasets, " datasets)."
        ),
        n_missing == n_accepted ~ stringr::str_c(
          text_counts, ", as accepted: ", reason
        ),
        base::is.na(reason) ~ stringr::str_c(
          text_counts, "; none are accepted, so their records cannot be ",
          "traced to a data provider."
        ),
        .default = stringr::str_c(
          text_counts, ", where ", n_accepted, " are accepted: ", reason
        )
      )
    )

  res <-
    build_check_result(
      check_id = "missing_data_sources",
      scope = dplyr::pull(data_compared, scope),
      status = dplyr::if_else(
        dplyr::pull(data_compared, n_missing) ==
          dplyr::pull(data_compared, n_accepted),
        "pass",
        "flag"
      ),
      observed = dplyr::pull(data_compared, n_missing),
      threshold = dplyr::pull(data_compared, n_accepted),
      message = dplyr::pull(data_compared, message)
    )

  return(res)
}
