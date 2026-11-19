#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_trait_example() returns fossil and trait rows", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_trait_example(
      path_database = path_database,
      list_region = list(
        lon_min = -110, lon_max = -38, lat_min = -53, lat_max = 28
      ),
      age_min = 6000,
      age_max = 12000,
      trait_domain_name = "Plant heigh",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  data_fossil <-
    res |>
    dplyr::filter(dataset_type == "fossil_pollen_archive")

  testthat::expect_equal(
    base::sort(base::unique(dplyr::pull(data_fossil, sample_id))),
    c(9L, 10L)
  )

  data_traits <-
    res |>
    dplyr::filter(dataset_type == "traits") |>
    dplyr::arrange(taxon_id_trait)

  # Plant height of Picea abies (30) and Quercus robur (20), classified to
  #   genera 2 and 5; the leaf area value is left out
  testthat::expect_equal(
    dplyr::pull(data_traits, taxon_id_trait),
    c(2L, 5L)
  )

  testthat::expect_equal(dplyr::pull(data_traits, trait_value), c(30, 20))
})


#----------------------------------------------------------#
# Messages and side effects -----
#----------------------------------------------------------#

testthat::test_that("load_trait_example() silences the expected note", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_no_warning(
    res <-
      load_trait_example(
        path_database = path_database,
        list_region = list(
          lon_min = -110, lon_max = -38, lat_min = -53, lat_max = 28
        ),
        age_min = 6000,
        age_max = 12000,
        trait_domain_name = "Plant heigh",
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

testthat::test_that("load_trait_example() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_region <-
    list(lon_min = -110, lon_max = -38, lat_min = -53, lat_max = 28)

  testthat::expect_error(
    load_trait_example(
      path_database = path_database,
      list_region = list_region,
      age_min = "6000",
      age_max = 12000,
      trait_domain_name = "Plant heigh",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "age_min"
  )

  testthat::expect_error(
    load_trait_example(
      path_database = path_database,
      list_region = list_region,
      age_min = 6000,
      age_max = 12000,
      trait_domain_name = c("Plant heigh", "Leaf Area"),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "trait_domain_name"
  )
})
