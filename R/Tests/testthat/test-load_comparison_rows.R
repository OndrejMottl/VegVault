#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_comparison_rows() validates arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_comparison_rows(
      path_database = base::file.path(withr::local_tempdir(), "none.sqlite"),
      sel_unit = "samples"
    ),
    regexp = "path_database"
  )

  testthat::expect_error(
    load_comparison_rows(path_database = path_database, sel_unit = "plots"),
    regexp = "sel_unit"
  )

  testthat::expect_error(
    load_comparison_rows(
      path_database = path_database,
      sel_unit = c("samples", "taxa")
    ),
    regexp = "sel_unit"
  )

  testthat::expect_error(
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "samples",
      n_digits = 1.5
    ),
    regexp = "n_digits"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_comparison_rows() returns the key columns", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_expected <-
    base::list(
      datasets = c(
        "coord_long", "coord_lat", "data_source_desc",
        "sampling_method_details"
      ),
      samples = c(
        "coord_long", "coord_lat", "age", "sample_size",
        "sample_size_description"
      ),
      sample_taxa = c("coord_long", "coord_lat", "age", "taxon_name", "value"),
      sample_uncertainty = c(
        "coord_long", "coord_lat", "sample_age", "iteration", "age"
      ),
      trait_values = c(
        "coord_long", "coord_lat", "trait_domain_name", "trait_name",
        "taxon_name", "trait_value"
      ),
      traits = "trait_name",
      abiotic_variables = c(
        "abiotic_variable_name", "abiotic_variable_unit", "measure_details"
      ),
      abiotic_values = c("sample_name", "abiotic_value"),
      sample_links = c(
        "coord_long", "coord_lat", "age", "gridpoint_name", "distance_in_km",
        "distance_in_years"
      ),
      taxa = "taxon_name",
      taxon_classification = c(
        "taxon_name", "species_name", "genus_name", "family_name"
      ),
      references = c("reference_detail", "mandatory")
    )

  purrr::iwalk(
    .x = list_expected,
    .f = ~ testthat::expect_named(
      load_comparison_rows(path_database = path_database, sel_unit = .y),
      c("scope", .x)
    )
  )

  purrr::iwalk(
    .x = list_expected,
    .f = ~ testthat::expect_s3_class(
      load_comparison_rows(path_database = path_database, sel_unit = .y),
      "tbl_df"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_comparison_rows() reads datasets and samples", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_datasets <-
    load_comparison_rows(path_database = path_database, sel_unit = "datasets")

  testthat::expect_equal(base::nrow(data_datasets), 9L)

  testthat::expect_equal(
    data_datasets |>
      dplyr::filter(scope == "gridpoints / gridpoints") |>
      dplyr::arrange(coord_long) |>
      dplyr::select(coord_long, coord_lat),
    tibble::tibble(
      coord_long = c(14.1, 16.1, 18),
      coord_lat = c(50.1, 49.6, 49)
    )
  )

  data_samples <-
    load_comparison_rows(path_database = path_database, sel_unit = "samples")

  testthat::expect_equal(base::nrow(data_samples), 11L)

  testthat::expect_equal(
    data_samples |>
      dplyr::filter(scope == "fossil_pollen_archive / FOSSILPOL") |>
      dplyr::pull(age) |>
      base::sort(),
    c(1000, 6000, 7000, 11000)
  )

  testthat::expect_equal(
    data_samples |>
      dplyr::filter(scope == "vegetation_plot / sPlotOpen") |>
      dplyr::arrange(coord_long) |>
      dplyr::select(coord_long, sample_size, sample_size_description),
    tibble::tibble(
      coord_long = c(14, 16),
      sample_size = c(100, 400),
      sample_size_description = "square meters"
    )
  )
})

testthat::test_that("load_comparison_rows() reads taxa and traits", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_sample_taxa <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "sample_taxa"
    )

  testthat::expect_equal(base::nrow(data_sample_taxa), 10L)

  testthat::expect_equal(
    data_sample_taxa |>
      dplyr::filter(coord_long == 14) |>
      dplyr::arrange(taxon_name) |>
      dplyr::select(taxon_name, value),
    tibble::tibble(
      taxon_name = c("Picea abies", "Quercus robur"),
      value = c(5, 3)
    )
  )

  data_traits <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "trait_values"
    )

  testthat::expect_equal(
    data_traits |>
      dplyr::arrange(trait_value) |>
      dplyr::select(scope, trait_name, taxon_name, trait_value),
    tibble::tibble(
      scope = "traits / TRY",
      trait_name = c(
        "Plant height vegetative", "Plant height vegetative", "Leaf area"
      ),
      taxon_name = c("Quercus robur", "Picea abies", "Quercus robur"),
      trait_value = c(20, 30, 5000)
    )
  )

  testthat::expect_setequal(
    load_comparison_rows(path_database = path_database, sel_unit = "taxa") |>
      dplyr::pull(taxon_name),
    c(
      "Picea abies", "Picea", "Pinaceae", "Quercus robur", "Quercus",
      "Fagaceae", "Indet."
    )
  )

  data_classification <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "taxon_classification"
    )

  testthat::expect_equal(base::nrow(data_classification), 6L)

  testthat::expect_equal(
    data_classification |>
      dplyr::filter(taxon_name == "Picea abies") |>
      dplyr::select(species_name, genus_name, family_name),
    tibble::tibble(
      species_name = "Picea abies",
      genus_name = "Picea",
      family_name = "Pinaceae"
    )
  )

  testthat::expect_equal(
    base::nrow(
      load_comparison_rows(
        path_database = path_database,
        sel_unit = "sample_uncertainty"
      )
    ),
    10L
  )
})

testthat::test_that("load_comparison_rows() reads abiotic values and links", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_values <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "abiotic_values"
    )

  testthat::expect_equal(
    data_values |>
      dplyr::arrange(scope, sample_name),
    tibble::tibble(
      scope = c("bio1", "bio1", "bio1", "bio12", "bio12"),
      sample_name = c(
        "grid_cz_1", "grid_cz_2", "grid_cz_3", "grid_cz_1", "grid_cz_2"
      ),
      abiotic_value = c(8.5, 9, 7, 600, 550)
    )
  )

  data_links <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "sample_links"
    )

  testthat::expect_equal(
    data_links |>
      dplyr::arrange(coord_long),
    tibble::tibble(
      scope = "vegetation_plot / sPlotOpen",
      coord_long = c(14, 16),
      coord_lat = c(50, 49.5),
      age = 0,
      gridpoint_name = c("grid_cz_1", "grid_cz_2"),
      distance_in_km = c(10L, 12L),
      distance_in_years = 0L
    )
  )
})

testthat::test_that("load_comparison_rows() reads the v1.0.0 links table", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_view <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "sample_links"
    )

  # In v1.0.0 the links are a table with the columns of the 2.0.0 view
  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(conn = .x, statement = "DROP VIEW AbioticDataReference")

      DBI::dbExecute(
        conn = .x,
        statement = "CREATE TABLE AbioticDataReference (sample_id INTEGER,
          sample_ref_id INTEGER, distance_in_km INTEGER,
          distance_in_years INTEGER)"
      )

      DBI::dbExecute(
        conn = .x,
        statement = "INSERT INTO AbioticDataReference VALUES
          (1, 3, 10, 0), (2, 4, 12, 0)"
      )
    }
  )

  data_table <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "sample_links"
    )

  testthat::expect_equal(base::nrow(data_table), 2L)

  testthat::expect_equal(data_table, data_view)
})

testthat::test_that("load_comparison_rows() rounds the doubles", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = ~ DBI::dbExecute(
      conn = .x,
      statement = "UPDATE Datasets SET coord_long = 14.123456789
        WHERE dataset_id = 1"
    )
  )

  vec_default <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "datasets"
    ) |>
    dplyr::pull(coord_long)

  vec_three <-
    load_comparison_rows(
      path_database = path_database,
      sel_unit = "datasets",
      n_digits = 3L
    ) |>
    dplyr::pull(coord_long)

  testthat::expect_true(14.123457 %in% vec_default)

  testthat::expect_true(14.123 %in% vec_three)
})
