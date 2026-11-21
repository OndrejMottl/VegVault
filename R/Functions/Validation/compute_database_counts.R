#' @title Compute the counts of a built database for the v1.0.0 comparison
#' @description
#' Count, in a built VegVault database and read-only, what the reference
#' counts of v1.0.0 count: rows per table, datasets, samples, positions,
#' taxon links and trait values per source, abiotic values per variable,
#' and the links per sample.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble with the columns `metric`, `scope` and `n_v2` (a double), with
#' the metrics and scopes of `build_v1_reference_counts()` and one more:
#' `sample_links`, scope `all`, the rows the view `AbioticDataReference`
#' returns (one per sample and linked gridpoint), counted as the sum over
#' positions of their links times their samples. `table_rows` covers the
#' tables of the database, not its views.
#' @details
#' `positions` per source counts the distinct positions of the samples of
#' a source, so a position shared by two sources counts for both;
#' `positions` of `all` is the number of rows of `Positions`. The counts
#' run in one read-only connection; the largest is the scan of
#' `PositionLink` for `sample_links`. Aborts when the database is not the
#' one of the manifest.
#' @seealso [build_v1_reference_counts()], [compute_v1_count_deltas()]
#' @examples
#' \dontrun{
#' compute_database_counts(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
compute_database_counts <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  sql_scope <-
    base::paste(
      "COALESCE(t.dataset_type, '(none)') || ' / ' ||",
      "COALESCE(st.dataset_source_type, '(none)') AS scope"
    )

  sql_types <-
    base::paste(
      "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
      "LEFT JOIN DatasetSourceTypeID AS st",
      "ON st.data_source_type_id = d.data_source_type_id"
    )

  sql_sample_dataset <-
    base::paste(
      "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      sql_types
    )

  data_statements <-
    tibble::tribble(
      ~metric, ~statement,
      "datasets",
      base::paste(
        "SELECT", sql_scope, ", COUNT(*) AS n FROM Datasets AS d",
        sql_types, "GROUP BY 1"
      ),
      "samples",
      base::paste(
        "SELECT", sql_scope, ", COUNT(*) AS n FROM Samples AS s",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id",
        sql_sample_dataset, "GROUP BY 1"
      ),
      "positions",
      base::paste(
        "SELECT", sql_scope, ", COUNT(DISTINCT sp.position_id) AS n",
        "FROM SamplePosition AS sp",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = sp.sample_id",
        sql_sample_dataset, "GROUP BY 1",
        "UNION ALL SELECT 'all' AS scope, COUNT(*) AS n FROM Positions"
      ),
      "sample_taxa_rows",
      base::paste(
        "SELECT", sql_scope, ", COUNT(*) AS n FROM SampleTaxa AS sx",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = sx.sample_id",
        sql_sample_dataset, "GROUP BY 1"
      ),
      "traits_value_rows",
      base::paste(
        "SELECT", sql_scope, ", COUNT(*) AS n FROM TraitsValue AS tv",
        "LEFT JOIN Datasets AS d ON d.dataset_id = tv.dataset_id",
        sql_types, "GROUP BY 1"
      ),
      "abiotic_values",
      base::paste(
        "SELECT COALESCE(v.abiotic_variable_name, '(none)') AS scope,",
        "COUNT(*) AS n FROM AbioticData AS a",
        "LEFT JOIN AbioticVariable AS v",
        "ON v.abiotic_variable_id = a.abiotic_variable_id GROUP BY 1"
      ),
      # The rows of the view AbioticDataReference: per position, its links
      #   times its samples
      "sample_links",
      base::paste(
        "SELECT 'all' AS scope, COALESCE(SUM(l.n_links * p.n_samples), 0)",
        "AS n FROM (SELECT position_id, COUNT(*) AS n_links",
        "FROM PositionLink GROUP BY position_id) AS l",
        "JOIN (SELECT position_id, COUNT(*) AS n_samples",
        "FROM SamplePosition GROUP BY position_id) AS p",
        "ON p.position_id = l.position_id"
      )
    )

  vec_metrics <-
    c(
      "table_rows", dplyr::pull(data_statements, metric)
    )

  res <-
    run_with_database(
      path_database = path_database,
      fn = ~ {
        con <- .x

        vec_tables <-
          DBI::dbGetQuery(
            con,
            base::paste(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
              "AND name NOT LIKE 'sqlite_%' ORDER BY name"
            )
          ) |>
          dplyr::pull(name)

        data_tables <-
          tibble::tibble(
            metric = "table_rows",
            scope = vec_tables,
            n_v2 = purrr::map_dbl(
              .x = vec_tables,
              .f = ~ DBI::dbGetQuery(
                con,
                stringr::str_c("SELECT COUNT(*) AS n FROM \"", .x, "\"")
              ) |>
                dplyr::pull(n) |>
                base::as.numeric()
            )
          )

        data_other <-
          purrr::map2(
            .x = dplyr::pull(data_statements, metric),
            .y = dplyr::pull(data_statements, statement),
            .f = ~ DBI::dbGetQuery(con, .y) |>
              tibble::as_tibble() |>
              dplyr::transmute(
                metric = .x,
                scope,
                n_v2 = base::as.numeric(n)
              )
          ) |>
          dplyr::bind_rows()

        dplyr::bind_rows(data_tables, data_other)
      },
      flag_read_only = TRUE
    ) |>
    dplyr::arrange(base::match(metric, vec_metrics), scope)

  return(res)
}
