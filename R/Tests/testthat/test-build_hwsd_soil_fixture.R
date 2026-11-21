#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_hwsd_soil_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "hwsd_soil.yml"
        )
      )

    res <-
      build_hwsd_soil_fixture(contract = contract)

    testthat::expect_type(res, "list")

    testthat::expect_length(res, 1L)

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

    # The variable name of the export stays HWSD2
    testthat::expect_equal(
      res |>
        purrr::chuck(1) |>
        dplyr::pull(var_name) |>
        base::unique(),
      "HWSD2"
    )
  }
)

testthat::test_that(
  "build_hwsd_soil_fixture() names files by date and hash",
  {
    res <-
      build_hwsd_soil_fixture(date_file = "2001-02-03")

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
  "build_hwsd_soil_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_hwsd_soil_fixture(),
      build_hwsd_soil_fixture()
    )
  }
)

testthat::test_that(
  "build_hwsd_soil_fixture() matches the shipped fixtures",
  {
    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_hwsd_soil_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "hwsd_soil"
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
  "build_hwsd_soil_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "hwsd_soil.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_hwsd_soil_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "class_mismatch"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      "value"
    )
  }
)

testthat::test_that(
  "build_hwsd_soil_fixture() uses the climate grid",
  {
    data_soil <-
      build_hwsd_soil_fixture() |>
      purrr::chuck(1)

    data_climate <-
      build_chelsa_neoclimate_fixture() |>
      purrr::chuck(1)

    testthat::expect_equal(
      dplyr::select(data_soil, long, lat),
      dplyr::select(data_climate, long, lat)
    )
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_hwsd_soil_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "splot_plots.yml"
        )
      )

    testthat::expect_error(
      build_hwsd_soil_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_hwsd_soil_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_hwsd_soil_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
