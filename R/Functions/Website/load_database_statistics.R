#' @title Load the summary statistics of a VegVault database
#' @description
#' Count, in a built VegVault database and read-only, the figures that the
#' website reports about the database: its tables, views and columns, its
#' size, and its datasets, samples, taxa, dataset sources, trait domains,
#' trait values, abiotic variables and sample ages.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with one row and these columns, all double:
#' \itemize{
#'   \item `n_tables` and `n_views`: the tables and views of the schema,
#'     without SQLite's internal tables (`sqlite_*`);
#'   \item `n_columns`: the columns of the tables, views not counted;
#'   \item `size_bytes`: the size of the database in bytes, its pages
#'     times its page size;
#'   \item `n_datasets` and `n_samples`: the rows of `Datasets` and
#'     `Samples`;
#'   \item `n_samples_gridpoints`: the samples of the datasets of type
#'     `gridpoints`;
#'   \item `n_taxa`: the rows of `Taxa`;
#'   \item `n_taxa_unclassified`: the taxa without a classification, that
#'     is without a row in `TaxonClassification` or with a row whose
#'     species, genus and family are all missing;
#'   \item `n_dataset_sources`: the rows of `DatasetSourcesID`;
#'   \item `n_trait_domains` and `n_trait_values`: the rows of
#'     `TraitsDomain` and `TraitsValue`;
#'   \item `n_abiotic_variables`: the rows of `AbioticVariable`;
#'   \item `age_min` and `age_max`: the youngest and the oldest sample age
#'     in calibrated years before present (1950), samples without an age
#'     left out; `NA` when no sample has an age.
#' }
#' @details
#' Every count runs in one read-only connection (`run_with_database()`),
#' so the database cannot change. The size is read from the database
#' itself (`page_count` times `page_size`); it equals the size of the file
#' when the database is not in write-ahead-log mode, which VegVault
#' databases are not. Aborts when the database is not the one of the
#' manifest. Messages never contain the database path.
#' @seealso [compute_database_counts()], which counts the rows per table
#' and source for the validation of a build.
#' @examples
#' \dontrun{
#' data_database_statistics <-
#'   load_database_statistics(
#'     path_database = path_to_vegvault,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_database_statistics <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  # A taxon without a row in TaxonClassification has NULL in all three
  #   classification columns after the LEFT JOIN, so one condition counts
  #   both kinds of unclassified taxa
  sql_statistics <-
    base::paste(
      "SELECT",
      "(SELECT COUNT(*) FROM sqlite_master WHERE type = 'table'",
      "AND name NOT LIKE 'sqlite_%') AS n_tables,",
      "(SELECT COUNT(*) FROM sqlite_master WHERE type = 'view')",
      "AS n_views,",
      "(SELECT COUNT(*) FROM sqlite_master AS m, pragma_table_info(m.name)",
      "WHERE m.type = 'table' AND m.name NOT LIKE 'sqlite_%')",
      "AS n_columns,",
      "(SELECT page_count FROM pragma_page_count()) *",
      "(SELECT page_size FROM pragma_page_size()) AS size_bytes,",
      "(SELECT COUNT(*) FROM Datasets) AS n_datasets,",
      "(SELECT COUNT(*) FROM Samples) AS n_samples,",
      "(SELECT COUNT(DISTINCT ds.sample_id) FROM DatasetSample AS ds",
      "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      "JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
      "WHERE t.dataset_type = 'gridpoints') AS n_samples_gridpoints,",
      "(SELECT COUNT(*) FROM Taxa) AS n_taxa,",
      "(SELECT COUNT(*) FROM Taxa AS tx",
      "LEFT JOIN TaxonClassification AS c ON c.taxon_id = tx.taxon_id",
      "WHERE c.taxon_species IS NULL AND c.taxon_genus IS NULL",
      "AND c.taxon_family IS NULL) AS n_taxa_unclassified,",
      "(SELECT COUNT(*) FROM DatasetSourcesID) AS n_dataset_sources,",
      "(SELECT COUNT(*) FROM TraitsDomain) AS n_trait_domains,",
      "(SELECT COUNT(*) FROM TraitsValue) AS n_trait_values,",
      "(SELECT COUNT(*) FROM AbioticVariable) AS n_abiotic_variables,",
      "(SELECT MIN(age) FROM Samples) AS age_min,",
      "(SELECT MAX(age) FROM Samples) AS age_max"
    )

  data_statistics_raw <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = sql_statistics,
      flag_read_only = TRUE
    )

  # SQLite returns integers, or a logical NA for an age when no sample
  #   has one; doubles hold the file size and every count alike
  res <-
    data_statistics_raw |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::everything(),
        .fns = base::as.double
      )
    )

  return(res)
}
