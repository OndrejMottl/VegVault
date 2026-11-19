#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_occurrences() bins the records", {
  data_raw <-
    tibble::tibble(
      dataset_id = c(6L, 7L, 7L, 7L, 8L, 8L, 9L),
      dataset_type = c(
        "vegetation_plot", "fossil_pollen_archive", "fossil_pollen_archive",
        "fossil_pollen_archive", "fossil_pollen_archive",
        "fossil_pollen_archive", "traits"
      ),
      coord_long = c(-100, -90, -90, -90, -70, -70, -65),
      coord_lat = c(45, 50, 50, 50, -20, -20, -15),
      age = c(0, 1000, 1000, 6000, 2600, 2600, NA),
      taxon_name = c(
        "Picea", "Picea", "Picea", "Picea", "Picea", "Quercus", NA
      ),
      value = c(4, 10, 10, 0, 1, 5, NA)
    )

  res <-
    prepare_taxon_occurrences(
      data_taxon_occurrences_raw = data_raw,
      taxon_name = "Picea",
      age_bin_width = 2500,
      age_min = 0,
      age_max = 12000
    )

  testthat::expect_s3_class(res, "tbl_df")

  vec_levels <-
    c(
      "contemporary",
      "paleo: 0 ka cal yr BP",
      "paleo: 2.5 ka cal yr BP",
      "paleo: 5 ka cal yr BP",
      "paleo: 7.5 ka cal yr BP",
      "paleo: 10 ka cal yr BP"
    )

  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_id = c(6L, 7L, 8L),
      dataset_type = c(
        "vegetation plot", "fossil pollen archive", "fossil pollen archive"
      ),
      coord_long = c(-100, -90, -70),
      coord_lat = c(45, 50, -20),
      age = c(0, 1000, 2600),
      age_bin_class = base::factor(
        c(
          "contemporary", "paleo: 0 ka cal yr BP", "paleo: 2.5 ka cal yr BP"
        ),
        levels = vec_levels
      )
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_occurrences() derives bins from ages", {
  data_raw <-
    tibble::tibble(
      dataset_id = 7L,
      dataset_type = "fossil_pollen_archive",
      coord_long = -90,
      coord_lat = 50,
      age = 7100,
      taxon_name = "Picea",
      value = 1
    )

  res <-
    prepare_taxon_occurrences(
      data_taxon_occurrences_raw = data_raw,
      taxon_name = "Picea",
      age_bin_width = 1000,
      age_min = 6000,
      age_max = 8000
    )

  testthat::expect_equal(
    base::levels(dplyr::pull(res, age_bin_class)),
    c(
      "contemporary", "paleo: 6 ka cal yr BP", "paleo: 7 ka cal yr BP",
      "paleo: 8 ka cal yr BP"
    )
  )

  testthat::expect_equal(
    base::as.character(dplyr::pull(res, age_bin_class)),
    "paleo: 7 ka cal yr BP"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_occurrences() validates its arguments", {
  data_raw <-
    tibble::tibble(
      dataset_id = 7L,
      dataset_type = "fossil_pollen_archive",
      coord_long = -90,
      coord_lat = 50,
      age = 7100,
      taxon_name = "Picea",
      value = 1
    )

  testthat::expect_error(
    prepare_taxon_occurrences(
      data_taxon_occurrences_raw = dplyr::select(data_raw, -value),
      taxon_name = "Picea",
      age_bin_width = 2500,
      age_min = 0,
      age_max = 12000
    ),
    regexp = "value"
  )

  testthat::expect_error(
    prepare_taxon_occurrences(
      data_taxon_occurrences_raw = data_raw,
      taxon_name = "Picea",
      age_bin_width = 0,
      age_min = 0,
      age_max = 12000
    ),
    regexp = "age_bin_width"
  )

  testthat::expect_error(
    prepare_taxon_occurrences(
      data_taxon_occurrences_raw = data_raw,
      taxon_name = "Picea",
      age_bin_width = 2500,
      age_min = 12000,
      age_max = 0
    ),
    regexp = "age_min"
  )
})
