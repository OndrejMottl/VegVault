#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_fossilpol_relations() passes the fixtures", {
  vec_paths_assembly <-
    base::list.files(
      path = here::here(
        "Data", "Contracts", "fixtures", "valid", "fossilpol_assembly"
      ),
      full.names = TRUE
    )

  vec_paths_age <-
    base::list.files(
      path = here::here(
        "Data", "Contracts", "fixtures", "valid", "fossilpol_age_uncertainty"
      ),
      full.names = TRUE
    )

  list_assembly <-
    purrr::map(.x = vec_paths_assembly, .f = qs2::qs_read) |>
    rlang::set_names(base::basename(vec_paths_assembly))

  list_age <-
    purrr::map(.x = vec_paths_age, .f = qs2::qs_read) |>
    rlang::set_names(base::basename(vec_paths_age))

  res <-
    validate_fossilpol_relations(
      list_assembly = list_assembly,
      list_age_uncertainty = list_age
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("relation", "n_datasets"))

  testthat::expect_equal(base::nrow(res), 3L)

  testthat::expect_equal(dplyr::pull(res, n_datasets), c(2L, 2L, 2L))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_fossilpol_relations() needs equal datasets", {
  list_assembly <-
    list(
      a.qs = tibble::tibble(
        dataset_id = c(1, 2),
        levels = list(
          tibble::tibble(sample_id = c("1_1", "1_2")),
          tibble::tibble(sample_id = "2_1")
        ),
        counts_harmonised = list(
          tibble::tibble(sample_id = c("1_1", "1_2")),
          tibble::tibble(sample_id = "2_1")
        )
      )
    )

  # Dataset 3 is not in the assembly; dataset 2 has no iterations
  list_age <-
    list(
      A.qs = tibble::tibble(
        dataset_id = c(1, 3),
        age_uncertainty = list(
          base::matrix(
            0,
            nrow = 2,
            ncol = 2,
            dimnames = list(NULL, c("1_2", "1_1"))
          ),
          base::matrix(0, nrow = 2, ncol = 1, dimnames = list(NULL, "3_1"))
        )
      )
    )

  res_error <-
    testthat::expect_error(
      validate_fossilpol_relations(
        list_assembly = list_assembly,
        list_age_uncertainty = list_age
      ),
      regexp = "FOSSILPOL"
    )

  vec_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(vec_message, "not\\s+in\\s+the\\s+assembly:\\s+3")

  testthat::expect_match(vec_message, "no\\s+age-uncertainty\\s+row:\\s+2")
})

testthat::test_that("validate_fossilpol_relations() compares sample IDs", {
  # Dataset 1: the iterations miss a sample; dataset 2: the counts do
  list_assembly <-
    list(
      a.qs = tibble::tibble(
        dataset_id = c(1, 2),
        levels = list(
          tibble::tibble(sample_id = c("1_1", "1_2")),
          tibble::tibble(sample_id = c("2_1", "2_2"))
        ),
        counts_harmonised = list(
          tibble::tibble(sample_id = c("1_2", "1_1")),
          tibble::tibble(sample_id = "2_1")
        )
      )
    )

  list_age <-
    list(
      A.qs = tibble::tibble(
        dataset_id = 1,
        age_uncertainty = list(
          base::matrix(0, nrow = 2, ncol = 1, dimnames = list(NULL, "1_1"))
        )
      ),
      B.qs = tibble::tibble(
        dataset_id = 2,
        age_uncertainty = list(
          base::matrix(
            0,
            nrow = 2,
            ncol = 2,
            dimnames = list(NULL, c("2_1", "2_2"))
          )
        )
      )
    )

  res_error <-
    testthat::expect_error(
      validate_fossilpol_relations(
        list_assembly = list_assembly,
        list_age_uncertainty = list_age
      ),
      regexp = "FOSSILPOL"
    )

  vec_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(vec_message, "samples\\s+of\\s+its\\s+levels:\\s+1")

  testthat::expect_match(vec_message, "levels\\s+and\\s+counts:\\s+2")

  testthat::expect_no_match(vec_message, "assembly:")
})

testthat::test_that("validate_fossilpol_relations() lists five IDs", {
  vec_ids <-
    base::seq_len(7L)

  list_assembly <-
    list(
      a.qs = tibble::tibble(
        dataset_id = 100,
        levels = list(tibble::tibble(sample_id = "100_1")),
        counts_harmonised = list(tibble::tibble(sample_id = "100_1"))
      )
    )

  list_age <-
    list(
      A.qs = tibble::tibble(
        dataset_id = c(100, vec_ids),
        age_uncertainty = purrr::map(
          .x = c(100, vec_ids),
          .f = ~ base::matrix(
            0,
            nrow = 1,
            ncol = 1,
            dimnames = list(NULL, stringr::str_c(.x, "_1"))
          )
        )
      )
    )

  res_error <-
    testthat::expect_error(
      validate_fossilpol_relations(
        list_assembly = list_assembly,
        list_age_uncertainty = list_age
      ),
      regexp = "7\\s+age-uncertainty\\s+datasets"
    )

  testthat::expect_match(base::conditionMessage(res_error), "1, 2, 3, 4, 5")

  testthat::expect_no_match(base::conditionMessage(res_error), "\\b6\\b")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_fossilpol_relations() validates its input", {
  testthat::expect_error(
    validate_fossilpol_relations(
      list_assembly = tibble::tibble(dataset_id = 1),
      list_age_uncertainty = list()
    ),
    regexp = "list_assembly"
  )

  testthat::expect_error(
    validate_fossilpol_relations(
      list_assembly = list(a.qs = tibble::tibble(dataset_id = 1)),
      list_age_uncertainty = list(A.qs = tibble::tibble(dataset_id = 1))
    ),
    regexp = "levels"
  )
})

testthat::test_that("validate_fossilpol_relations() needs unique datasets", {
  list_assembly <-
    list(
      a.qs = tibble::tibble(
        dataset_id = 1,
        levels = list(tibble::tibble(sample_id = "1_1")),
        counts_harmonised = list(tibble::tibble(sample_id = "1_1"))
      )
    )

  data_age <-
    tibble::tibble(
      dataset_id = 1,
      age_uncertainty = list(
        base::matrix(0, nrow = 1, ncol = 1, dimnames = list(NULL, "1_1"))
      )
    )

  # The same dataset in two partitions
  testthat::expect_error(
    validate_fossilpol_relations(
      list_assembly = list_assembly,
      list_age_uncertainty = list(A.qs = data_age, B.qs = data_age)
    ),
    regexp = "repeated\\s+in\\s+the\\s+age\\s+uncertainty:\\s+1"
  )

  testthat::expect_error(
    validate_fossilpol_relations(
      list_assembly = list(
        a.qs = purrr::chuck(list_assembly, "a.qs"),
        b.qs = purrr::chuck(list_assembly, "a.qs")
      ),
      list_age_uncertainty = list(A.qs = data_age)
    ),
    regexp = "repeated\\s+in\\s+the\\s+assembly:\\s+1"
  )
})
