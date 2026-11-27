#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_trait_unit_conversions_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_unit_conversions.yml"
        )
      )

    res <-
      build_trait_unit_conversions_fixture(contract = contract)

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
  "build_trait_unit_conversions_fixture() uses the fixed file name",
  {
    # The registry file has no date or hash, whatever the date given
    testthat::expect_equal(
      base::names(
        build_trait_unit_conversions_fixture(date_file = "2001-02-03")
      ),
      "unit_conversions.csv"
    )
  }
)

testthat::test_that(
  "build_trait_unit_conversions_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_trait_unit_conversions_fixture(),
      build_trait_unit_conversions_fixture()
    )
  }
)

testthat::test_that(
  "build_trait_unit_conversions_fixture() matches the shipped fixtures",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_unit_conversions.yml"
        )
      )

    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_trait_unit_conversions_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "trait_unit_conversions"
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
  "build_trait_unit_conversions_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_unit_conversions.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_trait_unit_conversions_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "key_duplicate"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      "conversion_rule_key"
    )
  }
)

testthat::test_that(
  "build_trait_unit_conversions_fixture() has the trait fixtures' rules",
  {
    vec_keys_rules <-
      build_trait_unit_conversions_fixture() |>
      purrr::chuck(1) |>
      dplyr::pull(conversion_rule_key)

    vec_keys_traits <-
      c(
        build_try_traits_fixture(),
        build_bien_traits_fixture()
      ) |>
      purrr::map(.f = ~ dplyr::pull(.x, conversion_rule_key)) |>
      base::unlist(use.names = FALSE) |>
      base::unique()

    testthat::expect_true(base::all(vec_keys_traits %in% vec_keys_rules))
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_trait_unit_conversions_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "trait_derivations.yml"
        )
      )

    testthat::expect_error(
      build_trait_unit_conversions_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_trait_unit_conversions_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_trait_unit_conversions_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
