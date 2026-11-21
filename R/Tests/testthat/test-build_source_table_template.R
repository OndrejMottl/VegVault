#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_source_table_template() lists the tables", {
  res <-
    build_source_table_template()

  testthat::expect_type(res, "list")
  testthat::expect_named(
    res,
    c(
      "datasets", "source_type_references", "data_source_references",
      "sampling_method_references", "dataset_references", "samples",
      "sample_references", "dataset_samples", "sample_uncertainty", "taxa",
      "taxon_references", "sample_taxa", "trait_domains", "traits",
      "trait_references", "trait_values"
    )
  )

  testthat::expect_true(
    base::all(purrr::map_lgl(.x = res, .f = tibble::is_tibble))
  )
  testthat::expect_true(
    base::all(purrr::map_int(.x = res, .f = base::nrow) == 0L)
  )
})

testthat::test_that("build_source_table_template() gives columns and types", {
  res <-
    build_source_table_template()

  testthat::expect_named(
    purrr::chuck(res, "datasets"),
    c(
      "dataset_name", "dataset_type", "dataset_source_type",
      "data_source_desc", "coord_long", "coord_lat",
      "sampling_method_details"
    )
  )
  testthat::expect_named(
    purrr::chuck(res, "samples"),
    c("sample_name", "age", "sample_size", "sample_size_description")
  )
  testthat::expect_named(
    purrr::chuck(res, "trait_values"),
    c(
      "dataset_name", "sample_name", "trait_name", "taxon_name",
      "trait_value", "trait_unit", "conversion_rule_key",
      "derivation_rule_key"
    )
  )

  # Every reference table has the text and the mandatory flag
  vec_reference_tables <-
    c(
      "source_type_references", "data_source_references",
      "sampling_method_references", "dataset_references",
      "sample_references", "taxon_references", "trait_references"
    )

  purrr::walk(
    .x = vec_reference_tables,
    .f = ~ {
      data_reference <-
        purrr::chuck(res, .x)

      testthat::expect_true(
        base::all(
          c("reference_detail", "mandatory") %in% base::names(data_reference)
        )
      )
      testthat::expect_type(dplyr::pull(data_reference, mandatory), "logical")
    }
  )

  testthat::expect_type(
    dplyr::pull(purrr::chuck(res, "datasets"), coord_long),
    "double"
  )
  testthat::expect_type(
    dplyr::pull(purrr::chuck(res, "sample_uncertainty"), iteration),
    "integer"
  )
  testthat::expect_type(
    dplyr::pull(purrr::chuck(res, "sample_taxa"), taxon_name),
    "character"
  )
  testthat::expect_identical(build_source_table_template(), res)
})
