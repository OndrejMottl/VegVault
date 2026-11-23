#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_comparison_summary() validates arguments", {
  data_summary <-
    tibble::tibble(
      unit = "samples",
      scope = "a",
      n_only_v1 = 0,
      n_only_v2 = 1
    )

  testthat::expect_error(
    diagnose_comparison_summary(
      data_summary = dplyr::select(data_summary, -n_only_v2),
      list_expected = base::list()
    ),
    regexp = "data_summary"
  )

  testthat::expect_error(
    diagnose_comparison_summary(
      data_summary = data_summary,
      list_expected = base::list(
        base::list(units = "samples", directions = "only_v2")
      )
    ),
    regexp = "reason"
  )

  testthat::expect_error(
    diagnose_comparison_summary(
      data_summary = data_summary,
      list_expected = base::list(
        base::list(units = "samples", directions = "more", reason = "Test.")
      )
    ),
    regexp = "directions"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_comparison_summary() marks each scope", {
  data_summary <-
    tibble::tibble(
      unit = c("samples", "samples", "samples", "sample_links"),
      scope = c("same", "new data", "lost rows", "links"),
      n_only_v1 = c(0, 3, 2, 0),
      n_only_v2 = c(0, 5, 0, 7)
    )

  list_expected <-
    base::list(
      base::list(
        units = "samples",
        scopes = c("new data", "lost rows"),
        directions = "only_v2",
        reason = "New producer data."
      ),
      base::list(
        units = "samples",
        scopes = "new data",
        directions = "only_v1",
        reason = "Rerun."
      ),
      base::list(
        units = "sample_links",
        directions = "only_v2",
        reason = "New links."
      )
    )

  res <-
    diagnose_comparison_summary(
      data_summary = data_summary,
      list_expected = list_expected
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("equal", "explained", "unexplained", "explained")
  )

  testthat::expect_equal(
    dplyr::pull(res, reason),
    c(NA, "New producer data.; Rerun.", "New producer data.", "New links.")
  )

  testthat::expect_equal(
    dplyr::select(res, -status, -reason),
    data_summary
  )
})

testthat::test_that("diagnose_comparison_summary() needs a reason", {
  res <-
    diagnose_comparison_summary(
      data_summary = tibble::tibble(
        unit = "taxa",
        scope = "all",
        n_only_v1 = 1,
        n_only_v2 = 0
      ),
      list_expected = base::list()
    )

  testthat::expect_equal(dplyr::pull(res, status), "unexplained")

  testthat::expect_true(base::is.na(dplyr::pull(res, reason)))
})
