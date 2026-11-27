#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "fossilpol_age_uncertainty.yml"
        )
      )

    res <-
      build_fossilpol_age_uncertainty_fixture(contract = contract)

    testthat::expect_type(res, "list")

    testthat::expect_length(res, 2L)

    testthat::expect_true(
      base::all(purrr::map_lgl(.x = res, .f = base::is.data.frame))
    )

    testthat::expect_true(
      base::all(
        stringr::str_detect(
          base::names(res),
          purrr::chuck(contract, "file", "name_patterns")[1]
        )
      )
    )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = res,
        contract = contract
      )

    testthat::expect_equal(base::nrow(data_findings), 0L)
  }
)

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() names files by date and hash",
  {
    res <-
      build_fossilpol_age_uncertainty_fixture(date_file = "2001-02-03")

    vec_hashes <-
      purrr::map_chr(.x = res, .f = rlang::hash)

    testthat::expect_true(
      base::all(stringr::str_detect(base::names(res), "_2001-02-03__"))
    )

    testthat::expect_equal(
      stringr::str_match(base::names(res), "__([0-9a-f]{32})__")[, 2],
      base::unname(vec_hashes)
    )
  }
)

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_fossilpol_age_uncertainty_fixture(),
      build_fossilpol_age_uncertainty_fixture()
    )
  }
)

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() matches the shipped fixtures",
  {
    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_fossilpol_age_uncertainty_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "fossilpol_age_uncertainty"
          )

        testthat::expect_setequal(
          base::list.files(dir_shipped),
          base::names(list_built)
        )

        list_shipped <-
          base::file.path(dir_shipped, base::names(list_built)) |>
          purrr::map(.f = ~ qs2::qs_read(file = .x)) |>
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
  "build_fossilpol_age_uncertainty_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "fossilpol_age_uncertainty.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_fossilpol_age_uncertainty_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "partition_gap"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      NA_character_
    )
  }
)

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() matches the assembly",
  {
    data_assembly <-
      build_fossilpol_assembly_fixture() |>
      purrr::chuck(1)

    data_uncertainty <-
      build_fossilpol_age_uncertainty_fixture() |>
      dplyr::bind_rows()

    testthat::expect_equal(
      dplyr::pull(data_uncertainty, dataset_id),
      dplyr::pull(data_assembly, dataset_id)
    )

    vec_matrix_samples <-
      dplyr::pull(data_uncertainty, age_uncertainty) |>
      purrr::map(.f = base::colnames)

    vec_level_samples <-
      dplyr::pull(data_assembly, levels) |>
      purrr::map(.f = ~ dplyr::pull(.x, sample_id))

    testthat::expect_equal(vec_matrix_samples, vec_level_samples)
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_fossilpol_age_uncertainty_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "splot_plots.yml"
        )
      )

    testthat::expect_error(
      build_fossilpol_age_uncertainty_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_fossilpol_age_uncertainty_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_fossilpol_age_uncertainty_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
