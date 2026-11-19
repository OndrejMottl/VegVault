list_columns_test <-
  base::list(
    base::list(
      name = "plot_id",
      class = "character",
      nullable = FALSE,
      description = "d",
      evidence = "e"
    ),
    base::list(
      name = "longitude",
      class = "numeric",
      nullable = FALSE,
      description = "d",
      evidence = "e",
      checks = base::list(range = base::list(min = -180, max = 180))
    ),
    base::list(
      name = "taxa",
      class = "list",
      nullable = FALSE,
      description = "d",
      evidence = "e",
      element = base::list(
        class = "data.frame",
        nullable = FALSE,
        columns = base::list(
          base::list(
            name = "taxon",
            class = "character",
            nullable = FALSE,
            description = "d",
            evidence = "e"
          )
        )
      )
    )
  )

data_valid <-
  tibble::tibble(
    plot_id = c("a", "b"),
    longitude = c(10, -170),
    taxa = base::list(
      tibble::tibble(taxon = "x"),
      tibble::tibble(taxon = c("y", "z"))
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_columns() passes valid data", {
  res <-
    diagnose_producer_columns(
      data_source = data_valid,
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots",
      file_name = "a.qs"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_columns() flags missing columns", {
  res <-
    diagnose_producer_columns(
      data_source = dplyr::select(data_valid, -"longitude"),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots",
      file_name = "a.qs"
    )

  testthat::expect_equal(dplyr::pull(res, check), "column_missing")

  testthat::expect_equal(dplyr::pull(res, column), "longitude")

  testthat::expect_equal(dplyr::pull(res, file_name), "a.qs")
})

testthat::test_that("diagnose_producer_columns() flags classes, not values", {
  res <-
    diagnose_producer_columns(
      data_source = dplyr::mutate(data_valid, longitude = c("10", "999")),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(dplyr::pull(res, check), "class_mismatch")

  testthat::expect_equal(dplyr::pull(res, column), "longitude")
})

testthat::test_that("diagnose_producer_columns() checks values", {
  res <-
    diagnose_producer_columns(
      data_source = dplyr::mutate(
        data_valid,
        longitude = c(10, 999),
        plot_id = c("a", NA)
      ),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("value_out_of_range", "value_missing")
  )

  testthat::expect_setequal(
    dplyr::pull(res, column),
    c("longitude", "plot_id")
  )
})

testthat::test_that("diagnose_producer_columns() handles extra columns", {
  data_extra <-
    dplyr::mutate(data_valid, elevation = 1)

  res_allow <-
    diagnose_producer_columns(
      data_source = data_extra,
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(base::nrow(res_allow), 0L)

  res_error <-
    diagnose_producer_columns(
      data_source = data_extra,
      list_columns = list_columns_test,
      extra_columns = "error",
      contract_id = "test_plots"
    )

  testthat::expect_equal(dplyr::pull(res_error, check), "column_extra")

  testthat::expect_equal(dplyr::pull(res_error, column), "elevation")
})

testthat::test_that("diagnose_producer_columns() checks list-columns", {
  res <-
    diagnose_producer_columns(
      data_source = dplyr::mutate(
        data_valid,
        taxa = base::list(
          tibble::tibble(taxon = "x"),
          tibble::tibble(name = "y")
        )
      ),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(dplyr::pull(res, check), "column_missing")

  testthat::expect_equal(dplyr::pull(res, column), "taxa[].taxon")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_columns() validates arguments", {
  testthat::expect_error(
    diagnose_producer_columns(
      data_source = base::list(a = 1),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "c"
    ),
    regexp = "data_source"
  )

  testthat::expect_error(
    diagnose_producer_columns(
      data_source = data_valid,
      list_columns = list_columns_test,
      extra_columns = "warn",
      contract_id = "c"
    ),
    regexp = "extra_columns"
  )
})


#----------------------------------------------------------#
# All-missing columns and duplicated names -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_columns() accepts all-NA nullables", {
  list_columns_doi <-
    c(
      list_columns_test,
      base::list(
        base::list(
          name = "doi",
          class = "character",
          nullable = TRUE,
          description = "d",
          evidence = "e"
        )
      )
    )

  res <-
    diagnose_producer_columns(
      data_source = dplyr::mutate(data_valid, doi = NA),
      list_columns = list_columns_doi,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(base::nrow(res), 0L)

  res_required <-
    diagnose_producer_columns(
      data_source = dplyr::mutate(data_valid, plot_id = NA),
      list_columns = list_columns_test,
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(dplyr::pull(res_required, check), "class_mismatch")
})

testthat::test_that("diagnose_producer_columns() flags duplicated names", {
  data_duplicated <-
    base::data.frame(
      plot_id = c("a", "b"),
      longitude = c(1, 2),
      longitude = c(3, 4),
      check.names = FALSE
    )

  res <-
    diagnose_producer_columns(
      data_source = data_duplicated,
      list_columns = list_columns_test[1:2],
      extra_columns = "allow",
      contract_id = "test_plots"
    )

  testthat::expect_equal(dplyr::pull(res, check), "column_duplicate")

  testthat::expect_equal(dplyr::pull(res, column), "longitude")
})
