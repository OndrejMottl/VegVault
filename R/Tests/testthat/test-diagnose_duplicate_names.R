#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_duplicate_names() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_duplicate_names(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "Taxa.taxon_name", "Traits.trait_name",
      "TraitsDomain.trait_domain_name",
      "AbioticVariable.abiotic_variable_name"
    )
  )

  testthat::expect_true(base::all(dplyr::pull(res, check_id) == "names"))

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))

  testthat::expect_true(base::all(dplyr::pull(res, observed) == "0"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_duplicate_names() flags repeats and gaps", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # A taxon name written twice more and one taxon without a name; an
  #   abiotic variable name written twice
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO Taxa VALUES (8, 'Picea abies'), (9, 'Picea abies'),",
          "(10, NULL)"
        )
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO AbioticVariable VALUES (3, 'bio1', 'C', '')"
      )
    }
  )

  res <-
    diagnose_duplicate_names(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "pass", "pass", "flag")
  )

  testthat::expect_equal(dplyr::pull(res, observed), c("1", "0", "0", "1"))

  testthat::expect_match(dplyr::pull(res, message)[1], "missing names: 1")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_duplicate_names() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_duplicate_names(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
