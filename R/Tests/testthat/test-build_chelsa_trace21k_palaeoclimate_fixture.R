#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_chelsa_trace21k_palaeoclimate_fixture() satisfies its contract",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
        )
      )

    res <-
      build_chelsa_trace21k_palaeoclimate_fixture(contract = contract)

    testthat::expect_type(res, "list")

    testthat::expect_length(res, 28L)

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
  "build_chelsa_trace21k_palaeoclimate_fixture() names files by date and hash",
  {
    res <-
      build_chelsa_trace21k_palaeoclimate_fixture(date_file = "2001-02-03")

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
  "build_chelsa_trace21k_palaeoclimate_fixture() is deterministic",
  {
    testthat::expect_identical(
      build_chelsa_trace21k_palaeoclimate_fixture(),
      build_chelsa_trace21k_palaeoclimate_fixture()
    )
  }
)

testthat::test_that(
  "build_chelsa_trace21k_palaeoclimate_fixture() matches the shipped fixtures",
  {
    purrr::walk(
      .x = c("valid", "broken"),
      .f = ~ {
        list_built <-
          build_chelsa_trace21k_palaeoclimate_fixture(
            flag_broken = .x == "broken"
          )

        dir_shipped <-
          here::here(
            "Data", "Contracts", "fixtures", .x,
            "chelsa_trace21k_palaeoclimate"
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
  "build_chelsa_trace21k_palaeoclimate_fixture() breaks exactly one rule",
  {
    contract <-
      load_producer_contract(
        path_contract = here::here(
        "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
        )
      )

    data_findings <-
      diagnose_producer_artefact(
        data_artefact = build_chelsa_trace21k_palaeoclimate_fixture(
          contract = contract,
          flag_broken = TRUE
        ),
        contract = contract
      )

    testthat::expect_equal(
      dplyr::pull(data_findings, check),
      "value_out_of_range"
    )

    testthat::expect_equal(
      dplyr::pull(data_findings, column),
      "value [bio1]"
    )
  }
)

testthat::test_that(
  "build_chelsa_trace21k_palaeoclimate_fixture() spans batches",
  {
    list_fixture <-
      build_chelsa_trace21k_palaeoclimate_fixture()

    vec_names_bio1 <-
      stringr::str_subset(base::names(list_fixture), "^bio01_")

    list_time_ids <-
      list_fixture[vec_names_bio1] |>
      purrr::map(.f = ~ base::unique(dplyr::pull(.x, time_id)))

    testthat::expect_type(base::unlist(list_time_ids), "integer")

    testthat::expect_setequal(
      base::unlist(list_time_ids),
      c(20L, 15L, -40L, -160L)
    )

    # Four batches, the first time slice in batches 1 and 2
    vec_rows_bio1 <-
      purrr::map_int(
        .x = list_fixture[vec_names_bio1],
        .f = base::nrow
      ) |>
      base::unname()

    testthat::expect_equal(vec_rows_bio1, c(5L, 7L, 6L, 6L))

    testthat::expect_true(
      base::length(
        base::intersect(
          purrr::chuck(list_time_ids, 1),
          purrr::chuck(list_time_ids, 2)
        )
      ) > 0L
    )
  }
)


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that(
  "build_chelsa_trace21k_palaeoclimate_fixture() validates arguments",
  {
    contract_other <-
      load_producer_contract(
        path_contract = here::here(
          "Data", "Contracts", "splot_plots.yml"
        )
      )

    testthat::expect_error(
      build_chelsa_trace21k_palaeoclimate_fixture(contract = contract_other),
      regexp = "contract"
    )

    testthat::expect_error(
      build_chelsa_trace21k_palaeoclimate_fixture(flag_broken = "yes"),
      regexp = "flag_broken"
    )

    testthat::expect_error(
      build_chelsa_trace21k_palaeoclimate_fixture(date_file = "2000-1-1"),
      regexp = "date"
    )
  }
)
