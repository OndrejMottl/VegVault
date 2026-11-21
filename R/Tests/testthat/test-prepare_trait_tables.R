#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_trait_tables() validates arguments", {
  data_try <-
    load_valid_fixture(id_artefact = "try_traits")

  list_columns <-
    base::list(
      sample_id = "observation_id",
      data_source_desc = "dataset",
      data_source_reference = "reference_source",
      taxon_name = "acc_species_name",
      sample_references = c("dataset_reference_citation", "record_reference")
    )

  testthat::expect_error(
    prepare_trait_tables(
      data_traits = dplyr::select(data_try, -trait_unit),
      list_columns = list_columns,
      name_prefix = "try",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "trait_unit"
  )

  testthat::expect_error(
    prepare_trait_tables(
      data_traits = data_try,
      list_columns = purrr::list_modify(list_columns, taxon_name = "nope"),
      name_prefix = "try",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "nope"
  )

  testthat::expect_error(
    prepare_trait_tables(
      data_traits = data_try,
      list_columns = list_columns,
      name_prefix = "",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "name_prefix"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_trait_tables() builds the TRY tables", {
  data_try <-
    load_valid_fixture(id_artefact = "try_traits")

  res <-
    prepare_trait_tables(
      data_traits = data_try,
      list_columns = base::list(
        sample_id = "observation_id",
        data_source_desc = "dataset",
        data_source_reference = "reference_source",
        taxon_name = "acc_species_name",
        sample_references = c(
          "dataset_reference_citation",
          "record_reference"
        )
      ),
      name_prefix = "try",
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    purrr::map(.x = build_source_table_template(), .f = base::names)
  )

  n_datasets <-
    data_try |>
    dplyr::distinct(dataset, longitude, latitude, reference_source) |>
    base::nrow()

  data_datasets <-
    purrr::chuck(res, "datasets")

  testthat::expect_equal(base::nrow(data_datasets), n_datasets)
  testthat::expect_equal(
    dplyr::pull(data_datasets, dataset_name),
    stringr::str_c("try_", base::seq_len(n_datasets))
  )

  data_samples <-
    purrr::chuck(res, "samples")

  testthat::expect_equal(
    base::sort(dplyr::pull(data_samples, sample_name)),
    base::sort(
      stringr::str_c(
        "try_",
        base::unique(dplyr::pull(data_try, observation_id))
      )
    )
  )
  testthat::expect_true(base::all(dplyr::pull(data_samples, age) == 0))

  # Both citation columns are sample references, never mandatory
  data_sample_references <-
    purrr::chuck(res, "sample_references")

  testthat::expect_true(
    base::all(
      c("Synthetic citation A", "Synthetic publication A") %in%
        dplyr::pull(data_sample_references, reference_detail)
    )
  )
  testthat::expect_false(
    base::any(dplyr::pull(data_sample_references, mandatory))
  )

  data_trait_values <-
    purrr::chuck(res, "trait_values")

  testthat::expect_equal(base::nrow(data_trait_values), base::nrow(data_try))
  testthat::expect_equal(
    dplyr::pull(data_trait_values, trait_value),
    dplyr::pull(data_try, trait_value)
  )
  testthat::expect_equal(
    dplyr::pull(data_trait_values, conversion_rule_key),
    dplyr::pull(data_try, conversion_rule_key)
  )
  testthat::expect_equal(
    base::sort(dplyr::pull(purrr::chuck(res, "traits"), trait_name)),
    base::sort(base::unique(dplyr::pull(data_try, trait_full_name)))
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "trait_domains")),
    base::length(base::unique(dplyr::pull(data_try, trait_domain)))
  )
})

testthat::test_that("prepare_trait_tables() names datasets by content", {
  data_try <-
    load_valid_fixture(id_artefact = "try_traits")

  list_columns <-
    base::list(
      sample_id = "observation_id",
      data_source_desc = "dataset",
      data_source_reference = "reference_source",
      taxon_name = "acc_species_name",
      sample_references = "dataset_reference_citation"
    )

  list_results <-
    base::list(
      data_try,
      dplyr::slice(data_try, base::rev(base::seq_len(base::nrow(data_try))))
    ) |>
    purrr::map(
      .f = ~ prepare_trait_tables(
        data_traits = .x,
        list_columns = list_columns,
        name_prefix = "try",
        list_source = build_test_source_config(),
        verbose = FALSE
      ) |>
        purrr::chuck("dataset_samples") |>
        dplyr::arrange(sample_name)
    )

  testthat::expect_identical(
    purrr::chuck(list_results, 1L),
    purrr::chuck(list_results, 2L)
  )
})

testthat::test_that("prepare_trait_tables() builds the BIEN trait tables", {
  data_bien_traits <-
    load_valid_fixture(id_artefact = "bien_traits")

  res <-
    prepare_trait_tables(
      data_traits = data_bien_traits,
      list_columns = base::list(
        sample_id = "id",
        data_source_desc = "project_pi",
        data_source_reference = "source_citation",
        taxon_name = "scrubbed_species_binomial",
        sample_references = base::character(0)
      ),
      name_prefix = "bien_traits",
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  testthat::expect_equal(
    base::sort(dplyr::pull(purrr::chuck(res, "samples"), sample_name)),
    base::sort(
      stringr::str_c("bien_traits_", dplyr::pull(data_bien_traits, id))
    )
  )
  testthat::expect_equal(
    base::nrow(purrr::chuck(res, "sample_references")),
    0L
  )

  # A data source without a citation has no data-source reference
  testthat::expect_false(
    base::anyNA(
      dplyr::pull(purrr::chuck(res, "data_source_references"), reference_detail)
    )
  )
  testthat::expect_true(
    stringr::str_detect(
      string = dplyr::pull(purrr::chuck(res, "datasets"), dataset_name)[1L],
      pattern = "^bien_traits_[0-9]+$"
    )
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_trait_tables() refuses inconsistent records", {
  data_try <-
    load_valid_fixture(id_artefact = "try_traits")

  list_columns <-
    base::list(
      sample_id = "observation_id",
      data_source_desc = "dataset",
      data_source_reference = "reference_source",
      taxon_name = "acc_species_name",
      sample_references = base::character(0)
    )

  # The first observation placed in two datasets
  data_two_datasets <-
    dplyr::mutate(
      data_try,
      dataset = dplyr::if_else(
        dplyr::row_number() == 1L,
        "Another study",
        dataset
      )
    )

  testthat::expect_error(
    prepare_trait_tables(
      data_traits = data_two_datasets,
      list_columns = list_columns,
      name_prefix = "try",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "more than one dataset"
  )

  testthat::expect_error(
    prepare_trait_tables(
      data_traits = dplyr::mutate(
        data_try,
        trait_value = dplyr::if_else(
          dplyr::row_number() == 2L,
          NA_real_,
          trait_value
        )
      ),
      list_columns = list_columns,
      name_prefix = "try",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "finite"
  )
})
