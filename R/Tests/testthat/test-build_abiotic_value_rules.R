#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_value_rules() reads the contracts", {
  res <-
    build_abiotic_value_rules()

  testthat::expect_named(
    res,
    c(
      "artefact_id", "variable", "unit", "details", "age_min", "age_max",
      "range_min", "range_max", "flag_min_inclusive", "flag_max_inclusive",
      "list_forbidden", "list_allowed", "flag_whole_number"
    )
  )

  vec_climate <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  testthat::expect_equal(
    dplyr::pull(res, artefact_id),
    c(
      base::rep("chelsa_neoclimate", 7L),
      base::rep("chelsa_trace21k_palaeoclimate", 7L),
      "hwsd_soil"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, variable),
    c(vec_climate, vec_climate, "HWSD2")
  )

  testthat::expect_equal(
    dplyr::pull(res, age_min),
    c(base::rep(0, 7L), base::rep(500, 7L), -Inf)
  )

  testthat::expect_equal(
    dplyr::pull(res, age_max),
    c(base::rep(0, 7L), base::rep(18000, 7L), Inf)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_value_rules() keeps each check", {
  res <-
    build_abiotic_value_rules()

  data_bio4 <-
    dplyr::filter(res, variable == "bio4")

  # The exclusive lower bound that rejects the v1 bio4 zeros
  testthat::expect_equal(dplyr::pull(data_bio4, range_min), c(0, 0))

  testthat::expect_equal(dplyr::pull(data_bio4, range_max), c(3000, 3000))

  testthat::expect_equal(
    dplyr::pull(data_bio4, flag_min_inclusive),
    c(FALSE, FALSE)
  )

  testthat::expect_equal(
    dplyr::pull(data_bio4, flag_max_inclusive),
    c(TRUE, TRUE)
  )

  testthat::expect_equal(
    dplyr::pull(data_bio4, unit),
    base::rep("C/100 (hundredths of a degree Celsius)", 2L)
  )

  data_bio18 <-
    dplyr::filter(res, variable == "bio18")

  testthat::expect_equal(
    dplyr::pull(data_bio18, list_forbidden),
    base::list(6553.5, base::numeric(0))
  )

  data_soil <-
    dplyr::filter(res, artefact_id == "hwsd_soil")

  testthat::expect_equal(dplyr::pull(data_soil, unit), "Unitless")

  testthat::expect_true(base::is.na(dplyr::pull(data_soil, details)))

  testthat::expect_true(dplyr::pull(data_soil, flag_whole_number))

  testthat::expect_equal(
    dplyr::pull(data_soil, list_allowed),
    base::list(base::as.numeric(1:32))
  )

  testthat::expect_equal(dplyr::pull(data_soil, range_min), -Inf)

  data_bio1 <-
    dplyr::filter(res, variable == "bio1")

  testthat::expect_false(
    base::any(dplyr::pull(data_bio1, flag_whole_number))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_abiotic_value_rules() refuses two labels", {
  list_contract <-
    yaml::read_yaml(
      here::here("Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml")
    )

  list_contract <-
    purrr::assign_in(
      list_contract,
      where = base::list("variables", "table", 1L, "unit"),
      value = "K"
    )

  path_contract <-
    base::file.path(
      withr::local_tempdir(),
      "chelsa_trace21k_palaeoclimate.yml"
    )

  yaml::write_yaml(list_contract, path_contract)

  testthat::expect_error(
    build_abiotic_value_rules(path_contract_past = path_contract),
    regexp = "different units or descriptions"
  )
})
