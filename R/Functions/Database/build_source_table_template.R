#' @title Build the template of the tables of one source
#' @description
#' Return the empty tables that every source of the database (sPlotOpen,
#' BIEN plots, FOSSILPOL, TRY, BIEN traits) is prepared into before ids are
#' assigned. The tables hold natural keys (names and texts) only, so the
#' sources can be combined and given ids in one step.
#' @return
#' A named list of zero-row tibbles, in this order:
#' \itemize{
#'   \item `datasets`: `dataset_name`, `dataset_type`,
#'     `dataset_source_type`, `data_source_desc`, `coord_long`, `coord_lat`,
#'     `sampling_method_details`;
#'   \item `source_type_references`: `dataset_source_type`,
#'     `reference_detail`, `mandatory`;
#'   \item `data_source_references`: `data_source_desc`,
#'     `reference_detail`, `mandatory`;
#'   \item `sampling_method_references`: `sampling_method_details`,
#'     `reference_detail`, `mandatory`;
#'   \item `dataset_references`: `dataset_name`, `reference_detail`,
#'     `mandatory`;
#'   \item `samples`: `sample_name`, `age`, `sample_size`,
#'     `sample_size_description`;
#'   \item `sample_references`: `sample_name`, `reference_detail`,
#'     `mandatory`;
#'   \item `dataset_samples`: `dataset_name`, `sample_name`;
#'   \item `sample_uncertainty`: `sample_name`, `iteration`, `age`;
#'   \item `taxa`: `taxon_name`;
#'   \item `taxon_references`: `taxon_name`, `reference_detail`,
#'     `mandatory`;
#'   \item `sample_taxa`: `sample_name`, `taxon_name`, `value`;
#'   \item `trait_domains`: `trait_domain_name`, `trait_unit`;
#'   \item `traits`: `trait_name`, `trait_domain_name`;
#'   \item `trait_references`: `trait_name`, `reference_detail`,
#'     `mandatory`;
#'   \item `trait_values`: `dataset_name`, `sample_name`, `trait_name`,
#'     `taxon_name`, `trait_value`, `trait_unit`, `conversion_rule_key`,
#'     `derivation_rule_key`.
#' }
#' @details
#' Names, texts and keys are character columns; `coord_long`, `coord_lat`,
#' `age`, `sample_size`, `value` and `trait_value` are doubles;
#' `iteration` is an integer; `mandatory` is logical. The template is the
#' contract between the functions that prepare one source and
#' `build_database_tables()`, which checks every source against it.
#' @seealso [build_database_tables()]
#' @examples
#' \dontrun{
#' list_template <- build_source_table_template()
#' }
build_source_table_template <- function() {
  vec_chr <- base::character(0)
  vec_dbl <- base::double(0)
  vec_lgl <- base::logical(0)

  res <-
    base::list(
      datasets = tibble::tibble(
        dataset_name = vec_chr,
        dataset_type = vec_chr,
        dataset_source_type = vec_chr,
        data_source_desc = vec_chr,
        coord_long = vec_dbl,
        coord_lat = vec_dbl,
        sampling_method_details = vec_chr
      ),
      source_type_references = tibble::tibble(
        dataset_source_type = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      data_source_references = tibble::tibble(
        data_source_desc = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      sampling_method_references = tibble::tibble(
        sampling_method_details = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      dataset_references = tibble::tibble(
        dataset_name = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      samples = tibble::tibble(
        sample_name = vec_chr,
        age = vec_dbl,
        sample_size = vec_dbl,
        sample_size_description = vec_chr
      ),
      sample_references = tibble::tibble(
        sample_name = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      dataset_samples = tibble::tibble(
        dataset_name = vec_chr,
        sample_name = vec_chr
      ),
      sample_uncertainty = tibble::tibble(
        sample_name = vec_chr,
        iteration = base::integer(0),
        age = vec_dbl
      ),
      taxa = tibble::tibble(
        taxon_name = vec_chr
      ),
      taxon_references = tibble::tibble(
        taxon_name = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      sample_taxa = tibble::tibble(
        sample_name = vec_chr,
        taxon_name = vec_chr,
        value = vec_dbl
      ),
      trait_domains = tibble::tibble(
        trait_domain_name = vec_chr,
        trait_unit = vec_chr
      ),
      traits = tibble::tibble(
        trait_name = vec_chr,
        trait_domain_name = vec_chr
      ),
      trait_references = tibble::tibble(
        trait_name = vec_chr,
        reference_detail = vec_chr,
        mandatory = vec_lgl
      ),
      trait_values = tibble::tibble(
        dataset_name = vec_chr,
        sample_name = vec_chr,
        trait_name = vec_chr,
        taxon_name = vec_chr,
        trait_value = vec_dbl,
        trait_unit = vec_chr,
        conversion_rule_key = vec_chr,
        derivation_rule_key = vec_chr
      )
    )

  return(res)
}
