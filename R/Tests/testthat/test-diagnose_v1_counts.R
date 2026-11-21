#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

data_test_deltas <-
  tibble::tribble(
    ~metric, ~scope, ~n_v1, ~n_v2, ~delta, ~relative_change, ~status,
    ~expected_reason, ~note,
    "table_rows", "Samples", 100, 104, 4, 0.04, "pass", NA, NA,
    "table_rows", "Taxa", 50, 45, -5, -0.1, "flag", NA, NA,
    "table_rows", "Positions", NA, 7, NA, NA, "flag", "New tables.", NA,
    "samples", "traits / TRY", 40, 30, -10, -0.25, "flag",
    "TRY duplicates removed.", NA,
    "samples", "traits / BIEN", 60, 60, 0, 0, "pass", NA, NA
  )

list_test_manifest <-
  base::list(subset = base::list(enabled = FALSE))


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_v1_counts() gives one row per metric", {
  res <-
    diagnose_v1_counts(
      data_deltas = data_test_deltas,
      list_build_manifest = list_test_manifest,
      tolerance = 0.05
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, scope), c("table_rows", "samples"))

  testthat::expect_true(base::all(dplyr::pull(res, check_id) == "v1_counts"))

  testthat::expect_equal(dplyr::pull(res, status), c("flag", "flag"))

  testthat::expect_equal(dplyr::pull(res, observed), c("2", "1"))

  testthat::expect_equal(dplyr::pull(res, threshold), c("0.05", "0.05"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_v1_counts() names the flagged counts", {
  res <-
    diagnose_v1_counts(
      data_deltas = data_test_deltas,
      list_build_manifest = list_test_manifest,
      tolerance = 0.05
    )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "2 of 3 counts")

  testthat::expect_match(vec_messages[1], "Taxa: 50 to 45 \\(-10%\\)")

  testthat::expect_match(
    vec_messages[1],
    "Positions: new in 2.0.0, 7; expected: New tables."
  )

  testthat::expect_match(
    vec_messages[2],
    "traits / TRY: 40 to 30 \\(-25%\\); expected: TRY duplicates removed."
  )
})

testthat::test_that("diagnose_v1_counts() passes counts within tolerance", {
  res <-
    diagnose_v1_counts(
      data_deltas = dplyr::filter(data_test_deltas, status == "pass"),
      list_build_manifest = list_test_manifest,
      tolerance = 0.05
    )

  testthat::expect_equal(dplyr::pull(res, status), c("pass", "pass"))

  testthat::expect_equal(dplyr::pull(res, observed), c("0", "0"))

  testthat::expect_match(
    dplyr::pull(res, message)[1],
    "^All counts within 5% of v1.0.0 \\(1 of 1\\)"
  )
})

testthat::test_that("diagnose_v1_counts() does not compare a subset", {
  res <-
    diagnose_v1_counts(
      data_deltas = data_test_deltas,
      list_build_manifest = base::list(subset = base::list(enabled = TRUE)),
      tolerance = 0.05
    )

  testthat::expect_equal(dplyr::pull(res, scope), "all")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_match(dplyr::pull(res, message), "^Not compared")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_v1_counts() needs a table of changes", {
  testthat::expect_error(
    diagnose_v1_counts(
      data_deltas = dplyr::select(data_test_deltas, -status),
      list_build_manifest = list_test_manifest,
      tolerance = 0.05
    ),
    regexp = "data_deltas"
  )
})
