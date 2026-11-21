#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_splot_tables() validates arguments", {
  data_splot <-
    load_valid_fixture(id_artefact = "splot_plots")

  testthat::expect_error(
    prepare_splot_tables(
      data_splot = dplyr::select(data_splot, -givd_id),
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "givd_id"
  )

  testthat::expect_error(
    prepare_splot_tables(
      data_splot = data_splot,
      list_source = purrr::list_modify(
        build_test_source_config(),
        dataset_type = rlang::zap()
      ),
      verbose = FALSE
    ),
    regexp = "dataset_type"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_splot_tables() fills the source template", {
  res <-
    prepare_splot_tables(
      data_splot = load_valid_fixture(id_artefact = "splot_plots"),
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  list_template <-
    build_source_table_template()

  testthat::expect_named(res, base::names(list_template))
  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    purrr::map(.x = list_template, .f = base::names)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_splot_tables() makes one dataset per plot", {
  data_splot <-
    load_valid_fixture(id_artefact = "splot_plots")

  res <-
    prepare_splot_tables(
      data_splot = data_splot,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_datasets <-
    purrr::chuck(res, "datasets")

  testthat::expect_equal(
    dplyr::pull(data_datasets, dataset_name),
    c("splot_101", "splot_102", "splot_103")
  )
  testthat::expect_equal(
    base::unique(dplyr::pull(data_datasets, dataset_type)),
    "test_type"
  )
  testthat::expect_equal(
    dplyr::pull(data_datasets, data_source_desc),
    dplyr::pull(data_splot, givd_id)
  )
  testthat::expect_equal(
    dplyr::pull(data_datasets, coord_long),
    dplyr::pull(data_splot, longitude)
  )
  testthat::expect_true(
    base::all(base::is.na(dplyr::pull(data_datasets, sampling_method_details)))
  )

  data_samples <-
    purrr::chuck(res, "samples")

  testthat::expect_equal(
    dplyr::pull(data_samples, sample_name),
    dplyr::pull(data_datasets, dataset_name)
  )
  testthat::expect_equal(dplyr::pull(data_samples, age), c(0, 0, 0))
  testthat::expect_equal(
    dplyr::pull(data_samples, sample_size),
    c(100, 25, 400)
  )
  testthat::expect_equal(
    base::unique(dplyr::pull(data_samples, sample_size_description)),
    "square meters"
  )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "dataset_samples"), sample_name),
    dplyr::pull(data_samples, sample_name)
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "source_type_references"), mandatory),
    TRUE
  )
})

testthat::test_that("prepare_splot_tables() keeps the taxa of each plot", {
  data_splot <-
    load_valid_fixture(id_artefact = "splot_plots")

  res <-
    prepare_splot_tables(
      data_splot = data_splot,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_taxa_rows <-
    data_splot |>
    dplyr::select(taxa) |>
    tidyr::unnest(taxa)

  data_sample_taxa <-
    purrr::chuck(res, "sample_taxa")

  testthat::expect_equal(
    base::nrow(data_sample_taxa),
    base::nrow(data_taxa_rows)
  )
  testthat::expect_equal(
    base::sort(dplyr::pull(data_sample_taxa, value)),
    base::sort(dplyr::pull(data_taxa_rows, Original_abundance))
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "taxa"), taxon_name),
    base::sort(base::unique(dplyr::pull(data_taxa_rows, Species)))
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "taxon_references"), taxon_name),
    dplyr::pull(purrr::chuck(res, "taxa"), taxon_name)
  )
  testthat::expect_true(
    base::all(
      dplyr::pull(purrr::chuck(res, "taxon_references"), reference_detail) ==
        "Taxon reference"
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_splot_tables() leaves out empty species", {
  data_splot <-
    load_valid_fixture(id_artefact = "splot_plots")

  data_taxa_first <-
    purrr::chuck(dplyr::pull(data_splot, taxa), 1L) |>
    dplyr::bind_rows(
      tibble::tibble(
        Species = "",
        Original_abundance = 3,
        Abundance_scale = "percentage"
      )
    )

  data_splot_empty <-
    dplyr::mutate(
      data_splot,
      taxa = c(
        base::list(data_taxa_first),
        dplyr::pull(data_splot, taxa)[-1L]
      ),
      plot_observation_id = c(300000, 102, 103)
    )

  testthat::expect_message(
    res <-
      prepare_splot_tables(
        data_splot = data_splot_empty,
        list_source = build_test_source_config(),
        verbose = TRUE
      ),
    regexp = "empty"
  )

  testthat::expect_false(
    "" %in% dplyr::pull(purrr::chuck(res, "taxa"), taxon_name)
  )
  testthat::expect_false(
    "" %in% dplyr::pull(purrr::chuck(res, "sample_taxa"), taxon_name)
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "datasets"), dataset_name)[1L],
    "splot_300000"
  )
})
