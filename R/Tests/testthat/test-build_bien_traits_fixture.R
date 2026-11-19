#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_bien_traits_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "bien_traits.yml"
        )
      )

    res <-
      build_bien_traits_fixture(contract = contract)

    testthat::expect_type(res, "list")

    testthat::expect_length(res, 3L)

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
  "build_bien_traits_fixture() names files by date and hash",
  {
    res <-
      build_bien_traits_fixture(date_file = "2001-02-03")

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
  "build_bien_traits_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_bien_traits_fixture(),
      build_bien_traits_fixture()
    )
  }
)

testthat::test_that(
  "build_bien_traits_fixture() matches the shipped fixtures",
  {
    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_bien_traits_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "bien_traits"
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
  "build_bien_traits_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "bien_traits.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_bien_traits_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "file_duplicate"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      NA_character_
    )
  }
)

testthat::test_that(
  "build_bien_traits_fixture() numbers parts from 0",
  {
    vec_names <-
      build_bien_traits_fixture() |>
      base::names()

    testthat::expect_equal(
      stringr::str_match(vec_names, "^data_traits_bien_([0-9]+)_")[, 2],
      c("0", "1", "2")
    )
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_bien_traits_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "splot_plots.yml"
        )
      )

    testthat::expect_error(
      build_bien_traits_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_bien_traits_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_bien_traits_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
