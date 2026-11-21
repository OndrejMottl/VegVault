#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

# Variables of the test rules, with their contract labels
data_test_variables <-
  tibble::tribble(
    ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit,
    ~measure_details,
    1L, "bio1", "C (degree Celsius)", "mean annual air temperature",
    2L, "bio4", "C/100 (hundredths of a degree Celsius)",
    "temperature seasonality",
    3L, "bio12", "kg m-2 year-1", "annual precipitation amount",
    4L, "bio18", "kg m-2 quarter-1",
    "precipitation amount of the warmest quarter",
    5L, "HWSD2", "Unitless", NA_character_
  )

# Plausible values at two gridpoints, at age 0 and 500 for bio1
data_test_values <-
  tibble::tribble(
    ~long, ~lat, ~age, ~variable, ~value,
    14.1, 50.1, 0, "bio1", 8.5,
    16.1, 49.6, 0, "bio1", 9,
    14.1, 50.1, 500, "bio1", 7.5,
    14.1, 50.1, 0, "bio4", 720.4,
    16.1, 49.6, 0, "bio4", 715.9,
    14.1, 50.1, 0, "bio12", 600,
    16.1, 49.6, 0, "bio12", 550,
    14.1, 50.1, 0, "bio18", 210.6,
    14.1, 50.1, 0, "HWSD2", 7,
    16.1, 49.6, 0, "HWSD2", 19
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_values() passes plausible values", {
  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = data_test_values,
      data_variables = data_test_variables
    )

  res <-
    diagnose_abiotic_values(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules()
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "bio1 / chelsa_neoclimate", "bio4 / chelsa_neoclimate",
      "bio12 / chelsa_neoclimate", "bio18 / chelsa_neoclimate",
      "bio1 / chelsa_trace21k_palaeoclimate",
      "bio12 / chelsa_trace21k_palaeoclimate", "HWSD2 / hwsd_soil"
    )
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "abiotic_values")
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))

  testthat::expect_true(base::all(dplyr::pull(res, observed) == "0"))

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "^2 values from 8.5 to 9")

  testthat::expect_match(vec_messages[6], "^No values")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_values() fails broken values", {
  # The defects of VegVault issue 78 (bio4 equal to 0 at age 0), a value
  #   outside the range at an old age, a forbidden value, a soil code that
  #   is neither whole nor allowed, a missing value and a value at an age
  #   that no rule covers
  data_values <-
    dplyr::bind_rows(
      data_test_values,
      tibble::tribble(
        ~long, ~lat, ~age, ~variable, ~value,
        18, 49, 0, "bio4", 0,
        20, 48, 0, "bio4", 0,
        18, 49, 500, "bio1", 99,
        18, 49, 0, "bio18", 6553.5,
        18, 49, 0, "HWSD2", 2.5,
        20, 48, 0, "bio1", NA_real_,
        18, 49, 250, "bio1", 8
      )
    )

  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = data_values,
      data_variables = data_test_variables
    )

  res <-
    diagnose_abiotic_values(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules()
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "bio1 / chelsa_neoclimate", "bio4 / chelsa_neoclimate",
      "bio12 / chelsa_neoclimate", "bio18 / chelsa_neoclimate",
      "bio1 / chelsa_trace21k_palaeoclimate",
      "bio12 / chelsa_trace21k_palaeoclimate", "HWSD2 / hwsd_soil",
      "bio1 / no rule"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("fail", "fail", "pass", "fail", "fail", "pass", "fail", "fail")
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("1", "2", "0", "1", "1", "0", "1", "1")
  )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "missing: 1")

  testthat::expect_match(vec_messages[2], "at or below 0: 2")

  testthat::expect_match(vec_messages[4], "forbidden value: 1")

  testthat::expect_match(vec_messages[5], "above 45: 1")

  testthat::expect_match(vec_messages[7], "not an allowed value: 1")

  testthat::expect_match(vec_messages[7], "not a whole number: 1")

  testthat::expect_match(vec_messages[8], "no rule covers: 1")
})

testthat::test_that("diagnose_abiotic_values() flags capped values", {
  # The CHELSA V2.1 bio12 storage cap, kept as a lower bound in 2.0.0
  data_values <-
    dplyr::bind_rows(
      data_test_values,
      tibble::tibble(
        long = 18, lat = 49, age = 0, variable = "bio12", value = 6553.5
      )
    )

  list_build <-
    build_abiotic_validation_database(
      dir = withr::local_tempdir(),
      data_values = data_values,
      data_variables = data_test_variables
    )

  res <-
    diagnose_abiotic_values(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_rules = build_abiotic_test_rules(),
      list_capped_values = base::list(
        chelsa_neoclimate = base::list(bio12 = 6553.5)
      )
    )

  data_bio12 <-
    dplyr::filter(res, scope == "bio12 / chelsa_neoclimate")

  testthat::expect_equal(dplyr::pull(data_bio12, status), "flag")

  testthat::expect_equal(dplyr::pull(data_bio12, observed), "1")

  testthat::expect_match(
    dplyr::pull(data_bio12, message),
    "at the storage cap 6553.5, a lower bound: 1"
  )

  data_other <-
    dplyr::filter(res, scope != "bio12 / chelsa_neoclimate")

  testthat::expect_true(base::all(dplyr::pull(data_other, status) == "pass"))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_abiotic_values() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_abiotic_values(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      data_rules = build_abiotic_test_rules()
    ),
    regexp = "not the database of the build manifest"
  )
})
