#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_positions() validates list_data", {
  data_assembly <-
    tibble::tibble(
      long = 14,
      lat = 50,
      levels = list(tibble::tibble(sample_id = "1", age = 100))
    )

  testthat::expect_error(
    prepare_fossilpol_positions(list_data = data_assembly),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_fossilpol_positions(list_data = list()),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_fossilpol_positions(list_data = list(1)),
    regexp = "list_data"
  )

  testthat::expect_error(
    prepare_fossilpol_positions(
      list_data = list(dplyr::select(data_assembly, -long))
    ),
    regexp = "long"
  )

  testthat::expect_error(
    prepare_fossilpol_positions(
      list_data = list(dplyr::mutate(data_assembly, levels = "a"))
    ),
    regexp = "levels"
  )
})

testthat::test_that("prepare_fossilpol_positions() validates the levels", {
  data_no_age <-
    tibble::tibble(
      long = 14,
      lat = 50,
      levels = list(tibble::tibble(sample_id = "1"))
    )

  data_text_age <-
    tibble::tibble(
      long = 14,
      lat = 50,
      levels = list(tibble::tibble(sample_id = "1", age = "100"))
    )

  testthat::expect_error(
    prepare_fossilpol_positions(list_data = list(data_no_age)),
    regexp = "age"
  )

  testthat::expect_error(
    prepare_fossilpol_positions(list_data = list(data_text_age)),
    regexp = "age"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_positions() returns positions", {
  res <-
    prepare_fossilpol_positions(
      list_data = list(
        tibble::tibble(
          dataset_id = "1",
          long = 14L,
          lat = 50,
          levels = list(tibble::tibble(sample_id = "1", age = 100L))
        )
      )
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("coord_long", "coord_lat", "age"))
  testthat::expect_type(dplyr::pull(res, coord_long), "double")
  testthat::expect_type(dplyr::pull(res, coord_lat), "double")
  testthat::expect_type(dplyr::pull(res, age), "double")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_positions() crosses sites and ages", {
  list_data <-
    list(
      file_1 = tibble::tibble(
        dataset_id = c("1", "2"),
        long = c(14.5, 14.5),
        lat = c(50.25, 50.25),
        levels = list(
          tibble::tibble(
            sample_id = c("a", "b", "c"),
            age = c(100.5, -73, 100.5),
            depth = c(1, 2, 3)
          ),
          tibble::tibble(sample_id = c("a", "b"), age = c(-73, 8000))
        )
      ),
      file_2 = tibble::tibble(
        dataset_id = c("3", "4"),
        long = c(-179.94, 10),
        lat = c(-54.87, 40),
        levels = list(
          tibble::tibble(sample_id = "x", age = 19997),
          tibble::tibble(
            sample_id = base::character(),
            age = base::numeric()
          )
        )
      )
    )

  res <-
    prepare_fossilpol_positions(list_data = list_data) |>
    dplyr::arrange(coord_long, coord_lat, age)

  data_expected <-
    tibble::tibble(
      coord_long = c(-179.94, 14.5, 14.5, 14.5),
      coord_lat = c(-54.87, 50.25, 50.25, 50.25),
      age = c(19997, -73, 100.5, 8000)
    )

  testthat::expect_equal(res, data_expected)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_fossilpol_positions() keeps missing values", {
  res <-
    prepare_fossilpol_positions(
      list_data = list(
        tibble::tibble(
          long = c(NA, 14),
          lat = c(50, 50),
          levels = list(
            tibble::tibble(sample_id = "a", age = 100),
            tibble::tibble(sample_id = "b", age = NA_real_)
          )
        )
      )
    ) |>
    dplyr::arrange(coord_long)

  data_expected <-
    tibble::tibble(
      coord_long = c(14, NA),
      coord_lat = c(50, 50),
      age = c(NA, 100)
    )

  testthat::expect_equal(res, data_expected)
})
