#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("classify_taxa() validates arguments", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = 1L,
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = c("Betula", NA_character_),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = c("Betula", ""),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = c("Betula", "Betula"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = NA_character_,
      verbose = FALSE
    ),
    regexp = "name_check_taxon"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = c("Quercus robur", "Betula"),
      verbose = FALSE
    ),
    regexp = "name_check_taxon"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Quercus robur",
      sel_db_name = c("gnr", "gnr"),
      verbose = FALSE
    ),
    regexp = "sel_db_name"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Quercus robur",
      sel_db_class = NA_character_,
      verbose = FALSE
    ),
    regexp = "sel_db_class"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Quercus robur",
      verbose = "yes"
    ),
    regexp = "verbose"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("classify_taxa() returns one row per name in order", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = c("Poaceae", "Unknown name", "Betula"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(
    res,
    c("taxon_name", "species_name", "genus_name", "family_name")
  )
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Poaceae", "Unknown name", "Betula")
  )
  testthat::expect_type(dplyr::pull(res, family_name), "character")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("classify_taxa() takes the species, genus and family", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = c(
        "Quercus robur L.", "Betula", "Poaceae", "Above family",
        "Unknown name"
      ),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  testthat::expect_equal(
    dplyr::pull(res, species_name),
    c("Quercus robur", NA, NA, NA, NA)
  )
  testthat::expect_equal(
    dplyr::pull(res, genus_name),
    c("Quercus", "Betula", NA, NA, NA)
  )
  testthat::expect_equal(
    dplyr::pull(res, family_name),
    c("Fagaceae", "Betulaceae", "Poaceae", NA, NA)
  )
})

testthat::test_that("classify_taxa() leaves out placeholder species", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = "Ambrosia",
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  # GBIF gives the genus the placeholder species "Ambrosia spec"
  testthat::expect_equal(dplyr::pull(res, species_name), NA_character_)
  testthat::expect_equal(dplyr::pull(res, genus_name), "Ambrosia")
  testthat::expect_equal(dplyr::pull(res, family_name), "Asteraceae")
})

testthat::test_that("classify_taxa() takes the smallest GBIF id of ties", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = "Tied name",
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  # Ids 1000 and 200 match equally well: 200 is the smaller number
  testthat::expect_equal(base::nrow(res), 1L)
  testthat::expect_equal(dplyr::pull(res, species_name), "Species a")
  testthat::expect_equal(dplyr::pull(res, family_name), "Family a")
})

testthat::test_that("classify_taxa() calls taxospace without its cache", {
  env_calls <-
    rlang::env()

  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      env_calls[["taxa_vec"]] <- taxa_vec
      env_calls[["args"]] <- base::list(...)
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = c("Betula", "Poaceae"),
      name_check_taxon = "Quercus robur",
      sel_db_name = "gnr",
      sel_db_class = "itis",
      verbose = FALSE
    )

  # The check name is classified first, with the batch
  testthat::expect_equal(
    env_calls[["taxa_vec"]],
    c("Quercus robur", "Betula", "Poaceae")
  )

  list_args <-
    env_calls[["args"]]

  testthat::expect_equal(purrr::chuck(list_args, "use_cache"), FALSE)
  testthat::expect_equal(purrr::chuck(list_args, "sel_db_name"), "gnr")
  testthat::expect_equal(purrr::chuck(list_args, "sel_db_class"), "itis")

  # The check name is not part of the result
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Betula", "Poaceae")
  )
})

testthat::test_that("classify_taxa() keeps a check name that is a taxon", {
  env_calls <-
    rlang::env()

  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      env_calls[["taxa_vec"]] <- taxa_vec
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = c("Betula", "Quercus robur"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  testthat::expect_equal(
    env_calls[["taxa_vec"]],
    c("Quercus robur", "Betula")
  )
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Betula", "Quercus robur")
  )
  testthat::expect_equal(
    dplyr::pull(res, family_name),
    c("Betulaceae", "Fagaceae")
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("classify_taxa() aborts when the services fail", {
  # taxospace returns only the names when no name could be matched
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      base::data.frame(sel_name = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = c("Betula", "Poaceae"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "check name"
  )
})

testthat::test_that("classify_taxa() aborts when the check has no family", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Above family",
      verbose = FALSE
    ),
    regexp = "check name"
  )
})


#----------------------------------------------------------#
# Messages -----
#----------------------------------------------------------#

testthat::test_that("classify_taxa() reports the classified names", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_message(
    classify_taxa(
      vec_taxon_names = c("Betula", "Unknown name"),
      name_check_taxon = "Quercus robur",
      verbose = TRUE
    ),
    regexp = "1 of 2"
  )
  testthat::expect_no_message(
    classify_taxa(
      vec_taxon_names = c("Betula", "Unknown name"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )
  )
})
