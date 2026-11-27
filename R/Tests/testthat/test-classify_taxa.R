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
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Quercus robur",
      flag_only_exact_match = NA,
      verbose = FALSE
    ),
    regexp = "flag_only_exact_match"
  )
  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = "Betula",
      name_check_taxon = "Quercus robur",
      sel_kingdom = c("Plantae", "Fungi"),
      verbose = FALSE
    ),
    regexp = "sel_kingdom"
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

  # "Quercus robur L." is sent as "Quercus robur l.", which the services
  #   still match to the species
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

testthat::test_that("classify_taxa() keeps only matches of the kingdom", {
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  res <-
    classify_taxa(
      vec_taxon_names = c("Dryas sp", "Coniferae Undiff", "Betula"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    )

  # "Dryas sp" matches the butterfly (id 100) and the plant (id 400)
  #   equally well: only the plant counts. "Coniferae Undiff" matches only
  #   an animal, so it stays unclassified
  testthat::expect_equal(
    res,
    tibble::tibble(
      taxon_name = c("Dryas sp", "Coniferae Undiff", "Betula"),
      species_name = NA_character_,
      genus_name = c("Dryas", NA_character_, "Betula"),
      family_name = c("Rosaceae", NA_character_, "Betulaceae")
    )
  )
})

testthat::test_that("classify_taxa() sends the names in sentence case", {
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
      vec_taxon_names = c(
        "VACCINIUM VITIS-IDAEA", "Juglans Nigra", "JUGLANS NIGRA", "Betula"
      ),
      name_check_taxon = "QUERCUS ROBUR",
      verbose = FALSE
    )

  # The services treat letter case strictly: a name in capitals is not
  #   matched, and a capitalised second word reaches only the genus. Each
  #   name is sent once, with only its first letter in capitals
  testthat::expect_equal(
    env_calls[["taxa_vec"]],
    c("Quercus robur", "Vaccinium vitis-idaea", "Juglans nigra", "Betula")
  )

  # The names stay as written
  testthat::expect_equal(
    res,
    tibble::tibble(
      taxon_name = c(
        "VACCINIUM VITIS-IDAEA", "Juglans Nigra", "JUGLANS NIGRA", "Betula"
      ),
      species_name = c(
        "Vaccinium vitis-idaea", "Juglans nigra", "Juglans nigra",
        NA_character_
      ),
      genus_name = c("Vaccinium", "Juglans", "Juglans", "Betula"),
      family_name = c(
        "Ericaceae", "Juglandaceae", "Juglandaceae", "Betulaceae"
      )
    )
  )
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

  # Not only the accepted GBIF taxa: otherwise "Ledum Type" and "Lagotis
  #   minor" are matched to a fungus and a ciliate
  testthat::expect_equal(
    purrr::chuck(list_args, "use_only_exact_match"),
    FALSE
  )

  # The check name is not part of the result
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Betula", "Poaceae")
  )

  classify_taxa(
    vec_taxon_names = "Betula",
    name_check_taxon = "Quercus robur",
    flag_only_exact_match = TRUE,
    verbose = FALSE
  )

  testthat::expect_equal(
    purrr::chuck(env_calls[["args"]], "use_only_exact_match"),
    TRUE
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

testthat::test_that("classify_taxa() retries name by name after a lookup", {
  # taxospace stops the whole call when a name is matched to a taxon that
  #   GBIF does not have (for example "Spermatophyta"); the stand-in does
  #   the same for "Bad name", with the error taxospace gives
  env_calls <-
    rlang::env(list_names = base::list())

  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      env_calls[["list_names"]] <-
        c(env_calls[["list_names"]], base::list(taxa_vec))

      if (
        "Bad name" %in% taxa_vec
      ) {
        rlang::abort(
          message = c("i" = "In index: 2.", "i" = "With name: Spermatophyta."),
          parent = base::simpleError("data_source must have at least one row.")
        )
      }

      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_warning(
    res <-
      classify_taxa(
        vec_taxon_names = c("Betula", "Bad name"),
        name_check_taxon = "Quercus robur",
        verbose = FALSE
      ),
    regexp = "name\\s+by\\s+name.*unclassified.*Bad\\s+name"
  )

  testthat::expect_equal(
    res,
    tibble::tibble(
      taxon_name = c("Betula", "Bad name"),
      species_name = c(NA_character_, NA_character_),
      genus_name = c("Betula", NA_character_),
      family_name = c("Betulaceae", NA_character_)
    )
  )

  # One call for the batch, then one per name, the check name first
  testthat::expect_equal(
    env_calls[["list_names"]],
    base::list(
      c("Quercus robur", "Betula", "Bad name"),
      "Quercus robur",
      "Betula",
      "Bad name"
    )
  )
})

testthat::test_that("classify_taxa() stops on other errors", {
  env_calls <-
    rlang::env(n_calls = 0L)

  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      env_calls[["n_calls"]] <- env_calls[["n_calls"]] + 1L

      rlang::abort(message = "Service unavailable.")
    },
    .package = "taxospace"
  )

  testthat::expect_error(
    classify_taxa(
      vec_taxon_names = c("Betula", "Poaceae"),
      name_check_taxon = "Quercus robur",
      verbose = FALSE
    ),
    regexp = "Service unavailable"
  )

  testthat::expect_equal(env_calls[["n_calls"]], 1L)
})

testthat::test_that("classify_taxa() keeps the check in the retry", {
  # The batch hits the lookup error, and in the retry the services do not
  #   answer: the check name gets no family, so nothing is kept
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      if (
        base::length(taxa_vec) > 1L
      ) {
        rlang::abort(
          message = "In index: 2.",
          parent = base::simpleError("data_source must have at least one row.")
        )
      }

      base::data.frame(sel_name = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_warning(
    testthat::expect_error(
      classify_taxa(
        vec_taxon_names = c("Betula", "Poaceae"),
        name_check_taxon = "Quercus robur",
        verbose = FALSE
      ),
      regexp = "check name"
    ),
    regexp = "name\\s+by\\s+name"
  )
})

testthat::test_that("classify_taxa() warns when a name fails in company", {
  # As for "Spermatophyta Undiff(Shrubs)": taxospace stops when the name is
  #   classified with others, but returns it unclassified when it is alone
  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      if (
        "Pollen type" %in% taxa_vec &&
          base::length(taxa_vec) > 1L
      ) {
        rlang::abort(
          message = "In index: 2.",
          parent = base::simpleError("data_source must have at least one row.")
        )
      }

      build_test_taxospace_result(vec_names = taxa_vec)
    },
    .package = "taxospace"
  )

  testthat::expect_warning(
    res <-
      classify_taxa(
        vec_taxon_names = c("Betula", "Pollen type"),
        name_check_taxon = "Quercus robur",
        verbose = FALSE
      ),
    regexp = "unclassified.*Pollen\\s+type"
  )

  testthat::expect_equal(
    dplyr::pull(res, genus_name),
    c("Betula", NA_character_)
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
