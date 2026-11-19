list_contract_batches <-
  base::list(
    contract_id = "test_batches",
    contract_version = "1.0.0",
    status = "active",
    title = "Test batches",
    producer = base::list(repository = "r", directory = "d"),
    consumers = "a.R",
    file = base::list(
      name_templates = "bio{variable}_batch_{partition}_{date}__{hash}__.qs"
    ),
    partitioning = base::list(scheme = "integer", first = 1L),
    columns = base::list(
      base::list(
        name = "long",
        class = "numeric",
        nullable = FALSE,
        description = "d",
        evidence = "e"
      ),
      base::list(
        name = "time_id",
        class = "character",
        nullable = FALSE,
        description = "d",
        evidence = "e"
      ),
      base::list(
        name = "value",
        class = "numeric",
        nullable = FALSE,
        description = "d",
        evidence = "e"
      )
    ),
    keys = base::list(c("long", "time_id")),
    variables = base::list(
      value_column = "value",
      table = base::list(
        base::list(
          variable = "bio1",
          file_token = "01",
          unit = "C (degree Celsius)",
          description = "d",
          evidence = "e",
          checks = base::list(range = base::list(min = -90, max = 60))
        ),
        base::list(
          variable = "bio12",
          file_token = "12",
          unit = "kg m-2 year-1",
          description = "d",
          evidence = "e",
          checks = base::list(forbidden_values = 6553.5)
        )
      )
    )
  )

list_contract_single <-
  base::list(
    contract_id = "test_single",
    contract_version = "1.0.0",
    status = "active",
    title = "Test single",
    producer = base::list(repository = "r", directory = "d"),
    consumers = "a.R",
    file = base::list(name_templates = "data_single_{date}__{hash}__.qs"),
    partitioning = base::list(scheme = "none"),
    columns = base::list(
      base::list(
        name = "plot_id",
        class = "character",
        nullable = FALSE,
        description = "d",
        evidence = "e"
      )
    ),
    keys = base::list("plot_id")
  )

hash_a <- "0123456789abcdef0123456789abcdef"

vec_names_batches <-
  stringr::str_c(
    c("bio01_batch_1", "bio01_batch_2", "bio12_batch_1"),
    "_2000-01-01__", hash_a, "__.qs"
  )

list_batches_valid <-
  base::list(
    tibble::tibble(long = c(1, 2), time_id = c("0", "0"), value = c(5, 6)),
    tibble::tibble(long = c(1, 2), time_id = c("5", "5"), value = c(7, 8)),
    tibble::tibble(long = c(1, 2), time_id = c("0", "0"), value = c(900, 1))
  ) |>
  rlang::set_names(vec_names_batches)


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_artefact() passes a valid artefact", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_valid,
      contract = contract
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)
})

testthat::test_that("diagnose_producer_artefact() accepts a data frame", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_single,
    file = base::file.path(path_dir, "test_single.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_single.yml")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = tibble::tibble(plot_id = c("a", "a")),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "key_duplicate")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_artefact() checks keys over batches", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  list_batches_overlap <-
    purrr::assign_in(
      list_batches_valid,
      where = base::list(2, "time_id"),
      value = c("0", "5")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_overlap,
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "key_duplicate")

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)

  testthat::expect_match(dplyr::pull(res, message), "bio1")
})

testthat::test_that("diagnose_producer_artefact() applies variable checks", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  list_batches_limit <-
    purrr::assign_in(
      list_batches_valid,
      where = base::list(3, "value"),
      value = c(6553.5, 1)
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_limit,
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "value_forbidden")

  testthat::expect_equal(dplyr::pull(res, column), "value [bio12]")

  testthat::expect_equal(
    dplyr::pull(res, file_name),
    vec_names_batches[3]
  )
})

testthat::test_that("diagnose_producer_artefact() reports every problem", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  list_batches_bad <-
    list_batches_valid |>
    purrr::assign_in(where = base::list(1, "value"), value = c(5, 99)) |>
    purrr::assign_in(where = base::list(2, "time_id"), value = NULL) |>
    rlang::set_names(c(vec_names_batches[1:2], "bio12.qs"))

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_bad,
      contract = contract
    )

  testthat::expect_true(
    base::all(
      c(
        "file_name_pattern", "variable_missing", "column_missing",
        "value_out_of_range"
      ) %in% dplyr::pull(res, check)
    )
  )
})

testthat::test_that("diagnose_producer_artefact() flags non-frame objects", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  list_batches_object <-
    purrr::assign_in(
      list_batches_valid,
      where = 3,
      value = base::list(long = 1)
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_object,
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "object_class")

  testthat::expect_equal(dplyr::pull(res, file_name), vec_names_batches[3])
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_artefact() validates the artefact", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  testthat::expect_error(
    diagnose_producer_artefact(
      data_artefact = purrr::chuck(list_batches_valid, 1),
      contract = contract
    ),
    regexp = "data_artefact"
  )

  testthat::expect_error(
    diagnose_producer_artefact(
      data_artefact = base::unname(list_batches_valid),
      contract = contract
    ),
    regexp = "data_artefact"
  )
})


#----------------------------------------------------------#
# Row minimum, rounded keys and selected variables -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_artefact() flags too few rows", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_single,
    file = base::file.path(path_dir, "test_single.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_single.yml")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = tibble::tibble(plot_id = base::character(0)),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "object_rows")
})

testthat::test_that("diagnose_producer_artefact() checks rounded keys", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_batches,
      rounded_keys = base::list(
        base::list(columns = c("long", "time_id"), digits = 0L)
      )
    ),
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = purrr::assign_in(
        list_batches_valid,
        where = base::list(1, "long"),
        value = c(1.2, 1.4)
      ),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "key_duplicate_rounded")
})

testthat::test_that("diagnose_producer_artefact() limits the variables", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_batches,
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  res <-
    diagnose_producer_artefact(
      data_artefact = list_batches_valid[1:2],
      contract = contract,
      vec_variables = "bio1"
    )

  testthat::expect_equal(base::nrow(res), 0L)
})
