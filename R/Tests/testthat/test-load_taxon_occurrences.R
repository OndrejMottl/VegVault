#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_taxon_occurrences() returns the genus records", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_taxon_occurrences(
      path_database = path_database,
      list_region = list(
        lon_min = -135, lon_max = -60, lat_min = 22, lat_max = 60
      ),
      age_min = 0,
      age_max = 12000,
      taxon_name = "Picea",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  data_sorted <-
    dplyr::arrange(res, sample_id)

  # Plot 6 holds Picea abies, classified to Picea; fossil sample 7 holds
  #   Picea; fossil sample 8 holds only Quercus
  testthat::expect_equal(dplyr::pull(data_sorted, sample_id), c(6L, 7L))

  testthat::expect_equal(
    base::unique(dplyr::pull(data_sorted, taxon_name)),
    "Picea"
  )

  testthat::expect_equal(dplyr::pull(data_sorted, value), c(4, 10))
})


#----------------------------------------------------------#
# Messages and side effects -----
#----------------------------------------------------------#

testthat::test_that("load_taxon_occurrences() silences the expected note", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_no_warning(
    res <-
      load_taxon_occurrences(
        path_database = path_database,
        list_region = list(
          lon_min = -135, lon_max = -60, lat_min = 22, lat_max = 60
        ),
        age_min = 0,
        age_max = 12000,
        taxon_name = "Picea",
        list_build_manifest = list(database = list(file_name = "f.sqlite"))
      )
  )

  testthat::expect_gt(base::nrow(res), 0L)

  # Windows cannot delete a file that a connection still holds
  base::unlink(path_database)

  testthat::expect_false(base::file.exists(path_database))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_taxon_occurrences() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_region <-
    list(lon_min = -135, lon_max = -60, lat_min = 22, lat_max = 60)

  list_manifest <-
    list(database = list(file_name = "f.sqlite"))

  testthat::expect_error(
    load_taxon_occurrences(
      path_database = path_database,
      list_region = list_region,
      age_min = 12000,
      age_max = 0,
      taxon_name = "Picea",
      list_build_manifest = list_manifest
    ),
    regexp = "age_min"
  )

  testthat::expect_error(
    load_taxon_occurrences(
      path_database = path_database,
      list_region = list_region,
      age_min = 0,
      age_max = 12000,
      taxon_name = NA_character_,
      list_build_manifest = list_manifest
    ),
    regexp = "taxon_name"
  )

  testthat::expect_error(
    load_taxon_occurrences(
      path_database = path_database,
      list_region = list_region,
      age_min = 0,
      age_max = 12000,
      taxon_name = "Picea",
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
