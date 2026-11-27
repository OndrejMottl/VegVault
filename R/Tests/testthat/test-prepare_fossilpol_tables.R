#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_tables() validates arguments", {
  data_assembly <-
    load_valid_fixture(id_artefact = "fossilpol_assembly")

  data_age_uncertainty <-
    load_valid_fixture(id_artefact = "fossilpol_age_uncertainty")

  testthat::expect_error(
    prepare_fossilpol_tables(
      data_assembly = dplyr::select(data_assembly, -levels),
      data_age_uncertainty = data_age_uncertainty,
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "levels"
  )

  testthat::expect_error(
    prepare_fossilpol_tables(
      data_assembly = data_assembly,
      data_age_uncertainty = dplyr::select(
        data_age_uncertainty,
        -age_uncertainty
      ),
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "age_uncertainty"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_tables() names datasets and levels", {
  res <-
    prepare_fossilpol_tables(
      data_assembly = load_valid_fixture(id_artefact = "fossilpol_assembly"),
      data_age_uncertainty = load_valid_fixture(
        id_artefact = "fossilpol_age_uncertainty"
      ),
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    purrr::map(.x = build_source_table_template(), .f = base::names)
  )

  data_datasets <-
    purrr::chuck(res, "datasets")

  testthat::expect_equal(
    dplyr::pull(data_datasets, dataset_name),
    c("fossilpol_90001", "fossilpol_90002")
  )
  testthat::expect_equal(
    dplyr::pull(data_datasets, sampling_method_details),
    c("Lake", "Peat")
  )

  data_samples <-
    purrr::chuck(res, "samples")

  testthat::expect_true(
    "fossilpol_90001_90001_1" %in% dplyr::pull(data_samples, sample_name)
  )
  testthat::expect_equal(
    dplyr::pull(
      dplyr::filter(data_samples, sample_name == "fossilpol_90001_90001_2"),
      age
    ),
    1210
  )
  testthat::expect_true(
    base::all(base::is.na(dplyr::pull(data_samples, sample_size)))
  )

  # The dataset with a DOI has it as its reference; the other has none
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "dataset_references"), dataset_name),
    "fossilpol_90001"
  )

  data_source_references <-
    purrr::chuck(res, "data_source_references")

  testthat::expect_equal(
    dplyr::pull(data_source_references, reference_detail),
    "Data source citation"
  )
  testthat::expect_true(dplyr::pull(data_source_references, mandatory))
})

testthat::test_that("prepare_fossilpol_tables() keeps counts above zero", {
  data_assembly <-
    load_valid_fixture(id_artefact = "fossilpol_assembly")

  res <-
    prepare_fossilpol_tables(
      data_assembly = data_assembly,
      data_age_uncertainty = load_valid_fixture(
        id_artefact = "fossilpol_age_uncertainty"
      ),
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_sample_taxa <-
    purrr::chuck(res, "sample_taxa")

  testthat::expect_true(base::all(dplyr::pull(data_sample_taxa, value) > 0))
  testthat::expect_false(
    base::any(
      dplyr::pull(data_sample_taxa, sample_name) ==
        "fossilpol_90001_90001_1" &
        dplyr::pull(data_sample_taxa, taxon_name) == "Synthetica beta"
    )
  )

  vec_count_columns <-
    dplyr::pull(data_assembly, counts_harmonised) |>
    purrr::map(.f = base::names) |>
    purrr::list_c() |>
    base::unique() |>
    base::setdiff("sample_id") |>
    base::sort()

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "taxa"), taxon_name),
    vec_count_columns
  )
})

testthat::test_that("prepare_fossilpol_tables() reshapes the iterations", {
  data_age_uncertainty <-
    load_valid_fixture(id_artefact = "fossilpol_age_uncertainty")

  res <-
    prepare_fossilpol_tables(
      data_assembly = load_valid_fixture(id_artefact = "fossilpol_assembly"),
      data_age_uncertainty = data_age_uncertainty,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_uncertainty <-
    purrr::chuck(res, "sample_uncertainty")

  mat_first <-
    purrr::chuck(dplyr::pull(data_age_uncertainty, age_uncertainty), 1L)

  name_first_sample <-
    stringr::str_c(
      "fossilpol_",
      dplyr::pull(data_age_uncertainty, dataset_id)[1L],
      "_",
      base::colnames(mat_first)[1L]
    )

  data_first_sample <-
    dplyr::filter(data_uncertainty, sample_name == name_first_sample)

  testthat::expect_equal(
    dplyr::pull(data_first_sample, iteration),
    base::seq_len(base::nrow(mat_first))
  )
  testthat::expect_equal(
    dplyr::pull(data_first_sample, age),
    base::as.double(mat_first[, 1L])
  )
  testthat::expect_type(dplyr::pull(data_uncertainty, iteration), "integer")
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_tables() drops levels without counts", {
  data_assembly <-
    load_valid_fixture(id_artefact = "fossilpol_assembly")

  data_counts_first <-
    purrr::chuck(dplyr::pull(data_assembly, counts_harmonised), 1L) |>
    dplyr::filter(sample_id != "90001_3")

  data_assembly_cut <-
    dplyr::mutate(
      data_assembly,
      counts_harmonised = c(
        base::list(data_counts_first),
        dplyr::pull(data_assembly, counts_harmonised)[-1L]
      )
    )

  testthat::expect_message(
    res <-
      prepare_fossilpol_tables(
        data_assembly = data_assembly_cut,
        data_age_uncertainty = load_valid_fixture(
          id_artefact = "fossilpol_age_uncertainty"
        ),
        list_source = build_test_source_config(),
        verbose = TRUE
      ),
    regexp = "iteration"
  )

  testthat::expect_false(
    "fossilpol_90001_90001_3" %in%
      dplyr::pull(purrr::chuck(res, "samples"), sample_name)
  )
  testthat::expect_false(
    "fossilpol_90001_90001_3" %in%
      dplyr::pull(purrr::chuck(res, "sample_uncertainty"), sample_name)
  )
})

testthat::test_that("prepare_fossilpol_tables() needs named matrices", {
  data_age_uncertainty <-
    load_valid_fixture(id_artefact = "fossilpol_age_uncertainty")

  data_unnamed <-
    dplyr::mutate(
      data_age_uncertainty,
      age_uncertainty = purrr::map(
        .x = age_uncertainty,
        .f = base::unname
      )
    )

  testthat::expect_error(
    prepare_fossilpol_tables(
      data_assembly = load_valid_fixture(id_artefact = "fossilpol_assembly"),
      data_age_uncertainty = data_unnamed,
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "column names"
  )
})
