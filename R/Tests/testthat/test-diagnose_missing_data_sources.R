#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_data_sources() passes named sources", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # The fixture gives no dataset a data source; here every one gets one
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO DatasetSourcesID (data_source_id, data_source_desc)",
          "VALUES (1, 'Provider A')"
        )
      )
      DBI::dbExecute(.x, "UPDATE Datasets SET data_source_id = 1")
    }
  )

  res <-
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "missing_data_sources")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "fossil_pollen_archive / FOSSILPOL", "gridpoints / gridpoints",
      "traits / TRY", "vegetation_plot / BIEN", "vegetation_plot / sPlotOpen"
    )
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))

  testthat::expect_true(base::all(dplyr::pull(res, observed) == "0"))

  testthat::expect_true(base::all(dplyr::pull(res, threshold) == "0"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_data_sources() flags each group", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # As built, the fixture gives no dataset a data source
  res <-
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "flag"))

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("2", "3", "1", "1", "2")
  )

  testthat::expect_true(base::all(dplyr::pull(res, threshold) == "0"))
})

testthat::test_that("diagnose_missing_data_sources() counts unnamed sources", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # One sPlotOpen dataset points to a source without a description, one
  #   FOSSILPOL dataset to a source with a blank one
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO DatasetSourcesID (data_source_id, data_source_desc)",
          "VALUES (1, 'Provider A'), (2, NULL), (3, '  ')"
        )
      )
      DBI::dbExecute(.x, "UPDATE Datasets SET data_source_id = 1")
      DBI::dbExecute(
        .x,
        "UPDATE Datasets SET data_source_id = 2 WHERE dataset_id = 1"
      )
      DBI::dbExecute(
        .x,
        "UPDATE Datasets SET data_source_id = 3 WHERE dataset_id = 7"
      )
    }
  )

  res <-
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  data_flagged <-
    dplyr::filter(res, status == "flag")

  testthat::expect_equal(
    dplyr::pull(data_flagged, scope),
    c("fossil_pollen_archive / FOSSILPOL", "vegetation_plot / sPlotOpen")
  )

  testthat::expect_equal(dplyr::pull(data_flagged, observed), c("1", "1"))

  testthat::expect_equal(base::nrow(res), 5L)
})

testthat::test_that("diagnose_missing_data_sources() applies accepted counts", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Two of the three gridpoint datasets and both sPlotOpen datasets
  #   without a data source
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO DatasetSourcesID (data_source_id, data_source_desc)",
          "VALUES (1, 'Provider A')"
        )
      )
      DBI::dbExecute(
        .x,
        base::paste(
          "UPDATE Datasets SET data_source_id = 1",
          "WHERE dataset_id NOT IN (1, 2, 3, 4)"
        )
      )
    }
  )

  res <-
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_accepted = base::list(
        base::list(
          scope = "gridpoints / gridpoints",
          n_datasets = 2L,
          reason = "Reason of the gridpoints."
        ),
        base::list(
          scope = "vegetation_plot / sPlotOpen",
          n_datasets = 1L,
          reason = "Reason of the plots."
        ),
        base::list(
          scope = "traits / BIEN",
          n_datasets = 5L,
          reason = "Not in the database."
        )
      )
    )

  data_gridpoints <-
    dplyr::filter(res, scope == "gridpoints / gridpoints")

  data_plots <-
    dplyr::filter(res, scope == "vegetation_plot / sPlotOpen")

  testthat::expect_equal(dplyr::pull(data_gridpoints, status), "pass")

  testthat::expect_equal(dplyr::pull(data_gridpoints, observed), "2")

  testthat::expect_equal(dplyr::pull(data_gridpoints, threshold), "2")

  testthat::expect_match(
    dplyr::pull(data_gridpoints, message),
    "Reason of the gridpoints.",
    fixed = TRUE
  )

  testthat::expect_equal(dplyr::pull(data_plots, status), "flag")

  testthat::expect_equal(dplyr::pull(data_plots, observed), "2")

  testthat::expect_equal(dplyr::pull(data_plots, threshold), "1")

  testthat::expect_match(
    dplyr::pull(data_plots, message),
    "Reason of the plots.",
    fixed = TRUE
  )

  # An accepted scope that is not in the database gives no row
  testthat::expect_equal(base::nrow(res), 5L)

  testthat::expect_equal(
    base::sum(dplyr::pull(res, status) == "pass"),
    4L
  )
})

testthat::test_that("diagnose_missing_data_sources() reports missing types", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (10, 'x')"
      )
    }
  )

  res <-
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, scope)[1],
    "(none) / (none)"
  )

  testthat::expect_equal(dplyr::pull(res, observed)[1], "1")

  testthat::expect_equal(base::nrow(res), 6L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_data_sources() refuses another file", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_missing_data_sources(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})

testthat::test_that("diagnose_missing_data_sources() checks list_accepted", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  list_entry <-
    base::list(
      scope = "traits / TRY",
      n_datasets = 1L,
      reason = "A reason."
    )

  list_malformed <-
    base::list(
      not_a_list = "traits / TRY",
      no_reason = base::list(
        base::list(scope = "traits / TRY", n_datasets = 1L)
      ),
      zero_count = base::list(
        purrr::list_modify(list_entry, n_datasets = 0L)
      ),
      fractional_count = base::list(
        purrr::list_modify(list_entry, n_datasets = 2.5)
      ),
      missing_count = base::list(
        purrr::list_modify(list_entry, n_datasets = NA_integer_)
      ),
      empty_scope = base::list(
        purrr::list_modify(list_entry, scope = "")
      ),
      empty_reason = base::list(
        purrr::list_modify(list_entry, reason = "")
      ),
      repeated_scope = base::list(list_entry, list_entry)
    )

  purrr::walk(
    .x = list_malformed,
    .f = ~ testthat::expect_error(
      diagnose_missing_data_sources(
        path_database = purrr::chuck(list_build, "path_database"),
        list_build_manifest = purrr::chuck(
          list_build,
          "list_build_manifest"
        ),
        list_accepted = .x
      ),
      regexp = "list_accepted"
    )
  )
})
