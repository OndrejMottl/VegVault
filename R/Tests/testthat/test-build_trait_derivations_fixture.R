#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_trait_derivations_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_derivations.yml"
        )
      )

    res <-
      build_trait_derivations_fixture(contract = contract)

    testthat::expect_type(res, "list")

    testthat::expect_length(res, 1L)

    testthat::expect_true(base::is.data.frame(purrr::chuck(res, 1)))

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = res,
        contract = contract
      )

    testthat::expect_equal(base::nrow(data_findings), 0L)
  }
)

testthat::test_that(
  "build_trait_derivations_fixture() uses the fixed file name",
  {
    testthat::expect_equal(
      base::names(
        build_trait_derivations_fixture(date_file = "2001-02-03")
      ),
      "trait_derivations.csv"
    )
  }
)

testthat::test_that(
  "build_trait_derivations_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_trait_derivations_fixture(),
      build_trait_derivations_fixture()
    )
  }
)

testthat::test_that(
  "build_trait_derivations_fixture() matches the shipped fixtures",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_derivations.yml"
        )
      )

    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_trait_derivations_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "trait_derivations"
          )

        testthat::expect_setequal(
          base::list.files(dir_shipped),
          base::names(list_built)
        )

        list_shipped <-
          base::file.path(dir_shipped, base::names(list_built)) |>
          purrr::map(
            .f = ~ load_producer_csv(path_file = .x, contract = contract)
          ) |>
          rlang::set_names(base::names(list_built))

        testthat::expect_identical(list_shipped, list_built)
      }
    )
  }
)


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that(
  "build_trait_derivations_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_derivations.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_trait_derivations_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "value_not_allowed"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      "operation"
    )
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_trait_derivations_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_unit_conversions.yml"
        )
      )

    testthat::expect_error(
      build_trait_derivations_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_trait_derivations_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_trait_derivations_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
