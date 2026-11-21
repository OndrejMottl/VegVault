#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

data_test_variables <-
  tibble::tribble(
    ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit,
    ~measure_details,
    1L, "bio1", "C (degree Celsius)", "mean annual air temperature",
    2L, "bio4", "C/100 (hundredths of a degree Celsius)",
    "temperature seasonality",
    3L, "bio12", "kg m-2 year-1", "annual precipitation amount",
    4L, "bio18", "kg m-2 quarter-1",
    "precipitation amount of the warmest quarter"
  )

# Thresholds by artefact, rule and variable; 1 never flags a share
list_test_thresholds <-
  base::list(
    chelsa_neoclimate = base::list(
      max = base::list(bio1 = 1, bio4 = 1, bio12 = 0.05, bio18 = 1),
      step = base::list(bio1 = 0.5, bio4 = 1, bio12 = 1, bio18 = 1)
    ),
    chelsa_trace21k_palaeoclimate = base::list(
      max = base::list(bio1 = 1, bio12 = 0.05),
      step = base::list(bio1 = 1, bio12 = 1),
      age_deviation = base::list(bio1 = 1, bio12 = 0.5)
    )
  )

list_test_exceptions <-
  base::list(
    base::list(
      artefact_id = "chelsa_trace21k_palaeoclimate",
      variables = c("bio12", "bio18", "bio19"),
      rules = c("max", "step"),
      lat_min = -91,
      lat_max = -74,
      reason = "No downscaled precipitation south of 74 S."
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_zero_shares() passes without zeros", {
  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = tibble::tribble(
        ~long, ~lat, ~age, ~variable, ~value,
        14.1, 50.1, 0, "bio1", 8.5,
        14.2, 50.2, 0, "bio1", 9
      ),
      data_variables = data_test_variables
    )

  res <-
    diagnose_abiotic_zero_shares(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules(),
      list_thresholds = list_test_thresholds,
      list_exceptions = list_test_exceptions,
      min_values_per_band = 2L
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  # The soil rule has no thresholds, so it is not evaluated
  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "bio1 / chelsa_neoclimate", "bio4 / chelsa_neoclimate",
      "bio12 / chelsa_neoclimate", "bio18 / chelsa_neoclimate",
      "bio1 / chelsa_trace21k_palaeoclimate",
      "bio12 / chelsa_trace21k_palaeoclimate"
    )
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "abiotic_zero_shares")
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))

  testthat::expect_match(dplyr::pull(res, message)[1], "bands evaluated: 1")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_zero_shares() flags each rule", {
  # bio1 at age 0: zeros south of 65 N (step); bio12 at age 0: a quarter
  #   of zeros (max); bio18: one zero, too few values to evaluate; bio12
  #   in the past: zeros at 1500 years only (max and age deviation), and
  #   zeros near the South Pole (an accepted exception)
  data_values <-
    tibble::tribble(
      ~long, ~lat, ~age, ~variable, ~value,
      10, 65.1, 0, "bio1", 5,
      10, 65.2, 0, "bio1", 5.5,
      10, 64.1, 0, "bio1", 0,
      10, 64.2, 0, "bio1", 0,
      12, 50.1, 0, "bio12", 0,
      12, 50.2, 0, "bio12", 600,
      12, 50.3, 0, "bio12", 550,
      12, 50.4, 0, "bio12", 700,
      14, 30.1, 0, "bio18", 0,
      16, 10.1, 500, "bio12", 900,
      16, 10.2, 500, "bio12", 950,
      16, 10.1, 1000, "bio12", 910,
      16, 10.2, 1000, "bio12", 940,
      16, 10.1, 1500, "bio12", 0,
      16, 10.2, 1500, "bio12", 0,
      18, -79.9, 500, "bio12", 0,
      18, -79.8, 500, "bio12", 0
    )

  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = data_values,
      data_variables = data_test_variables
    )

  res <-
    diagnose_abiotic_zero_shares(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules(),
      list_thresholds = list_test_thresholds,
      list_exceptions = list_test_exceptions,
      min_values_per_band = 2L
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "bio1 / chelsa_neoclimate / age 0", "bio4 / chelsa_neoclimate",
      "bio12 / chelsa_neoclimate / age 0", "bio18 / chelsa_neoclimate",
      "bio1 / chelsa_trace21k_palaeoclimate",
      "bio12 / chelsa_trace21k_palaeoclimate / age 1500"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "pass", "flag", "pass", "pass", "flag")
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("1", "0", "1", "0", "0", "2")
  )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "step above 0.5 in band 64 to 65")

  testthat::expect_match(vec_messages[3], "share above 0.05 in band 50 to 51")

  testthat::expect_match(vec_messages[4], "not evaluated.*: 1")

  testthat::expect_match(vec_messages[6], "deviation above 0.5 in band 10")

  testthat::expect_match(vec_messages[6], "accepted exceptions: 1")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_zero_shares() needs every threshold", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  list_thresholds <-
    purrr::assign_in(
      list_test_thresholds,
      where = base::list("chelsa_neoclimate", "step", "bio12"),
      value = NULL
    )

  testthat::expect_error(
    diagnose_abiotic_zero_shares(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules(),
      list_thresholds = list_thresholds
    ),
    regexp = "threshold"
  )
})

testthat::test_that("diagnose_abiotic_zero_shares() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_abiotic_zero_shares(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      data_rules = build_abiotic_test_rules(),
      list_thresholds = list_test_thresholds
    ),
    regexp = "not the database of the build manifest"
  )
})
