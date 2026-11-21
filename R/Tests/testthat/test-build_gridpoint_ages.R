#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_gridpoint_ages() gives the time steps", {
  res <-
    build_gridpoint_ages()

  testthat::expect_type(res, "double")

  testthat::expect_equal(res, base::seq(from = 0, to = 18000, by = 500))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_gridpoint_ages() needs allowed time slices", {
  list_contract <-
    yaml::read_yaml(
      here::here("Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml")
    )

  vec_names <-
    purrr::map_chr(
      .x = purrr::chuck(list_contract, "columns"),
      .f = ~ purrr::chuck(.x, "name")
    )

  # A valid contract whose time_id lists no allowed values
  list_contract <-
    purrr::assign_in(
      list_contract,
      where = base::list(
        "columns", base::which(vec_names == "time_id"), "checks"
      ),
      value = base::list(whole_number = TRUE)
    )

  path_contract <-
    base::file.path(
      withr::local_tempdir(),
      "chelsa_trace21k_palaeoclimate.yml"
    )

  yaml::write_yaml(list_contract, path_contract)

  testthat::expect_error(
    build_gridpoint_ages(path_contract = path_contract),
    regexp = "allowed values"
  )
})
