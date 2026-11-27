#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_import() reads a validated artefact", {
  list_fixture <-
    build_producer_manifest_fixture(
      dir_root = withr::local_tempdir(),
      vec_contract_ids = "splot_plots"
    )

  data_files <-
    resolve_producer_artefact(
      data_manifest = load_producer_manifest(
        path_manifest = purrr::chuck(list_fixture, "path_manifest"),
        flag_require_all_contracts = FALSE
      ),
      artefact_id = "splot_plots",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  res <-
    load_producer_import(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "splot_plots.yml"),
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    )

  testthat::expect_type(res, "list")

  testthat::expect_named(res, dplyr::pull(data_files, file_name))

  testthat::expect_equal(res, load_producer_artefact(data_files = data_files))
})

testthat::test_that("load_producer_import() reads one variable", {
  list_fixture <-
    build_producer_manifest_fixture(
      dir_root = withr::local_tempdir(),
      vec_contract_ids = "chelsa_neoclimate"
    )

  data_files <-
    resolve_producer_artefact(
      data_manifest = load_producer_manifest(
        path_manifest = purrr::chuck(list_fixture, "path_manifest"),
        flag_require_all_contracts = FALSE
      ),
      artefact_id = "chelsa_neoclimate",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  res <-
    load_producer_import(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      variable = "bio12",
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "long",
        col_lat = "lat",
        flag_margin = TRUE
      )
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(base::names(res), "^CHELSA_bio_12_")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_producer_import() cuts the subset box", {
  list_fixture <-
    build_producer_manifest_fixture(
      dir_root = withr::local_tempdir(),
      vec_contract_ids = "splot_plots"
    )

  data_files <-
    resolve_producer_artefact(
      data_manifest = load_producer_manifest(
        path_manifest = purrr::chuck(list_fixture, "path_manifest"),
        flag_require_all_contracts = FALSE
      ),
      artefact_id = "splot_plots",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  res <-
    load_producer_import(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "splot_plots.yml"),
      list_subset = list(
        enabled = TRUE,
        lon_min = 0,
        lon_max = 30,
        lat_min = 45,
        lat_max = 75,
        margin_lon = 1,
        margin_lat = 1
      ),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    )

  data_splot <-
    dplyr::bind_rows(res)

  data_splot_all <-
    dplyr::bind_rows(load_producer_artefact(data_files = data_files))

  testthat::expect_lt(base::nrow(data_splot), base::nrow(data_splot_all))

  testthat::expect_gt(base::nrow(data_splot), 0L)

  testthat::expect_true(
    base::all(dplyr::between(dplyr::pull(data_splot, longitude), 0, 30))
  )
})

testthat::test_that("load_producer_import() rejects each broken fixture", {
  # The column (or, for file-level faults, the rule) each fixture breaks
  data_broken <-
    tibble::tribble(
      ~artefact_id, ~variable, ~pattern,
      "bien_plots", NA, "plot_data\\[\\]\\.individual_count",
      "bien_traits", NA, "file_duplicate",
      "chelsa_neoclimate", "bio18", "value\\s+\\[bio18\\]",
      "chelsa_trace21k_palaeoclimate", "bio1", "value\\s+\\[bio1\\]",
      "fossilpol_age_uncertainty", NA, "partition_gap",
      "fossilpol_assembly", NA, "levels\\[\\]\\.age",
      "splot_plots", NA, "plot_observation_id",
      "try_traits", NA, "disposition",
      "hwsd_soil", NA, "value",
      "trait_unit_conversions", NA, "conversion_rule_key",
      "trait_derivations", NA, "operation"
    )

  testthat::expect_setequal(
    dplyr::pull(data_broken, artefact_id),
    base::list.files(here::here("Data", "Contracts", "fixtures", "broken"))
  )

  purrr::pwalk(
    .l = data_broken,
    .f = ~ {
      sel_artefact_id <- ..1

      vec_paths <-
        base::list.files(
          path = here::here(
            "Data", "Contracts", "fixtures", "broken", sel_artefact_id
          ),
          full.names = TRUE
        )

      # The rule registries are csv files kept in the producer repository
      data_files <-
        tibble::tibble(
          artefact_id = sel_artefact_id,
          file_name = base::basename(vec_paths),
          path = vec_paths,
          format = dplyr::if_else(
            stringr::str_detect(vec_paths, "[.]csv$"),
            "csv",
            "qs2"
          )
        )

      res_error <-
        testthat::expect_error(
          load_producer_import(
            data_files = data_files,
            path_contract = here::here(
              "Data", "Contracts", stringr::str_c(sel_artefact_id, ".yml")
            ),
            variable = if (
              base::is.na(..2)
            ) {
              NULL
            } else {
              ..2
            },
            list_subset = list(enabled = FALSE),
            list_subset_filter = list(
              col_lon = "long",
              col_lat = "lat",
              flag_margin = FALSE
            )
          ),
          class = "producer_contract_error"
        )

      testthat::expect_match(
        base::conditionMessage(res_error),
        sel_artefact_id,
        info = sel_artefact_id
      )

      testthat::expect_match(
        base::conditionMessage(res_error),
        ..3,
        info = sel_artefact_id
      )
    }
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_import() checks the variable", {
  vec_paths <-
    base::list.files(
      path = here::here(
        "Data", "Contracts", "fixtures", "valid", "chelsa_neoclimate"
      ),
      full.names = TRUE
    )

  data_files <-
    tibble::tibble(
      artefact_id = "chelsa_neoclimate",
      file_name = base::basename(vec_paths),
      path = vec_paths,
      format = "qs2"
    )

  list_filter <-
    list(col_lon = "long", col_lat = "lat", flag_margin = TRUE)

  # A contract with variables is read one variable at a time
  testthat::expect_error(
    load_producer_import(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      list_subset = list(enabled = FALSE),
      list_subset_filter = list_filter
    ),
    regexp = "variable"
  )

  testthat::expect_error(
    load_producer_import(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      variable = "bio2",
      list_subset = list(enabled = FALSE),
      list_subset_filter = list_filter
    ),
    regexp = "bio2"
  )

  # A contract without variables has none to choose
  testthat::expect_error(
    load_producer_import(
      data_files = dplyr::mutate(data_files, artefact_id = "hwsd_soil"),
      path_contract = here::here("Data", "Contracts", "hwsd_soil.yml"),
      variable = "bio1",
      list_subset = list(enabled = FALSE),
      list_subset_filter = list_filter
    ),
    regexp = "variable"
  )
})

testthat::test_that("load_producer_import() needs one artefact", {
  testthat::expect_error(
    load_producer_import(
      data_files = tibble::tibble(
        artefact_id = c("splot_plots", "bien_plots"),
        file_name = c("a.qs", "b.qs"),
        path = c("a.qs", "b.qs"),
        format = "qs2"
      ),
      path_contract = here::here("Data", "Contracts", "splot_plots.yml"),
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    ),
    regexp = "one\\s+artefact"
  )

  testthat::expect_error(
    load_producer_import(
      data_files = tibble::tibble(file_name = "a.qs", path = "a.qs"),
      path_contract = here::here("Data", "Contracts", "splot_plots.yml"),
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    ),
    regexp = "artefact_id"
  )
})
