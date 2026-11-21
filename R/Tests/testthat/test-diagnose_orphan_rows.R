#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_orphan_rows() reports the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_orphan_rows(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_true(base::all(dplyr::pull(res, check_id) == "orphans"))

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "datasets_without_samples", "samples_without_dataset",
      "positions_without_samples", "gridpoints_with_position",
      "links_to_other_samples", "linked_gridpoints_without_values",
      "taxa_without_use", "abiotic_variables_without_values"
    )
  )

  # Taxon 7 (Indet.) is used by no sample, trait value or classification
  testthat::expect_equal(
    dplyr::pull(res, status),
    c(base::rep("pass", 6L), "flag", "pass")
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c(base::rep("0", 6L), "1", "0")
  )

  testthat::expect_true(base::all(dplyr::pull(res, threshold) == "0"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_orphan_rows() fails and flags each scope", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # One defect per scope; sample 3 is gridpoint gridpoint_cz_1 and sample 6
  #   the BIEN plot
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (10, 'empty')"
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO Samples (sample_id, sample_name) VALUES (12, 'lonely')"
      )
      DBI::dbExecute(.x, "INSERT INTO Positions VALUES (3, 10, 10, 0)")
      DBI::dbExecute(.x, "INSERT INTO SamplePosition VALUES (3, 1)")
      DBI::dbExecute(.x, "INSERT INTO PositionLink VALUES (1, 6, 5, 0)")
      DBI::dbExecute(.x, "DELETE FROM AbioticData WHERE sample_id = 3")
      DBI::dbExecute(
        .x,
        "INSERT INTO AbioticVariable VALUES (3, 'bio4', 'C/100', '')"
      )
    }
  )

  res <-
    diagnose_orphan_rows(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c(base::rep("fail", 5L), base::rep("flag", 3L))
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("1", "1", "1", "1", "1", "1", "1", "1")
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_orphan_rows() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_orphan_rows(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
