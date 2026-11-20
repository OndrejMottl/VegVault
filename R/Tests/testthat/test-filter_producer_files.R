#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("filter_producer_files() keeps the files of a variable", {
  vec_paths <-
    base::list.files(
      path = here::here(
        "Data", "Contracts", "fixtures", "valid",
        "chelsa_trace21k_palaeoclimate"
      ),
      full.names = TRUE
    )

  data_files <-
    tibble::tibble(
      artefact_id = "chelsa_trace21k_palaeoclimate",
      file_name = base::basename(vec_paths),
      path = vec_paths,
      format = "qs2"
    )

  res <-
    filter_producer_files(
      data_files = data_files,
      path_contract = here::here(
        "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
      ),
      variable = "bio12"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("artefact_id", "file_name", "path", "format"))

  # Three batches of bio12, in the order of `data_files`
  testthat::expect_equal(
    dplyr::pull(res, file_name),
    stringr::str_subset(dplyr::pull(data_files, file_name), "^bio12_batch_")
  )

  testthat::expect_equal(base::nrow(res), 3L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("filter_producer_files() checks the variable", {
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

  testthat::expect_error(
    filter_producer_files(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      variable = "bio2"
    ),
    regexp = "bio2"
  )

  testthat::expect_error(
    filter_producer_files(
      data_files = data_files,
      path_contract = here::here("Data", "Contracts", "wosis_soil.yml"),
      variable = "bio1"
    ),
    regexp = "no\\s+variables"
  )

  # A variable of the contract without a resolved file
  testthat::expect_error(
    filter_producer_files(
      data_files = dplyr::filter(
        data_files,
        !stringr::str_detect(file_name, "_bio_04_")
      ),
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      variable = "bio4"
    ),
    regexp = "no\\s+file"
  )

  testthat::expect_error(
    filter_producer_files(
      data_files = dplyr::select(data_files, -file_name),
      path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
      variable = "bio4"
    ),
    regexp = "file_name"
  )
})
