#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_bien_plot_tables() needs the stable plot id", {
  testthat::expect_error(
    prepare_bien_plot_tables(
      data_bien = load_valid_fixture(id_artefact = "bien_plots") |>
        dplyr::select(-dplyr::any_of("plot_id")),
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "plot_id"
  )

  testthat::expect_error(
    prepare_bien_plot_tables(
      data_bien = load_valid_fixture(id_artefact = "bien_plots") |>
        dplyr::mutate(plot_id = c("p1", "p2", "p3")),
      list_source = base::list(dataset_type = "test_type"),
      verbose = FALSE
    ),
    regexp = "list_source"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_bien_plot_tables() fills the source template", {
  data_bien <-
    load_valid_fixture(id_artefact = "bien_plots") |>
    dplyr::mutate(plot_id = c("p1", "p2", "p3"))

  res <-
    prepare_bien_plot_tables(
      data_bien = data_bien,
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
    c("bien_p1", "bien_p2", "bien_p3")
  )
  testthat::expect_equal(
    dplyr::pull(data_datasets, data_source_desc),
    dplyr::pull(data_bien, datasource)
  )
  testthat::expect_equal(
    dplyr::pull(data_datasets, sampling_method_details),
    dplyr::pull(data_bien, methodology_description)
  )

  data_samples <-
    purrr::chuck(res, "samples")

  testthat::expect_equal(
    dplyr::pull(data_samples, sample_name),
    c("bien_p1", "bien_p2", "bien_p3")
  )
  testthat::expect_equal(
    dplyr::pull(data_samples, sample_size),
    dplyr::pull(data_bien, plot_area_ha) * 10000
  )
})

testthat::test_that("prepare_bien_plot_tables() links methods to references", {
  data_bien <-
    load_valid_fixture(id_artefact = "bien_plots") |>
    dplyr::mutate(plot_id = c("p1", "p2", "p3"))

  res <-
    prepare_bien_plot_tables(
      data_bien = data_bien,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_method_references <-
    purrr::chuck(res, "sampling_method_references") |>
    dplyr::filter(
      sampling_method_details == "0.1 ha transect, synthetic"
    )

  testthat::expect_equal(
    base::sort(dplyr::pull(data_method_references, reference_detail)),
    c("Method reference", "Synthetic protocol reference")
  )
  testthat::expect_false(
    base::any(
      dplyr::pull(purrr::chuck(res, "sampling_method_references"), mandatory)
    )
  )
  testthat::expect_false(
    base::anyNA(
      dplyr::pull(
        purrr::chuck(res, "sampling_method_references"),
        sampling_method_details
      )
    )
  )
})

testthat::test_that("prepare_bien_plot_tables() keeps the plot taxa", {
  data_bien <-
    load_valid_fixture(id_artefact = "bien_plots") |>
    dplyr::mutate(plot_id = c("p1", "p2", "p3"))

  res <-
    prepare_bien_plot_tables(
      data_bien = data_bien,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_rows <-
    data_bien |>
    dplyr::select(plot_id, plot_data) |>
    tidyr::unnest(plot_data)

  data_sample_taxa <-
    purrr::chuck(res, "sample_taxa")

  testthat::expect_equal(base::nrow(data_sample_taxa), base::nrow(data_rows))
  testthat::expect_equal(
    dplyr::pull(data_sample_taxa, value),
    base::as.double(dplyr::pull(data_rows, individual_count))
  )
  testthat::expect_equal(
    dplyr::pull(data_sample_taxa, sample_name),
    stringr::str_c("bien_", dplyr::pull(data_rows, plot_id))
  )
})
