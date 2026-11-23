#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_classification_tables() validates arguments", {
  data_classification <-
    tibble::tibble(
      taxon_name = "Betula pendula",
      species_name = "Betula pendula",
      genus_name = "Betula",
      family_name = "Betulaceae"
    )

  testthat::expect_error(
    prepare_classification_tables(
      data_classification = "not a table",
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "data_classification"
  )
  testthat::expect_error(
    prepare_classification_tables(
      data_classification = dplyr::select(data_classification, -genus_name),
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "genus_name"
  )
  testthat::expect_error(
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = base::list(dataset_type = "taxa"),
      verbose = FALSE
    ),
    regexp = "references"
  )
  testthat::expect_error(
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = NA
    ),
    regexp = "verbose"
  )
})

testthat::test_that("prepare_classification_tables() refuses repeated names", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Betula pendula", "Betula pendula"),
      species_name = c("Betula pendula", "Betula pubescens"),
      genus_name = "Betula",
      family_name = "Betulaceae"
    )

  testthat::expect_error(
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    ),
    regexp = "Betula pendula"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_classification_tables() fills the template", {
  res <-
    prepare_classification_tables(
      data_classification = tibble::tibble(
        taxon_name = "Betula pendula",
        species_name = "Betula pendula",
        genus_name = "Betula",
        family_name = "Betulaceae"
      ),
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

  vec_rows <-
    purrr::map_int(.x = res, .f = base::nrow)

  vec_filled <-
    c("taxa", "taxon_references", "taxon_classification")

  testthat::expect_true(base::all(vec_rows[vec_filled] > 0L))
  testthat::expect_true(
    base::all(vec_rows[base::setdiff(base::names(vec_rows), vec_filled)] == 0L)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_classification_tables() classifies the ranks", {
  data_classification <-
    tibble::tibble(
      taxon_name = c(
        "Quercus robur L.", "Quercus petraea", "Betula", "Unknown name"
      ),
      species_name = c("Quercus robur", "Quercus petraea", NA, NA),
      genus_name = c("Quercus", "Quercus", "Betula", NA),
      family_name = c("Fagaceae", "Fagaceae", "Betulaceae", NA)
    )

  res <-
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_expected <-
    tibble::tribble(
      ~taxon_name, ~species_name, ~genus_name, ~family_name,
      "Betula", NA, "Betula", "Betulaceae",
      "Betulaceae", NA, NA, "Betulaceae",
      "Fagaceae", NA, NA, "Fagaceae",
      "Quercus", NA, "Quercus", "Fagaceae",
      "Quercus petraea", "Quercus petraea", "Quercus", "Fagaceae",
      "Quercus robur", "Quercus robur", "Quercus", "Fagaceae",
      "Quercus robur L.", "Quercus robur", "Quercus", "Fagaceae"
    )

  # The classified names, and every rank name with the ranks above it;
  #   a name without a rank has no row
  testthat::expect_equal(
    purrr::chuck(res, "taxon_classification"),
    data_expected
  )
})

testthat::test_that("prepare_classification_tables() adds the rank names", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur L.", "Betula", "Unknown name"),
      species_name = c("Quercus robur", NA, NA),
      genus_name = c("Quercus", "Betula", NA),
      family_name = c("Fagaceae", "Betulaceae", NA)
    )

  res <-
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  vec_rank_names <-
    c("Betula", "Betulaceae", "Fagaceae", "Quercus", "Quercus robur")

  # Every rank name, also a taxon of a source ("Betula"), is a taxon
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "taxa"), taxon_name),
    vec_rank_names
  )

  # with the taxon references of the source entry
  data_references <-
    purrr::chuck(res, "taxon_references")

  testthat::expect_equal(
    dplyr::pull(data_references, taxon_name),
    vec_rank_names
  )
  testthat::expect_equal(
    base::unique(dplyr::pull(data_references, reference_detail)),
    "Taxon reference"
  )
  testthat::expect_equal(
    base::unique(dplyr::pull(data_references, mandatory)),
    FALSE
  )
})

testthat::test_that("prepare_classification_tables() resolves homonyms", {
  # "Morus" is a genus of Moraceae for two names and of Sulidae for one;
  #   "Tiegenus" is in two families, once each
  data_classification <-
    tibble::tibble(
      taxon_name = c(
        "Morus alba", "Morus nigra", "Morus bassanus", "Tiegenus b",
        "Tiegenus a"
      ),
      species_name = c(
        "Morus alba", "Morus nigra", "Morus bassanus", "Tiegenus b",
        "Tiegenus a"
      ),
      genus_name = c("Morus", "Morus", "Morus", "Tiegenus", "Tiegenus"),
      family_name = c("Moraceae", "Moraceae", "Sulidae", "Bfam", "Afam")
    )

  res <-
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_genera <-
    purrr::chuck(res, "taxon_classification") |>
    dplyr::filter(taxon_name %in% c("Morus", "Tiegenus"))

  testthat::expect_equal(
    dplyr::pull(data_genera, family_name),
    c("Moraceae", "Afam")
  )

  # Each name has one classification row
  testthat::expect_false(
    base::anyDuplicated(
      dplyr::pull(purrr::chuck(res, "taxon_classification"), taxon_name)
    ) > 0L
  )
})

testthat::test_that("prepare_classification_tables() keeps classified names", {
  # "Betula" is classified itself (as a genus of Betulaceae) and is also
  #   the genus of "Betula pendula": its own classification is kept
  data_classification <-
    tibble::tibble(
      taxon_name = c("Betula", "Betula pendula"),
      species_name = c(NA, "Betula pendula"),
      genus_name = c("Betula", "Betula"),
      family_name = c("Betulaceae", "Betulaceae")
    )

  res <-
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  data_betula <-
    purrr::chuck(res, "taxon_classification") |>
    dplyr::filter(taxon_name == "Betula")

  testthat::expect_equal(base::nrow(data_betula), 1L)
  testthat::expect_equal(dplyr::pull(data_betula, genus_name), "Betula")
})

testthat::test_that("prepare_classification_tables() accepts no names", {
  res <-
    prepare_classification_tables(
      data_classification = tibble::tibble(
        taxon_name = "Unknown name",
        species_name = NA_character_,
        genus_name = NA_character_,
        family_name = NA_character_
      ),
      list_source = build_test_source_config(),
      verbose = FALSE
    )

  testthat::expect_named(res, base::names(build_source_table_template()))
  testthat::expect_true(
    base::all(purrr::map_int(.x = res, .f = base::nrow) == 0L)
  )
})


#----------------------------------------------------------#
# Messages -----
#----------------------------------------------------------#

testthat::test_that("prepare_classification_tables() reports the counts", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur L.", "Unknown name"),
      species_name = c("Quercus robur", NA),
      genus_name = c("Quercus", NA),
      family_name = c("Fagaceae", NA)
    )

  testthat::expect_message(
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = TRUE
    ),
    regexp = "1 of 2"
  )
  testthat::expect_no_message(
    prepare_classification_tables(
      data_classification = data_classification,
      list_source = build_test_source_config(),
      verbose = FALSE
    )
  )
})
