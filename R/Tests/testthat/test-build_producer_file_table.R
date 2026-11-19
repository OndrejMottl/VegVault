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
        name = "value",
        class = "numeric",
        nullable = FALSE,
        description = "Value.",
        evidence = "test"
      )
    ),
    variables = base::list(
      value_column = "value",
      table = base::list(
        base::list(
          variable = "bio1",
          file_token = "01",
          unit = "u",
          description = "d",
          evidence = "e"
        ),
        base::list(
          variable = "bio12",
          file_token = "12",
          unit = "u",
          description = "d",
          evidence = "e"
        )
      )
    )
  )

list_contract_two_formats <-
  base::list(
    contract_id = "test_assembly",
    contract_version = "1.0.0",
    status = "active",
    title = "Test assembly",
    producer = base::list(repository = "r", directory = "d"),
    consumers = "a.R",
    file = base::list(
      name_templates = c(
        "data_assembly_light_{date}__{hash}__.qs",
        "data_assembly_{date}__{hash}__.rds"
      )
    ),
    partitioning = base::list(scheme = "none"),
    columns = base::list(
      base::list(
        name = "dataset_id",
        class = "numeric",
        nullable = FALSE,
        description = "Dataset.",
        evidence = "test"
      )
    )
  )

hash_example <- "0123456789abcdef0123456789abcdef"


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_table() parses names", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_batches.yml")

  yaml::write_yaml(x = list_contract_batches, file = path_contract)

  contract <-
    load_producer_contract(path_contract = path_contract)

  vec_names <-
    c(
      stringr::str_c("bio12_batch_3_2024-08-06__", hash_example, "__.qs"),
      "notes.txt"
    )

  res <-
    build_producer_file_table(
      vec_file_names = vec_names,
      contract = contract
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c(
      "file_name", "is_match", "template_index", "extension", "date",
      "hash", "partition", "variable_token", "variable"
    )
  )

  testthat::expect_equal(dplyr::pull(res, file_name), vec_names)

  testthat::expect_equal(dplyr::pull(res, is_match), c(TRUE, FALSE))

  testthat::expect_equal(dplyr::pull(res, template_index), c(1L, NA))

  testthat::expect_equal(dplyr::pull(res, extension), c("qs", "txt"))

  testthat::expect_equal(dplyr::pull(res, date), c("2024-08-06", NA))

  testthat::expect_equal(dplyr::pull(res, hash), c(hash_example, NA))

  testthat::expect_equal(dplyr::pull(res, partition), c("3", NA))

  testthat::expect_equal(dplyr::pull(res, variable_token), c("12", NA))

  testthat::expect_equal(dplyr::pull(res, variable), c("bio12", NA))
})

testthat::test_that("build_producer_file_table() picks the first template", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_assembly.yml")

  yaml::write_yaml(x = list_contract_two_formats, file = path_contract)

  contract <-
    load_producer_contract(path_contract = path_contract)

  res <-
    build_producer_file_table(
      vec_file_names = c(
        stringr::str_c("data_assembly_2023-12-12__", hash_example, "__.rds"),
        stringr::str_c(
          "data_assembly_light_2023-12-12__", hash_example, "__.qs"
        )
      ),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, template_index), c(2L, 1L))

  testthat::expect_equal(dplyr::pull(res, extension), c("rds", "qs"))

  testthat::expect_equal(
    dplyr::pull(res, partition),
    c(NA_character_, NA_character_)
  )

  testthat::expect_equal(
    dplyr::pull(res, variable),
    c(NA_character_, NA_character_)
  )
})

testthat::test_that("build_producer_file_table() accepts no names", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_assembly.yml")

  yaml::write_yaml(x = list_contract_two_formats, file = path_contract)

  contract <-
    load_producer_contract(path_contract = path_contract)

  res <-
    build_producer_file_table(
      vec_file_names = base::character(0),
      contract = contract
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_type(dplyr::pull(res, is_match), "logical")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_file_table() validates names", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_assembly.yml")

  yaml::write_yaml(x = list_contract_two_formats, file = path_contract)

  contract <-
    load_producer_contract(path_contract = path_contract)

  testthat::expect_error(
    build_producer_file_table(
      vec_file_names = c("a.qs", NA),
      contract = contract
    ),
    regexp = "vec_file_names"
  )

  testthat::expect_error(
    build_producer_file_table(
      vec_file_names = "Outputs/Data/a.qs",
      contract = contract
    ),
    regexp = "vec_file_names"
  )
})
