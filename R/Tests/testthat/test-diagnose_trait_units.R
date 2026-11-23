#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_units() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "trait_units")

  testthat::expect_equal(dplyr::pull(res, scope), "TraitsValue")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  # The three trait values of the fixture
  testthat::expect_equal(dplyr::pull(res, observed), "3")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_units() fails a value in another unit", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # The plant height domain claims centimetres; its rule gives metres
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = stringr::str_c(
      "UPDATE TraitsDomain SET trait_unit = 'cm'",
      "WHERE trait_domain_id = 1",
      sep = " "
    )
  )

  res <-
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, scope), "Plant heigh")

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_equal(dplyr::pull(res, observed), "2")

  testthat::expect_match(dplyr::pull(res, message), "unit of its rule")
})

testthat::test_that("diagnose_trait_units() checks the derived unit", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # A derivation that turns metres into centimetres, applied to one value:
  #   its output differs from the domain unit, and a second derivation
  #   expects another input unit than the rule gives
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO TraitDerivation VALUES",
          "(1, 'm_to_cm', '1', 'm', 'cm', 'length', 'multiply', 100,",
          "'Test'), (2, 'mm_to_m', '1', 'mm', 'm', 'length', 'multiply',",
          "0.001, 'Test')",
          sep = " "
        )
      )
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "UPDATE TraitsValue SET trait_derivation_id = 1",
          "WHERE trait_id = 1 AND taxon_id = 1",
          sep = " "
        )
      )
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "UPDATE TraitsValue SET trait_derivation_id = 2",
          "WHERE trait_id = 1 AND taxon_id = 4",
          sep = " "
        )
      )
    }
  )

  res <-
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, scope), "Plant heigh")

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_equal(dplyr::pull(res, observed), "2")

  testthat::expect_match(
    dplyr::pull(res, message),
    "1 .*unit of its rule.*1 .*input unit"
  )
})

testthat::test_that("diagnose_trait_units() fails values not finite", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "UPDATE TraitsValue SET trait_value = NULL WHERE trait_id = 2"
      )
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "UPDATE TraitsValue SET trait_value = 9e999",
          "WHERE trait_id = 1 AND taxon_id = 1",
          sep = " "
        )
      )
    }
  )

  res <-
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_setequal(
    dplyr::pull(res, scope),
    c("Leaf Area", "Plant heigh")
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "fail"))

  testthat::expect_true(
    base::all(stringr::str_detect(dplyr::pull(res, message), "finite"))
  )
})


testthat::test_that("diagnose_trait_units() fails a value without a rule", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # The leaf-area value names a conversion rule that does not exist; the
  #   connection does not enforce foreign keys, as in the build
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = stringr::str_c(
      "UPDATE TraitsValue SET trait_unit_conversion_id = 99",
      "WHERE trait_id = 2",
      sep = " "
    )
  )

  res <-
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, scope), "Leaf Area")

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_equal(dplyr::pull(res, observed), "1")

  testthat::expect_match(
    dplyr::pull(res, message),
    "1 without a conversion rule"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_units() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_trait_units(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
