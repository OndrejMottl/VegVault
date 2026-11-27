#' @title Load the rows of one kind from a database for the v1.0.0 comparison
#' @description
#' Read, read-only, the rows of one kind (datasets, samples, sample taxa,
#' trait values, links and so on) of a VegVault database by their natural
#' keys, so that a 2.0.0 build and v1.0.0 can be compared row by row
#' without ids. The queries read only tables and columns that both schemas
#' share, so the same call reads a v1.0.0 and a 2.0.0 file.
#' @param path_database
#' Character scalar. Path of an existing database file.
#' @param sel_unit
#' Character scalar. The kind of rows: `"datasets"`, `"samples"`,
#' `"sample_taxa"`, `"sample_uncertainty"`, `"trait_values"`, `"traits"`,
#' `"abiotic_variables"`, `"abiotic_values"`, `"sample_links"`, `"taxa"`,
#' `"taxon_classification"` or `"references"`.
#' @param n_digits
#' Whole number. Decimals to which every double column is rounded, so that
#' the last bits of a coordinate or value do not count as a difference.
#' Default: 6.
#' @return
#' A tibble with the column `scope` and the key columns of the unit:
#' \itemize{
#'   \item `datasets`: `coord_long`, `coord_lat`, `data_source_desc`,
#'     `sampling_method_details`;
#'   \item `samples`: `coord_long`, `coord_lat`, `age`, `sample_size`,
#'     `sample_size_description`;
#'   \item `sample_taxa`: `coord_long`, `coord_lat`, `age`, `taxon_name`,
#'     `value`;
#'   \item `sample_uncertainty`: `coord_long`, `coord_lat`, `sample_age`,
#'     `iteration`, `age`;
#'   \item `trait_values`: `coord_long`, `coord_lat`, `trait_domain_name`,
#'     `trait_name`, `taxon_name`, `trait_value`;
#'   \item `traits`: `trait_name`;
#'   \item `abiotic_variables`: `abiotic_variable_name`,
#'     `abiotic_variable_unit`, `measure_details`;
#'   \item `abiotic_values`: `sample_name`, `abiotic_value`;
#'   \item `sample_links`: `coord_long`, `coord_lat`, `age`,
#'     `gridpoint_name`, `distance_in_km`, `distance_in_years`;
#'   \item `taxa`: `taxon_name`;
#'   \item `taxon_classification`: `taxon_name`, `species_name`,
#'     `genus_name`, `family_name`;
#'   \item `references`: `reference_detail`, `mandatory`.
#' }
#' @details
#' The scope of the rows of datasets and samples is the dataset type and
#' source type, written as in the validation stage (`"<type> / <source
#' type>"`, `"(none)"` for a missing one); a link takes the scope of its
#' sample. The scope of abiotic values is the variable, of traits the
#' trait domain, and of the other units `"all"`. Datasets and samples are
#' identified by their coordinates and ages, not by their names, because
#' 2.0.0 renames the FOSSILPOL, BIEN and trait datasets on purpose;
#' gridpoint samples keep their names, which are stable. Links are read
#' from `AbioticDataReference`, a table in v1.0.0 and a view in 2.0.0 with
#' the same columns. Whole-number columns are returned as doubles, so that
#' a column stored as `INTEGER` in one file and `REAL` in the other gives
#' the same values and the same checksum. Aborts when the file does not
#' exist or `sel_unit` is unknown.
#' @seealso [compute_comparison_summary()],
#'   [compute_comparison_differences()]
#' @examples
#' \dontrun{
#' data_v1_samples <-
#'   load_comparison_rows(
#'     path_database = path_v1_subset,
#'     sel_unit = "samples"
#'   )
#' }
load_comparison_rows <- function(
  path_database,
  sel_unit,
  n_digits = 6L
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::file.exists(path_database),
    msg = "`path_database` must be the path of an existing database file."
  )

  vec_units <-
    c(
      "datasets", "samples", "sample_taxa", "sample_uncertainty",
      "trait_values", "traits", "abiotic_variables", "abiotic_values",
      "sample_links", "taxa", "taxon_classification", "references"
    )

  assertthat::assert_that(
    base::is.character(sel_unit),
    base::length(sel_unit) == 1L,
    base::isTRUE(sel_unit %in% vec_units),
    msg = stringr::str_c(
      "`sel_unit` must be one of: ",
      stringr::str_c(vec_units, collapse = ", "),
      "."
    )
  )

  assertthat::assert_that(
    base::is.numeric(n_digits),
    base::length(n_digits) == 1L,
    !base::is.na(n_digits),
    n_digits >= 0,
    n_digits == base::round(n_digits),
    msg = "`n_digits` must be a whole number of 0 or more."
  )

  # The dataset type and source type, written as in the validation stage
  sql_scope <-
    stringr::str_c(
      "COALESCE(t.dataset_type, '(none)') || ' / ' ||",
      "COALESCE(st.dataset_source_type, '(none)') AS scope",
      sep = " "
    )

  sql_dataset_joins <-
    stringr::str_c(
      "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
      "LEFT JOIN DatasetSourceTypeID AS st",
      "ON st.data_source_type_id = d.data_source_type_id",
      sep = " "
    )

  sql_sample_joins <-
    stringr::str_c(
      "LEFT JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id",
      "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      sql_dataset_joins,
      sep = " "
    )

  data_statements <-
    tibble::tribble(
      ~unit, ~statement,
      "datasets",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat,",
        "src.data_source_desc, sm.sampling_method_details",
        "FROM Datasets AS d", sql_dataset_joins,
        "LEFT JOIN DatasetSourcesID AS src",
        "ON src.data_source_id = d.data_source_id",
        "LEFT JOIN SamplingMethodID AS sm",
        "ON sm.sampling_method_id = d.sampling_method_id",
        sep = " "
      ),
      "samples",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat, s.age,",
        "sz.sample_size, sz.description AS sample_size_description",
        "FROM Samples AS s", sql_sample_joins,
        "LEFT JOIN SampleSizeID AS sz ON sz.sample_size_id = s.sample_size_id",
        sep = " "
      ),
      "sample_taxa",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat, s.age,",
        "tx.taxon_name, stx.value",
        "FROM SampleTaxa AS stx",
        "JOIN Samples AS s ON s.sample_id = stx.sample_id", sql_sample_joins,
        "LEFT JOIN Taxa AS tx ON tx.taxon_id = stx.taxon_id",
        sep = " "
      ),
      "sample_uncertainty",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat,",
        "s.age AS sample_age, su.iteration, su.age",
        "FROM SampleUncertainty AS su",
        "JOIN Samples AS s ON s.sample_id = su.sample_id", sql_sample_joins,
        sep = " "
      ),
      "trait_values",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat,",
        "td.trait_domain_name, tr.trait_name, tx.taxon_name, tv.trait_value",
        "FROM TraitsValue AS tv",
        "LEFT JOIN Datasets AS d ON d.dataset_id = tv.dataset_id",
        sql_dataset_joins,
        "LEFT JOIN Traits AS tr ON tr.trait_id = tv.trait_id",
        "LEFT JOIN TraitsDomain AS td",
        "ON td.trait_domain_id = tr.trait_domain_id",
        "LEFT JOIN Taxa AS tx ON tx.taxon_id = tv.taxon_id",
        sep = " "
      ),
      "traits",
      stringr::str_c(
        "SELECT COALESCE(td.trait_domain_name, '(none)') AS scope,",
        "tr.trait_name FROM Traits AS tr",
        "LEFT JOIN TraitsDomain AS td",
        "ON td.trait_domain_id = tr.trait_domain_id",
        sep = " "
      ),
      "abiotic_variables",
      stringr::str_c(
        "SELECT 'all' AS scope, abiotic_variable_name,",
        "abiotic_variable_unit, measure_details FROM AbioticVariable",
        sep = " "
      ),
      "abiotic_values",
      stringr::str_c(
        "SELECT COALESCE(av.abiotic_variable_name, '(none)') AS scope,",
        "s.sample_name, ad.abiotic_value FROM AbioticData AS ad",
        "LEFT JOIN AbioticVariable AS av",
        "ON av.abiotic_variable_id = ad.abiotic_variable_id",
        "LEFT JOIN Samples AS s ON s.sample_id = ad.sample_id",
        sep = " "
      ),
      "sample_links",
      stringr::str_c(
        "SELECT", sql_scope, ", d.coord_long, d.coord_lat, s.age,",
        "g.sample_name AS gridpoint_name, adr.distance_in_km,",
        "adr.distance_in_years FROM AbioticDataReference AS adr",
        "JOIN Samples AS s ON s.sample_id = adr.sample_id", sql_sample_joins,
        "LEFT JOIN Samples AS g ON g.sample_id = adr.sample_ref_id",
        sep = " "
      ),
      "taxa",
      "SELECT 'all' AS scope, taxon_name FROM Taxa",
      "taxon_classification",
      stringr::str_c(
        "SELECT 'all' AS scope, t.taxon_name, sp.taxon_name AS species_name,",
        "ge.taxon_name AS genus_name, fa.taxon_name AS family_name",
        "FROM TaxonClassification AS tc",
        "LEFT JOIN Taxa AS t ON t.taxon_id = tc.taxon_id",
        "LEFT JOIN Taxa AS sp ON sp.taxon_id = tc.taxon_species",
        "LEFT JOIN Taxa AS ge ON ge.taxon_id = tc.taxon_genus",
        "LEFT JOIN Taxa AS fa ON fa.taxon_id = tc.taxon_family",
        sep = " "
      ),
      "references",
      stringr::str_c(
        "SELECT 'all' AS scope, reference_detail, mandatory",
        "FROM \"References\"",
        sep = " "
      )
    )

  sql_statement <-
    data_statements |>
    dplyr::filter(unit == sel_unit) |>
    dplyr::pull(statement)

  data_rows <-
    run_with_database(
      path_database = path_database,
      fn = ~ DBI::dbGetQuery(conn = .x, statement = sql_statement),
      flag_read_only = TRUE
    )

  res <-
    data_rows |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::where(base::is.integer),
        .fns = base::as.double
      ),
      dplyr::across(
        .cols = dplyr::where(base::is.double),
        .fns = ~ base::round(.x, digits = n_digits)
      )
    )

  return(res)
}
