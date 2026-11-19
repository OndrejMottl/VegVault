#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_bien_plots_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "bien_plots.yml"
        )
      )

    res <-
      build_bien_plots_fixture(contract = contract)

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
  }
)

testthat::test_that(
  "build_bien_plots_fixture() names files by date and hash",
  {
    res <-
      build_bien_plots_fixture(date_file = "2001-02-03")

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
  "build_bien_plots_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_bien_plots_fixture(),
      build_bien_plots_fixture()
    )
  }
)

testthat::test_that(
  "build_bien_plots_fixture() matches the shipped fixtures",
  {
    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_bien_plots_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "bien_plots"
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
  "build_bien_plots_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "bien_plots.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_bien_plots_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "column_missing"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      "plot_data[].individual_count"
    )
  }
)

testthat::test_that(
  "build_bien_plots_fixture() has a presence-only record",
  {
    data_plots <-
      build_bien_plots_fixture() |>
      purrr::chuck(1)

    vec_counts <-
      dplyr::pull(data_plots, plot_data) |>
      purrr::map(.f = ~ dplyr::pull(.x, individual_count)) |>
      purrr::list_c()

    testthat::expect_true(base::anyNA(vec_counts))
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_bien_plots_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "splot_plots.yml"
        )
      )

    testthat::expect_error(
      build_bien_plots_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_bien_plots_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_bien_plots_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
