list_contract_test <-
  base::list(
    contract_id = "test_plots",
    contract_version = "1.0.0",
    status = "active",
    title = "Test plots",
    producer = base::list(repository = "r", directory = "d"),
    consumers = "a.R",
    file = base::list(
      name_templates = "data_plots_{partition}_{date}__{hash}__.qs"
    ),
    partitioning = base::list(scheme = "integer", first = 0L),
    columns = base::list(
      base::list(
        name = "plot_id",
        class = "character",
        nullable = FALSE,
        description = "d",
        evidence = "e"
      ),
      base::list(
        name = "longitude",
        class = "numeric",
        nullable = FALSE,
        description = "d",
        evidence = "e",
        checks = base::list(range = base::list(min = -180, max = 180))
      ),
      base::list(
        name = "disposition",
        class = "character",
        nullable = FALSE,
        description = "d",
        evidence = "e",
        checks = base::list(allowed_values = "published")
      ),
      base::list(
        name = "value",
        class = "numeric",
        nullable = FALSE,
        description = "d",
        evidence = "e",
        checks = base::list(forbidden_values = 6553.5)
      ),
      base::list(
        name = "levels",
        class = "list",
        nullable = FALSE,
        description = "d",
        evidence = "e",
        element = base::list(
          class = "data.frame",
          nullable = FALSE,
          columns = base::list(
            base::list(
              name = "sample_id",
              class = "character",
              nullable = FALSE,
              description = "d",
              evidence = "e"
            ),
            base::list(
              name = "age",
              class = "numeric",
              nullable = FALSE,
              description = "d",
              evidence = "e"
            )
          )
        )
      )
    ),
    keys = base::list("plot_id")
  )

hash_a <- "0123456789abcdef0123456789abcdef"

vec_names_valid <-
  stringr::str_c(
    "data_plots_", c("0", "1"), "_2000-01-01__", hash_a, "__.qs"
  )

list_artefact_valid <-
  base::list(
    tibble::tibble(
      plot_id = c("a", "b"),
      longitude = c(10, 20),
      disposition = "published",
      value = c(1, 2),
      levels = base::list(
        tibble::tibble(sample_id = "s1", age = 0),
        tibble::tibble(sample_id = c("s1", "s2"), age = c(-50, 3000))
      )
    ),
    tibble::tibble(
      plot_id = "c",
      longitude = -179,
      disposition = "published",
      value = 3,
      levels = base::list(tibble::tibble(sample_id = "s1", age = 12))
    )
  ) |>
  rlang::set_names(vec_names_valid)

path_dir_contract <-
  withr::local_tempdir(.local_envir = base::environment())

path_contract_test <-
  base::file.path(path_dir_contract, "test_plots.yml")

yaml::write_yaml(x = list_contract_test, file = path_contract_test)


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_producer_artefact() returns data invisibly", {
  contract <-
    load_producer_contract(path_contract = path_contract_test)

  testthat::expect_invisible(
    validate_producer_artefact(
      contract = contract,
      data_artefact = list_artefact_valid,
      verbose = FALSE
    )
  )

  res <-
    validate_producer_artefact(
      contract = contract,
      data_artefact = list_artefact_valid,
      verbose = FALSE
    )

  testthat::expect_identical(res, list_artefact_valid)
})

testthat::test_that("validate_producer_artefact() accepts a contract path", {
  res <-
    validate_producer_artefact(
      contract = path_contract_test,
      data_artefact = list_artefact_valid,
      verbose = FALSE
    )

  testthat::expect_identical(res, list_artefact_valid)
})

testthat::test_that("validate_producer_artefact() reads qs2 and rds files", {
  path_dir <-
    withr::local_tempdir()

  vec_paths <-
    base::file.path(path_dir, vec_names_valid)

  qs2::qs_save(
    object = purrr::chuck(list_artefact_valid, 1),
    file = vec_paths[1]
  )

  qs2::qs_save(
    object = purrr::chuck(list_artefact_valid, 2),
    file = vec_paths[2]
  )

  res <-
    validate_producer_artefact(
      contract = path_contract_test,
      path_artefact = vec_paths,
      verbose = FALSE
    )

  testthat::expect_identical(res, list_artefact_valid)
})

testthat::test_that("validate_producer_artefact() informs when verbose", {
  testthat::expect_message(
    validate_producer_artefact(
      contract = path_contract_test,
      data_artefact = list_artefact_valid,
      verbose = TRUE
    ),
    regexp = "test_plots"
  )

  testthat::expect_no_message(
    validate_producer_artefact(
      contract = path_contract_test,
      data_artefact = list_artefact_valid,
      verbose = FALSE
    )
  )
})


#----------------------------------------------------------#
# Negative cases: each error names the contract and column -----
#----------------------------------------------------------#

testthat::test_that("validate_producer_artefact() flags a missing column", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(1, "longitude"),
          value = NULL
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "test_plots")

  testthat::expect_match(base::conditionMessage(res_error), "longitude")

  testthat::expect_equal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    "column_missing"
  )
})

testthat::test_that("validate_producer_artefact() flags a wrong class", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(2, "longitude"),
          value = "-179"
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "longitude")

  testthat::expect_equal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    "class_mismatch"
  )
})

testthat::test_that("validate_producer_artefact() flags a nested column", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(2, "levels"),
          value = base::list(tibble::tibble(sample_id = "s1"))
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "test_plots")

  testthat::expect_match(
    base::conditionMessage(res_error),
    "levels[].age",
    fixed = TRUE
  )
})

testthat::test_that("validate_producer_artefact() flags duplicate keys", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(2, "plot_id"),
          value = "a"
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "plot_id")

  testthat::expect_equal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    "key_duplicate"
  )
})

testthat::test_that("validate_producer_artefact() flags a missing age", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(1, "levels", 2, "age"),
          value = c(-50, NA)
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "levels[].age",
    fixed = TRUE
  )

  testthat::expect_equal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    "value_missing"
  )
})

testthat::test_that("validate_producer_artefact() flags range and limits", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = list_artefact_valid |>
          purrr::assign_in(
            where = base::list(1, "longitude"),
            value = c(10, 200)
          ) |>
          purrr::assign_in(where = base::list(2, "value"), value = 6553.5),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "longitude")

  testthat::expect_match(base::conditionMessage(res_error), "value")

  testthat::expect_setequal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    c("value_out_of_range", "value_forbidden")
  )
})

testthat::test_that("validate_producer_artefact() flags unpublished rows", {
  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = purrr::assign_in(
          list_artefact_valid,
          where = base::list(2, "disposition"),
          value = "quarantined"
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(base::conditionMessage(res_error), "disposition")

  testthat::expect_equal(
    purrr::chuck(res_error, "findings") |> dplyr::pull(check),
    "value_not_allowed"
  )
})

testthat::test_that("validate_producer_artefact() flags file names, parts", {
  res_error_name <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = rlang::set_names(
          list_artefact_valid,
          c(vec_names_valid[1], "data_plots_1.qs")
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_match(
    base::conditionMessage(res_error_name),
    "data_plots_1.qs",
    fixed = TRUE
  )

  vec_names_gap <-
    stringr::str_c(
      "data_plots_", c("0", "2"), "_2000-01-01__", hash_a, "__.qs"
    )

  res_error_gap <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = rlang::set_names(list_artefact_valid, vec_names_gap),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_equal(
    purrr::chuck(res_error_gap, "findings") |> dplyr::pull(check),
    "partition_gap"
  )

  vec_names_duplicate <-
    stringr::str_c(
      "data_plots_0_", c("2000-01-01", "2000-02-02"), "__", hash_a, "__.qs"
    )

  res_error_duplicate <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = rlang::set_names(
          list_artefact_valid,
          vec_names_duplicate
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_equal(
    purrr::chuck(res_error_duplicate, "findings") |> dplyr::pull(check),
    "file_duplicate"
  )
})

testthat::test_that("validate_producer_artefact() flags unreadable files", {
  path_dir <-
    withr::local_tempdir()

  vec_paths <-
    base::file.path(path_dir, vec_names_valid)

  qs2::qs_save(
    object = purrr::chuck(list_artefact_valid, 1),
    file = vec_paths[1]
  )

  base::writeLines(text = "not a qs2 file", con = vec_paths[2])

  res_error <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        path_artefact = vec_paths,
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_true(
    "file_unreadable" %in%
      (purrr::chuck(res_error, "findings") |> dplyr::pull(check))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_producer_artefact() needs exactly one input", {
  testthat::expect_error(
    validate_producer_artefact(
      contract = path_contract_test,
      verbose = FALSE
    ),
    regexp = "data_artefact"
  )

  testthat::expect_error(
    validate_producer_artefact(
      contract = path_contract_test,
      data_artefact = list_artefact_valid,
      path_artefact = "a.qs",
      verbose = FALSE
    ),
    regexp = "data_artefact"
  )

  testthat::expect_error(
    validate_producer_artefact(
      contract = path_contract_test,
      path_artefact = "no_such_file.qs",
      verbose = FALSE
    ),
    regexp = "path_artefact"
  )
})


#----------------------------------------------------------#
# Shipped contracts and fixtures -----
#----------------------------------------------------------#

testthat::test_that("validate_producer_artefact() passes shipped fixtures", {
  vec_contracts <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$",
      full.names = TRUE
    )

  testthat::expect_gt(base::length(vec_contracts), 0L)

  purrr::walk(
    .x = vec_contracts,
    .f = ~ {
      contract_id <-
        stringr::str_remove(base::basename(.x), "[.]yml$")

      vec_paths <-
        base::list.files(
          path = here::here(
            "Data", "Contracts", "fixtures", "valid", contract_id
          ),
          full.names = TRUE
        )

      testthat::expect_gt(base::length(vec_paths), 0L)

      testthat::expect_no_error(
        validate_producer_artefact(
          contract = .x,
          path_artefact = vec_paths,
          verbose = FALSE
        )
      )
    }
  )
})

testthat::test_that("validate_producer_artefact() rejects broken fixtures", {
  vec_contracts <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$",
      full.names = TRUE
    )

  testthat::expect_gt(base::length(vec_contracts), 0L)

  purrr::walk(
    .x = vec_contracts,
    .f = ~ {
      contract_id <-
        stringr::str_remove(base::basename(.x), "[.]yml$")

      vec_paths <-
        base::list.files(
          path = here::here(
            "Data", "Contracts", "fixtures", "broken", contract_id
          ),
          full.names = TRUE
        )

      testthat::expect_gt(base::length(vec_paths), 0L)

      testthat::expect_error(
        validate_producer_artefact(
          contract = .x,
          path_artefact = vec_paths,
          verbose = FALSE
        ),
        class = "producer_contract_error"
      )
    }
  )
})


#----------------------------------------------------------#
# Empty artefacts and selected variables -----
#----------------------------------------------------------#

testthat::test_that("validate_producer_artefact() rejects empty artefacts", {
  res_error_list <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = base::list(),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_equal(
    purrr::chuck(res_error_list, "findings") |> dplyr::pull(check),
    "no_files"
  )

  res_error_frame <-
    testthat::expect_error(
      validate_producer_artefact(
        contract = path_contract_test,
        data_artefact = rlang::set_names(
          base::list(tibble::tibble()),
          vec_names_valid[1]
        ),
        verbose = FALSE
      ),
      class = "producer_contract_error"
    )

  testthat::expect_true(
    base::all(
      c("column_missing", "object_rows") %in%
        (purrr::chuck(res_error_frame, "findings") |> dplyr::pull(check))
    )
  )
})

testthat::test_that("validate_producer_artefact() checks vec_variables", {
  testthat::expect_error(
    validate_producer_artefact(
      contract = path_contract_test,
      data_artefact = list_artefact_valid,
      vec_variables = "bio1",
      verbose = FALSE
    ),
    regexp = "vec_variables"
  )
})
