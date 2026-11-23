#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("filter_producer_artefact() keeps data without subset", {
  list_artefact <-
    list(
      a.qs = tibble::tibble(longitude = c(5, 20), latitude = c(45, 45))
    )

  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    )

  testthat::expect_identical(res, list_artefact)
})

testthat::test_that("filter_producer_artefact() cuts by coordinates", {
  list_artefact <-
    list(
      a.qs = tibble::tibble(
        longitude = c(5, 11, 20, NA),
        latitude = c(45, 45, 45, 45),
        id = 1:4
      ),
      b.qs = tibble::tibble(longitude = 1, latitude = 60, id = 5L)
    )

  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(
        enabled = TRUE,
        lon_min = 0,
        lon_max = 10,
        lat_min = 40,
        lat_max = 50,
        margin_lon = 2,
        margin_lat = 1
      ),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    )

  testthat::expect_named(res, c("a.qs", "b.qs"))

  testthat::expect_equal(dplyr::pull(purrr::chuck(res, "a.qs"), id), 1L)

  testthat::expect_equal(base::nrow(purrr::chuck(res, "b.qs")), 0L)

  testthat::expect_named(
    purrr::chuck(res, "b.qs"),
    c("longitude", "latitude", "id")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("filter_producer_artefact() widens the box for grids", {
  list_artefact <-
    list(
      a.qs = tibble::tibble(
        long = c(11, 12.5, -2),
        lat = c(50.5, 45, 51)
      )
    )

  # Box 0 to 10 and 40 to 50, widened to -2 to 12 and 39 to 51
  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(
        enabled = TRUE,
        lon_min = 0,
        lon_max = 10,
        lat_min = 40,
        lat_max = 50,
        margin_lon = 2,
        margin_lat = 1
      ),
      list_subset_filter = list(
        col_lon = "long",
        col_lat = "lat",
        flag_margin = TRUE
      )
    )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "a.qs"), long),
    c(11, -2)
  )
})

testthat::test_that("filter_producer_artefact() keeps the reference keys", {
  # A missing key is never kept, even when the reference has one
  list_artefact <-
    list(
      a.qs = tibble::tibble(dataset_id = c(1, 2, 3, NA)),
      b.qs = tibble::tibble(dataset_id = 4)
    )

  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(
        enabled = TRUE,
        lon_min = 0,
        lon_max = 10,
        lat_min = 40,
        lat_max = 50,
        margin_lon = 2,
        margin_lat = 1
      ),
      list_subset_filter = list(
        col_key = "dataset_id",
        reference = "fossilpol_assembly"
      ),
      vec_keys_kept = c(1, 3, NA)
    )

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "a.qs"), dataset_id),
    c(1, 3)
  )

  testthat::expect_equal(base::nrow(purrr::chuck(res, "b.qs")), 0L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("filter_producer_artefact() checks the filter rule", {
  list_artefact <-
    list(a.qs = tibble::tibble(longitude = 5, latitude = 45))

  # Checked also without a subset
  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(col_lon = "longitude", flag_margin = FALSE)
    ),
    regexp = "list_subset_filter"
  )

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = "yes"
      )
    ),
    regexp = "list_subset_filter"
  )

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE,
        col_key = "dataset_id"
      )
    ),
    regexp = "list_subset_filter"
  )
})

testthat::test_that("filter_producer_artefact() validates its data", {
  list_subset_box <-
    list(
      enabled = TRUE,
      lon_min = 0,
      lon_max = 10,
      lat_min = 40,
      lat_max = 50,
      margin_lon = 2,
      margin_lat = 1
    )

  # A filter by key needs the keys of the reference artefact
  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list(a.qs = tibble::tibble(dataset_id = 1)),
      list_subset = list_subset_box,
      list_subset_filter = list(
        col_key = "dataset_id",
        reference = "fossilpol_assembly"
      )
    ),
    regexp = "vec_keys_kept"
  )

  # The margins of gridded data must be in the subset section
  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list(a.qs = tibble::tibble(long = 5, lat = 45)),
      list_subset = purrr::list_modify(list_subset_box, margin_lon = NULL),
      list_subset_filter = list(
        col_lon = "long",
        col_lat = "lat",
        flag_margin = TRUE
      )
    ),
    regexp = "margin_lon"
  )

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list(tibble::tibble(longitude = 5, latitude = 45)),
      list_subset = list_subset_box,
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    ),
    regexp = "list_artefact"
  )

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list(a.qs = tibble::tibble(longitude = 5, latitude = 45)),
      list_subset = list(lon_min = 0),
      list_subset_filter = list(
        col_lon = "longitude",
        col_lat = "latitude",
        flag_margin = FALSE
      )
    ),
    regexp = "enabled"
  )
})

testthat::test_that("filter_producer_artefact() keeps every row on request", {
  # A rule table has no coordinates and holds for every region
  list_artefact <-
    list(
      unit_conversions.csv = tibble::tibble(
        conversion_rule_key = c("rule_a", "rule_b"),
        multiplier = c(1, 100)
      )
    )

  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(
        enabled = TRUE,
        lon_min = 0,
        lon_max = 10,
        lat_min = 40,
        lat_max = 50
      ),
      list_subset_filter = list(flag_keep_all = TRUE)
    )

  testthat::expect_identical(res, list_artefact)

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(flag_keep_all = FALSE)
    ),
    regexp = "list_subset_filter"
  )

  testthat::expect_error(
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list(enabled = FALSE),
      list_subset_filter = list(flag_keep_all = TRUE, col_key = "id")
    ),
    regexp = "list_subset_filter"
  )
})
