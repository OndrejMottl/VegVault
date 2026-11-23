#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_abiotic_variables() validates arguments", {
  testthat::expect_error(
    load_abiotic_variables(path_contract = c("a.yml", "b.yml")),
    regexp = "path_contract"
  )

  testthat::expect_error(
    load_abiotic_variables(path_contract = NA_character_),
    regexp = "path_contract"
  )
})

testthat::test_that("load_abiotic_variables() needs a variables table", {
  testthat::expect_error(
    load_abiotic_variables(
      path_contract = here::here("Data", "Contracts", "hwsd_soil.yml")
    ),
    regexp = "variables"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("load_abiotic_variables() reads the climate contracts", {
  vec_variables <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  res_present <-
    load_abiotic_variables(
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml")
    )

  res_palaeo <-
    load_abiotic_variables(
      path_contract = here::here(
        "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
      )
    )

  testthat::expect_named(res_present, vec_variables)

  testthat::expect_named(res_palaeo, vec_variables)

  testthat::expect_equal(
    purrr::chuck(res_present, "bio1"),
    base::list(
      name = "bio1",
      unit = "C (degree Celsius)",
      details = "mean annual air temperature"
    )
  )

  testthat::expect_true(
    base::all(
      purrr::map_lgl(
        .x = c(res_present, res_palaeo),
        .f = ~ base::identical(base::names(.x), c("name", "unit", "details")) &&
          base::all(purrr::map_lgl(.x = .x, .f = rlang::is_string))
      )
    )
  )
})

testthat::test_that("load_abiotic_variables() takes the contract values", {
  list_contract <-
    load_producer_contract(
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml")
    )

  data_expected <-
    purrr::pluck(list_contract, "variables", "table") |>
    purrr::map(
      .f = ~ tibble::tibble(
        name = purrr::chuck(.x, "variable"),
        unit = purrr::chuck(.x, "unit"),
        details = purrr::chuck(.x, "description")
      )
    ) |>
    purrr::list_rbind()

  res <-
    load_abiotic_variables(
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml")
    ) |>
    purrr::map(.f = tibble::as_tibble) |>
    purrr::list_rbind()

  testthat::expect_equal(res, data_expected)
})
