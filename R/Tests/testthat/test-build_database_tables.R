#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_tables() validates arguments", {
  list_inputs <-
    build_test_database_sources()

  list_source_tables <-
    purrr::chuck(list_inputs, "list_source_tables")

  testthat::expect_error(
    build_database_tables(
      list_source_tables = base::unname(list_source_tables),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "list_source_tables"
  )

  list_extra_column <-
    purrr::assign_in(
      list_source_tables,
      where = c("splot", "taxa"),
      value = dplyr::mutate(
        purrr::chuck(list_source_tables, "splot", "taxa"),
        extra_column = 1
      )
    )

  testthat::expect_error(
    build_database_tables(
      list_source_tables = list_extra_column,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "extra_column"
  )

  list_unknown_table <-
    purrr::assign_in(
      list_source_tables,
      where = c("splot", "unknown_table"),
      value = tibble::tibble(x = 1)
    )

  testthat::expect_error(
    build_database_tables(
      list_source_tables = list_unknown_table,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "unknown_table"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_tables() returns the schema tables", {
  list_inputs <-
    build_test_database_sources()

  res <-
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  vec_tables <-
    c(
      "DatasetTypeID", "DatasetSourceTypeID", "DatasetSourcesID",
      "SamplingMethodID", "References", "DatasetSourceTypeReference",
      "DatasetSourcesReference", "SamplingMethodReference", "Datasets",
      "DatasetReferences", "SampleSizeID", "Samples", "SampleReference",
      "DatasetSample", "SampleUncertainty", "Taxa", "TaxonReference",
      "SampleTaxa", "TraitsDomain", "Traits", "TraitsReference",
      "TraitUnitConversion", "TraitDerivation", "TraitsValue",
      "AbioticVariable", "AbioticVariableReference", "AbioticData"
    )

  testthat::expect_named(res, vec_tables)

  # The columns of each table are those of the schema, in schema order
  list_schema_columns <-
    run_with_database(
      path_database = base::file.path(withr::local_tempdir(), "schema.sqlite"),
      fn = ~ {
        con_schema <- .x

        build_database_schema(con = con_schema, sel_objects = "tables")

        vec_tables |>
          rlang::set_names() |>
          purrr::map(
            .f = ~ DBI::dbGetQuery(
              conn = con_schema,
              statement = stringr::str_c(
                "PRAGMA table_info(\"",
                .x,
                "\")"
              )
            ) |>
              dplyr::pull(name)
          )
      }
    )

  testthat::expect_identical(
    purrr::map(.x = res, .f = base::names),
    list_schema_columns
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_database_tables() gives a database that loads", {
  list_inputs <-
    build_test_database_sources()

  list_tables <-
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  save_vegvault_database(
    path_database = path_database,
    list_tables = list_tables,
    list_pragmas_load = base::list(
      journal_mode = "MEMORY",
      foreign_keys = "OFF"
    ),
    list_pragmas_final = base::list(foreign_keys = "ON"),
    n_chunk_size = 1000L,
    verbose = FALSE
  )

  list_checks <-
    run_with_database(
      path_database = path_database,
      fn = ~ base::list(
        foreign_keys = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA foreign_key_check"
        ),
        integrity = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA integrity_check"
        ),
        n_trait_values = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT COUNT(*) AS n FROM TraitsValue"
        )
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    base::nrow(purrr::chuck(list_checks, "foreign_keys")),
    0L
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(list_checks, "integrity"), 1L),
    "ok"
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(list_checks, "n_trait_values"), n),
    base::nrow(purrr::chuck(list_tables, "TraitsValue"))
  )
})

testthat::test_that("build_database_tables() numbers lookups by source", {
  list_inputs <-
    build_test_database_sources()

  res <-
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  # The dataset types and source types get the ids they have in v1.0.0
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "DatasetTypeID"), dataset_type),
    c("vegetation_plot", "fossil_pollen_archive", "traits")
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "DatasetSourceTypeID"), dataset_source_type),
    c("sPlotOpen", "BIEN", "FOSSILPOL", "TRY")
  )

  # A text used by several sources is one row
  vec_taxa <-
    dplyr::pull(purrr::chuck(res, "Taxa"), taxon_name)

  testthat::expect_equal(base::sum(vec_taxa == "Synthetica alpha"), 1L)
  testthat::expect_equal(
    base::sum(
      dplyr::pull(purrr::chuck(res, "References"), reference_detail) ==
        "Citation of BIEN"
    ),
    1L
  )

  # Datasets follow the source, then the name
  vec_dataset_names <-
    dplyr::pull(purrr::chuck(res, "Datasets"), dataset_name)

  vec_source_index <-
    dplyr::case_when(
      stringr::str_starts(vec_dataset_names, "splot_") ~ 1L,
      stringr::str_starts(vec_dataset_names, "bien_traits_") ~ 5L,
      stringr::str_starts(vec_dataset_names, "bien_") ~ 2L,
      stringr::str_starts(vec_dataset_names, "fossilpol_") ~ 3L,
      stringr::str_starts(vec_dataset_names, "try_") ~ 4L
    )

  testthat::expect_false(base::is.unsorted(vec_source_index))
  testthat::expect_false(base::anyNA(vec_source_index))
})

testthat::test_that("build_database_tables() does not depend on row order", {
  list_inputs <-
    build_test_database_sources()

  list_source_tables <-
    purrr::chuck(list_inputs, "list_source_tables")

  list_reversed <-
    list_source_tables |>
    purrr::map(
      .f = ~ purrr::map(
        .x = .x,
        .f = ~ dplyr::slice(.x, base::rev(base::seq_len(base::nrow(.x))))
      )
    )

  list_results <-
    base::list(list_source_tables, list_reversed) |>
    purrr::map(
      .f = ~ build_database_tables(
        list_source_tables = .x,
        data_unit_conversions = purrr::chuck(
          list_inputs,
          "data_unit_conversions"
        ),
        data_trait_derivations = purrr::chuck(
          list_inputs,
          "data_trait_derivations"
        )
      ) |>
        purrr::map(
          .f = ~ dplyr::arrange(.x, dplyr::pick(dplyr::everything()))
        )
    )

  testthat::expect_identical(
    purrr::chuck(list_results, 1L),
    purrr::chuck(list_results, 2L)
  )
})

testthat::test_that("build_database_tables() makes a reference mandatory", {
  list_inputs <-
    build_test_database_sources()

  # The taxon reference text is also the mandatory citation of a source
  list_shared <-
    purrr::assign_in(
      purrr::chuck(list_inputs, "list_source_tables"),
      where = c("splot", "source_type_references"),
      value = tibble::tibble(
        dataset_source_type = "sPlotOpen",
        reference_detail = "Taxon reference",
        mandatory = TRUE
      )
    )

  res <-
    build_database_tables(
      list_source_tables = list_shared,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  data_reference <-
    purrr::chuck(res, "References") |>
    dplyr::filter(reference_detail == "Taxon reference")

  testthat::expect_equal(base::nrow(data_reference), 1L)
  testthat::expect_true(dplyr::pull(data_reference, mandatory))
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("build_database_tables() puts general references first", {
  list_inputs <-
    build_test_database_sources()

  res <-
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      ),
      data_general_references = tibble::tibble(
        reference_detail = "VegVault reference",
        mandatory = TRUE
      )
    )

  data_first <-
    purrr::chuck(res, "References") |>
    dplyr::slice(1L)

  testthat::expect_equal(dplyr::pull(data_first, reference_id), 1L)
  testthat::expect_equal(
    dplyr::pull(data_first, reference_detail),
    "VegVault reference"
  )
  testthat::expect_true(dplyr::pull(data_first, mandatory))
})

testthat::test_that("build_database_tables() builds the abiotic tables", {
  list_inputs <-
    build_test_database_sources()

  list_with_abiotic <-
    c(
      purrr::chuck(list_inputs, "list_source_tables"),
      base::list(
        climate_bio4 = build_test_abiotic_source(
          name_variable = "bio4",
          vec_sample_names = c("splot_101", "splot_102"),
          vec_values = c(10, 20)
        ),
        climate_bio1 = build_test_abiotic_source(
          name_variable = "bio1",
          vec_sample_names = "splot_101",
          vec_values = 5
        ),
        palaeo_bio4 = build_test_abiotic_source(
          name_variable = "bio4",
          vec_sample_names = "splot_103",
          vec_values = 30,
          reference = "Palaeoclimate citation"
        )
      )
    )

  res <-
    build_database_tables(
      list_source_tables = list_with_abiotic,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    )

  # Variable ids follow the order of the sources, not the names
  data_variables <-
    purrr::chuck(res, "AbioticVariable")

  testthat::expect_equal(
    dplyr::pull(data_variables, abiotic_variable_name),
    c("bio4", "bio1")
  )
  testthat::expect_equal(
    dplyr::pull(data_variables, abiotic_variable_id),
    c(1L, 2L)
  )

  data_values <-
    purrr::chuck(res, "AbioticData")

  testthat::expect_named(
    data_values,
    c("sample_id", "abiotic_variable_id", "abiotic_value")
  )
  testthat::expect_equal(base::nrow(data_values), 4L)

  # bio4 has the citations of both of its sources
  testthat::expect_equal(
    purrr::chuck(res, "AbioticVariableReference") |>
      dplyr::filter(abiotic_variable_id == 1L) |>
      base::nrow(),
    2L
  )
})

testthat::test_that("build_database_tables() refuses abiotic conflicts", {
  list_inputs <-
    build_test_database_sources()

  list_unit_conflict <-
    c(
      purrr::chuck(list_inputs, "list_source_tables"),
      base::list(
        climate_bio4 = build_test_abiotic_source(
          name_variable = "bio4",
          vec_sample_names = "splot_101",
          vec_values = 10
        ),
        palaeo_bio4 = build_test_abiotic_source(
          name_variable = "bio4",
          vec_sample_names = "splot_102",
          vec_values = 20,
          unit = "another unit"
        )
      )
    )

  testthat::expect_error(
    build_database_tables(
      list_source_tables = list_unit_conflict,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "conflicting"
  )

  list_value_twice <-
    c(
      purrr::chuck(list_inputs, "list_source_tables"),
      base::list(
        climate_bio4 = build_test_abiotic_source(
          name_variable = "bio4",
          vec_sample_names = c("splot_101", "splot_101"),
          vec_values = c(10, 11)
        )
      )
    )

  testthat::expect_error(
    build_database_tables(
      list_source_tables = list_value_twice,
      data_unit_conversions = purrr::chuck(
        list_inputs,
        "data_unit_conversions"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "AbioticData"
  )
})

testthat::test_that("build_database_tables() checks the trait rules", {
  list_inputs <-
    build_test_database_sources()

  data_unit_conversions <-
    purrr::chuck(list_inputs, "data_unit_conversions")

  testthat::expect_error(
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = dplyr::slice(data_unit_conversions, -1L),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "TraitsValue"
  )

  testthat::expect_error(
    build_database_tables(
      list_source_tables = purrr::chuck(list_inputs, "list_source_tables"),
      data_unit_conversions = dplyr::mutate(
        data_unit_conversions,
        standardized_unit = "other unit"
      ),
      data_trait_derivations = purrr::chuck(
        list_inputs,
        "data_trait_derivations"
      )
    ),
    regexp = "unit"
  )
})
