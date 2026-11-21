list_record_base <-
  base::list(
    vegvault_commit = "0123456789abcdef0123456789abcdef01234567",
    producer_repository = "OndrejMottl/VegVault-Vegetation_data",
    files = base::list(
      base::list(
        path = "R/Functions/Contracts/load_example_contract.R",
        sha256 = base::strrep("a", 64L)
      ),
      base::list(
        path = "Data/Contracts/splot_plots.yml",
        sha256 = base::strrep("b", 64L),
        contract_id = "splot_plots",
        contract_version = "1.0.0"
      )
    )
  )


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_contract_copy_record() validates its input", {
  dir_producer <-
    withr::local_tempdir()

  testthat::expect_error(
    load_contract_copy_record(
      path_producer = base::file.path(dir_producer, "missing_folder")
    ),
    regexp = "path_producer"
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = c(dir_producer, dir_producer)),
    regexp = "path_producer"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("load_contract_copy_record() reads a valid record", {
  dir_producer <-
    withr::local_tempdir()

  base::dir.create(
    base::file.path(dir_producer, "Data", "Contracts"),
    recursive = TRUE
  )

  yaml::write_yaml(
    x = list_record_base,
    file = base::file.path(
      dir_producer, "Data", "Contracts", "contract_copy.yml"
    )
  )

  res <-
    load_contract_copy_record(path_producer = dir_producer)

  testthat::expect_type(res, "list")

  testthat::expect_named(
    res,
    c("vegvault_commit", "producer_repository", "data_files")
  )

  testthat::expect_equal(
    purrr::chuck(res, "vegvault_commit"),
    "0123456789abcdef0123456789abcdef01234567"
  )

  testthat::expect_equal(
    purrr::chuck(res, "producer_repository"),
    "OndrejMottl/VegVault-Vegetation_data"
  )

  data_files <-
    purrr::chuck(res, "data_files")

  testthat::expect_s3_class(data_files, "tbl_df")

  testthat::expect_named(
    data_files,
    c("path", "sha256", "contract_id", "contract_version")
  )

  testthat::expect_equal(
    dplyr::pull(data_files, path),
    c(
      "Data/Contracts/splot_plots.yml",
      "R/Functions/Contracts/load_example_contract.R"
    )
  )

  testthat::expect_equal(
    dplyr::pull(data_files, sha256),
    c(base::strrep("b", 64L), base::strrep("a", 64L))
  )

  testthat::expect_equal(
    dplyr::pull(data_files, contract_id),
    c("splot_plots", NA_character_)
  )

  testthat::expect_equal(
    dplyr::pull(data_files, contract_version),
    c("1.0.0", NA_character_)
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_contract_copy_record() needs the record file", {
  dir_producer <-
    withr::local_tempdir()

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "contract_copy.yml"
  )

  base::dir.create(
    base::file.path(dir_producer, "Data", "Contracts"),
    recursive = TRUE
  )

  base::writeLines(
    text = "only text",
    con = base::file.path(
      dir_producer, "Data", "Contracts", "contract_copy.yml"
    )
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "contract_copy.yml"
  )
})

testthat::test_that("load_contract_copy_record() checks the top fields", {
  dir_producer <-
    withr::local_tempdir()

  base::dir.create(
    base::file.path(dir_producer, "Data", "Contracts"),
    recursive = TRUE
  )

  path_record <-
    base::file.path(dir_producer, "Data", "Contracts", "contract_copy.yml")

  yaml::write_yaml(
    x = purrr::list_assign(
      list_record_base,
      vegvault_commit = rlang::zap()
    ),
    file = path_record
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "vegvault_commit"
  )

  yaml::write_yaml(
    x = purrr::list_assign(
      list_record_base,
      vegvault_commit = "abc123"
    ),
    file = path_record
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "vegvault_commit"
  )

  yaml::write_yaml(
    x = purrr::list_assign(
      list_record_base,
      extra_field = "x"
    ),
    file = path_record
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "extra_field"
  )

  yaml::write_yaml(
    x = purrr::list_assign(
      list_record_base,
      files = base::list()
    ),
    file = path_record
  )

  testthat::expect_error(
    load_contract_copy_record(path_producer = dir_producer),
    regexp = "files"
  )
})

testthat::test_that("load_contract_copy_record() checks every file entry", {
  dir_producer <-
    withr::local_tempdir()

  base::dir.create(
    base::file.path(dir_producer, "Data", "Contracts"),
    recursive = TRUE
  )

  list_record_bad <-
    purrr::list_assign(
      list_record_base,
      files = base::list(
        base::list(
          path = "R/Functions/Contracts/load_example_contract.R",
          sha256 = "not_a_checksum"
        ),
        base::list(
          path = "../outside.R",
          sha256 = base::strrep("c", 64L)
        ),
        base::list(
          path = "Data/Contracts/fixtures/example.yml",
          sha256 = base::strrep("d", 64L),
          contract_id = "example",
          contract_version = "1.0.0"
        ),
        base::list(
          path = "Data/Contracts/splot_plots.yml",
          sha256 = base::strrep("e", 64L),
          contract_id = "bien_plots",
          contract_version = "1.0.0"
        ),
        base::list(
          path = "Data/Contracts/hwsd_soil.yml",
          sha256 = base::strrep("f", 64L),
          contract_id = "hwsd_soil"
        ),
        base::list(
          path = "R/Functions/Contracts/load_example_contract.R",
          sha256 = base::strrep("a", 64L)
        )
      )
    )

  yaml::write_yaml(
    x = list_record_bad,
    file = base::file.path(
      dir_producer, "Data", "Contracts", "contract_copy.yml"
    )
  )

  # Every problem is reported at once
  res_error <-
    testthat::expect_error(
      load_contract_copy_record(path_producer = dir_producer)
    )

  text_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(text_message, "sha256")

  testthat::expect_match(text_message, "outside.R", fixed = TRUE)

  testthat::expect_match(
    text_message,
    "fixtures/example.yml",
    fixed = TRUE
  )

  testthat::expect_match(text_message, "contract_id")

  testthat::expect_match(text_message, "contract_version")

  testthat::expect_match(text_message, "twice")
})
