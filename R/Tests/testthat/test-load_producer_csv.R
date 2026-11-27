#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

contract_conversions <-
  load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "trait_unit_conversions.yml"
    )
  )

vec_lines_rules <-
  c(
    stringr::str_c(
      "conversion_rule_key,rule_version,source_provider,source_trait_id,",
      "source_dataset_key,normalized_original_unit,standardized_unit,",
      "trait_dimension,operation,multiplier,verify_source_standardized,",
      "evidence"
    ),
    "rule_a,1.0.0,TRY,3106,,cm,m,length,multiply,0.01,TRUE,Synthetic rule",
    "rule_b,1.0.0,TRY,3106,90,m,m,length,identity,1,FALSE,\"Synthetic, quoted\""
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_csv() reads the contract's classes", {
  path_file <-
    save_test_lines(
      vec_lines = vec_lines_rules,
      dir_test = withr::local_tempdir()
    )

  res <-
    load_producer_csv(
      path_file = path_file,
      contract = contract_conversions
    )

  testthat::expect_identical(
    base::class(res),
    c("tbl_df", "tbl", "data.frame")
  )

  testthat::expect_null(base::attr(res, "spec"))

  testthat::expect_equal(base::nrow(res), 2L)

  # A numeric-looking identifier stays text, as the contract says
  testthat::expect_identical(
    dplyr::pull(res, source_trait_id),
    c("3106", "3106")
  )

  testthat::expect_identical(
    dplyr::pull(res, multiplier),
    c(0.01, 1)
  )

  testthat::expect_identical(
    dplyr::pull(res, source_dataset_key),
    c(NA_character_, "90")
  )

  testthat::expect_identical(
    dplyr::pull(res, evidence),
    c("Synthetic rule", "Synthetic, quoted")
  )

  # A column the contract does not describe is read as text
  testthat::expect_identical(
    dplyr::pull(res, verify_source_standardized),
    c("TRUE", "FALSE")
  )
})

testthat::test_that("load_producer_csv() reads CRLF line ends alike", {
  dir_test <-
    withr::local_tempdir()

  res_lf <-
    load_producer_csv(
      path_file = save_test_lines(vec_lines_rules, dir_test, eol = "\n"),
      contract = contract_conversions
    )

  res_crlf <-
    load_producer_csv(
      path_file = save_test_lines(vec_lines_rules, dir_test, eol = "\r\n"),
      contract = contract_conversions
    )

  testthat::expect_identical(res_crlf, res_lf)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_producer_csv() stops at an unreadable value", {
  vec_lines_bad <-
    vec_lines_rules

  vec_lines_bad[3] <-
    stringr::str_replace(vec_lines_bad[3], ",1,FALSE,", ",one,FALSE,")

  path_file <-
    save_test_lines(
      vec_lines = vec_lines_bad,
      dir_test = withr::local_tempdir()
    )

  # The error replaces readr's own warning about the value
  testthat::expect_no_warning(
    testthat::expect_error(
      load_producer_csv(
        path_file = path_file,
        contract = contract_conversions
      ),
      regexp = "unit_conversions.csv.*multiplier.*one"
    )
  )
})

testthat::test_that("load_producer_csv() leaves missing columns to the check", {
  # The same lines without the last column, evidence
  vec_lines_short <-
    stringr::str_remove(
      vec_lines_rules,
      ",(evidence|Synthetic rule|\"Synthetic, quoted\")$"
    )

  path_file <-
    save_test_lines(
      vec_lines = vec_lines_short,
      dir_test = withr::local_tempdir()
    )

  testthat::expect_no_warning(
    res <-
      load_producer_csv(
        path_file = path_file,
        contract = contract_conversions
      )
  )

  testthat::expect_false("evidence" %in% base::names(res))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_csv() validates arguments", {
  dir_test <-
    withr::local_tempdir()

  path_file <-
    save_test_lines(vec_lines = vec_lines_rules, dir_test = dir_test)

  testthat::expect_error(
    load_producer_csv(
      path_file = base::file.path(dir_test, "missing.csv"),
      contract = contract_conversions
    ),
    regexp = "path_file"
  )

  testthat::expect_error(
    load_producer_csv(
      path_file = path_file,
      contract = base::list(contract_id = "x")
    ),
    regexp = "contract"
  )

  # A nested column cannot come from a csv file
  contract_nested <-
    purrr::assign_in(
      contract_conversions,
      where = base::list("columns", 1, "class"),
      value = "list"
    )

  testthat::expect_error(
    load_producer_csv(
      path_file = path_file,
      contract = contract_nested
    ),
    regexp = "conversion_rule_key"
  )
})
