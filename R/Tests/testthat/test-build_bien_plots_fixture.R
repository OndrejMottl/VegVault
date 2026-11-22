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

testthat::test_that(
  "bien_plots rejects a taxon repeated within a plot",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here("Data", "Contracts", "bien_plots.yml")
      )

    # Two records of one name in the first plot (contract 2.0.0)
    list_artefact <-
      purrr::assign_in(
        build_bien_plots_fixture(contract = contract),
        where = base::list(1L, "plot_data", 1L),
        value = tibble::tibble(
          name_matched = c("Synthetica alpha", "Synthetica alpha"),
          individual_count = c(12L, 3L)
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = list_artefact,
        contract = contract
      )

    testthat::expect_equal(dplyr::pull(data_findings, check), "key_duplicate")

    testthat::expect_match(dplyr::pull(data_findings, column), "plot_data")
  }
)

testthat::test_that(
  "bien_plots requires the plot identifier",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here("Data", "Contracts", "bien_plots.yml")
      )

    list_fixture <-
      build_bien_plots_fixture(contract = contract)

    list_artefact <-
      purrr::map(
        .x = list_fixture,
        .f = ~ dplyr::select(.x, -plot_id)
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = list_artefact,
        contract = contract
      )

    testthat::expect_equal(dplyr::pull(data_findings, check), "column_missing")

    testthat::expect_equal(dplyr::pull(data_findings, column), "plot_id")

    # The identifier is a key: two plots with one identifier are refused
    list_repeated <-
      purrr::assign_in(
        list_fixture,
        where = base::list(1L, "plot_id"),
        value = c("SYNTH-A__P1", "SYNTH-A__P1", "SYNTH-B__P1")
      )

    data_findings_repeated <-
      diagnose_producer_artefact(
        data_artefact = list_repeated,
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings_repeated, check),
      "key_duplicate"
    )
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
