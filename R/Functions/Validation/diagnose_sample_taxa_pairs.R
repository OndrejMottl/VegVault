#' @title Diagnose repeated sample and taxon pairs
#' @description
#' Count the (sample, taxon) pairs that occur more than once in
#' `SampleTaxa` of a built VegVault database, read-only, per source of
#' the samples.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `sample_taxa_pairs`: one `pass` row with scope `SampleTaxa` when no pair
#' repeats, otherwise one `flag` row per source type of the datasets
#' (for example `BIEN` or `sPlotOpen`), with the number of repeated pairs
#' as the observed value and the number of their rows in the message.
#' @details
#' `SampleTaxa` has no primary key in 2.0.0, because v1.0.0 repeats
#' 189,639 pairs; the vegetation producers find out why and propose how to
#' merge them. Until then the pairs are flagged for review, not failed. A
#' sample without a dataset is counted under `(no source)`. Opens the
#' database read-only. Aborts only when the database is not the one of the
#' manifest.
#' @examples
#' \dontrun{
#' diagnose_sample_taxa_pairs(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_sample_taxa_pairs <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_pairs <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT COALESCE(st.dataset_source_type, '(no source)') AS source,",
        "COUNT(*) AS n_pairs, SUM(p.n_rows) AS n_rows",
        "FROM (SELECT sample_id, taxon_id, COUNT(*) AS n_rows",
        "FROM SampleTaxa GROUP BY sample_id, taxon_id",
        "HAVING COUNT(*) > 1) AS p",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = p.sample_id",
        "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
        "LEFT JOIN DatasetSourceTypeID AS st",
        "ON st.data_source_type_id = d.data_source_type_id",
        "GROUP BY 1 ORDER BY 1"
      ),
      flag_read_only = TRUE
    )

  res <-
    if (
      base::nrow(data_pairs) == 0L
    ) {
      build_check_result(
        check_id = "sample_taxa_pairs",
        scope = "SampleTaxa",
        status = "pass",
        observed = 0L,
        threshold = 0L,
        message = "No (sample, taxon) pair occurs more than once."
      )
    } else {
      build_check_result(
        check_id = "sample_taxa_pairs",
        scope = dplyr::pull(data_pairs, source),
        status = "flag",
        observed = dplyr::pull(data_pairs, n_pairs),
        threshold = 0L,
        message = stringr::str_c(
          "(sample, taxon) pairs of ", dplyr::pull(data_pairs, source),
          " that occur more than once: ", dplyr::pull(data_pairs, n_pairs),
          ", in ", dplyr::pull(data_pairs, n_rows), " rows. Flagged until ",
          "the vegetation producers resolve them."
        )
      )
    }

  return(res)
}
