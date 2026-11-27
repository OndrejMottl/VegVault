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

list_contract_letters <-
  base::list(
    contract_id = "test_letters",
    contract_version = "1.0.0",
    status = "active",
    title = "Test letters",
    producer = base::list(repository = "r", directory = "d"),
    consumers = "a.R",
    file = base::list(
      name_templates = "data_part_{partition}_{date}__{hash}__.qs"
    ),
    partitioning = base::list(scheme = "letter", first = "A"),
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

list_contract_single <-
  purrr::list_modify(
    list_contract_letters,
    contract_id = "test_single",
    file = base::list(name_templates = "data_single_{date}__{hash}__.qs"),
    partitioning = base::list(scheme = "none")
  )

hash_a <- "0123456789abcdef0123456789abcdef"

hash_b <- "fedcba9876543210fedcba9876543210"

vec_batches_complete <-
  c(
    stringr::str_c("bio01_batch_1_2024-08-06__", hash_a, "__.qs"),
    stringr::str_c("bio01_batch_2_2024-08-06__", hash_a, "__.qs"),
    stringr::str_c("bio12_batch_1_2024-08-06__", hash_a, "__.qs"),
    stringr::str_c("bio12_batch_2_2024-08-06__", hash_a, "__.qs")
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_file_names() passes complete sets", {
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
    diagnose_producer_file_names(
      vec_file_names = vec_batches_complete,
      contract = contract
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(
    res,
    c(
      "contract_id", "file_name", "column", "check", "n_violations",
      "message"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_file_names() flags bad names", {
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
    diagnose_producer_file_names(
      vec_file_names = c(vec_batches_complete, "bio01_batch_3.qs"),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "file_name_pattern")

  testthat::expect_equal(dplyr::pull(res, file_name), "bio01_batch_3.qs")

  testthat::expect_equal(dplyr::pull(res, contract_id), "test_batches")
})

testthat::test_that("diagnose_producer_file_names() flags gaps, duplicates", {
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

  res_gap <-
    diagnose_producer_file_names(
      vec_file_names = c(
        vec_batches_complete[-2],
        stringr::str_c("bio01_batch_3_2024-08-06__", hash_a, "__.qs")
      ),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res_gap, check), "partition_gap")

  testthat::expect_match(dplyr::pull(res_gap, message), "bio1")

  testthat::expect_match(dplyr::pull(res_gap, message), "2")

  res_duplicate <-
    diagnose_producer_file_names(
      vec_file_names = c(
        vec_batches_complete,
        stringr::str_c("bio12_batch_2_2024-01-02__", hash_b, "__.qs")
      ),
      contract = contract
    )

  testthat::expect_equal(
    dplyr::pull(res_duplicate, check),
    "file_duplicate"
  )

  testthat::expect_equal(dplyr::pull(res_duplicate, n_violations), 2L)

  res_before_first <-
    diagnose_producer_file_names(
      vec_file_names = c(
        vec_batches_complete,
        stringr::str_c("bio12_batch_0_2024-08-06__", hash_a, "__.qs")
      ),
      contract = contract
    )

  testthat::expect_equal(
    dplyr::pull(res_before_first, check),
    "partition_unexpected"
  )
})

testthat::test_that("diagnose_producer_file_names() flags missing variables", {
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
    diagnose_producer_file_names(
      vec_file_names = vec_batches_complete[1:2],
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "variable_missing")

  testthat::expect_match(dplyr::pull(res, message), "bio12")
})

testthat::test_that("diagnose_producer_file_names() handles letters", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = list_contract_letters,
    file = base::file.path(path_dir, "test_letters.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_letters.yml")
    )

  vec_names_ok <-
    stringr::str_c("data_part_", c("A", "B", "C"), "_2023-12-12__", hash_a)

  res_ok <-
    diagnose_producer_file_names(
      vec_file_names = stringr::str_c(vec_names_ok, "__.qs"),
      contract = contract
    )

  testthat::expect_equal(base::nrow(res_ok), 0L)

  res_gap <-
    diagnose_producer_file_names(
      vec_file_names = stringr::str_c(vec_names_ok[c(1, 3)], "__.qs"),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res_gap, check), "partition_gap")

  testthat::expect_match(dplyr::pull(res_gap, message), "B")
})

testthat::test_that("diagnose_producer_file_names() handles single files", {
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

  res_ok <-
    diagnose_producer_file_names(
      vec_file_names = stringr::str_c(
        "data_single_2023-12-12__", hash_a, "__.qs"
      ),
      contract = contract
    )

  testthat::expect_equal(base::nrow(res_ok), 0L)

  res_two <-
    diagnose_producer_file_names(
      vec_file_names = c(
        stringr::str_c("data_single_2023-12-12__", hash_a, "__.qs"),
        stringr::str_c("data_single_2024-01-01__", hash_b, "__.qs")
      ),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res_two, check), "file_duplicate")

  res_none <-
    diagnose_producer_file_names(
      vec_file_names = base::character(0),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res_none, check), "no_files")
})


#----------------------------------------------------------#
# Partition count, numbering and selected variables -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_file_names() checks partition count", {
  path_dir <-
    withr::local_tempdir()

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_batches,
      where = c("partitioning", "count"),
      value = 3L
    ),
    file = base::file.path(path_dir, "test_batches.yml")
  )

  contract <-
    load_producer_contract(
      path_contract = base::file.path(path_dir, "test_batches.yml")
    )

  res <-
    diagnose_producer_file_names(
      vec_file_names = vec_batches_complete,
      contract = contract
    )

  testthat::expect_equal(
    dplyr::pull(res, check),
    c("partition_count", "partition_count")
  )

  testthat::expect_match(dplyr::pull(res, message), "3", all = TRUE)
})

testthat::test_that("diagnose_producer_file_names() reads 01 as 1", {
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
    diagnose_producer_file_names(
      vec_file_names = c(
        vec_batches_complete,
        stringr::str_c("bio01_batch_01_2024-08-06__", hash_b, "__.qs")
      ),
      contract = contract
    )

  testthat::expect_equal(dplyr::pull(res, check), "file_duplicate")
})

testthat::test_that("diagnose_producer_file_names() limits the variables", {
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
    diagnose_producer_file_names(
      vec_file_names = vec_batches_complete[1:2],
      contract = contract,
      vec_variables = "bio1"
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_error(
    diagnose_producer_file_names(
      vec_file_names = vec_batches_complete[1:2],
      contract = contract,
      vec_variables = "bio5"
    ),
    regexp = "vec_variables"
  )
})
