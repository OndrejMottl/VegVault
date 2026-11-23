#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_artefact_rows() adds the rows of every file", {
  # The BIEN traits fixture: three parts of one artefact
  list_artefact <-
    build_bien_traits_fixture()

  res <-
    compute_artefact_rows(list_data = list_artefact)

  testthat::expect_type(res, "double")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(
    res,
    base::sum(purrr::map_dbl(.x = list_artefact, .f = base::nrow))
  )
})

testthat::test_that("compute_artefact_rows() counts the top-level rows", {
  # A nested artefact counts its plots, not the taxa inside them
  list_artefact <-
    build_splot_plots_fixture()

  testthat::expect_equal(
    compute_artefact_rows(list_data = list_artefact),
    base::as.numeric(base::nrow(purrr::chuck(list_artefact, 1)))
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_artefact_rows() counts empty tables as 0", {
  # A subset cut can leave a file without rows
  testthat::expect_equal(
    compute_artefact_rows(
      list_data = list(
        a.qs = tibble::tibble(x = base::numeric(0)),
        b.qs = tibble::tibble(x = 1:3)
      )
    ),
    3
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_artefact_rows() validates its argument", {
  testthat::expect_error(
    compute_artefact_rows(list_data = tibble::tibble(x = 1)),
    regexp = "list_data"
  )

  testthat::expect_error(
    compute_artefact_rows(list_data = list()),
    regexp = "list_data"
  )

  testthat::expect_error(
    compute_artefact_rows(list_data = list(a.qs = 1:3)),
    regexp = "list_data"
  )
})
