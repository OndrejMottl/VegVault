#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

data_test_reference <-
  tibble::tribble(
    ~metric, ~scope, ~n_v1, ~source,
    "table_rows", "AbioticDataReference", 1000, "rowid_bounds",
    "table_rows", "Samples", 100, "rowid_bounds",
    "table_rows", "Taxa", 50, "rowid_bounds",
    "samples", "traits / TRY", 40, "sample_composition",
    "samples", "traits / BIEN", 60, "sample_composition",
    "positions", "all", 0, "tuples_all_sources"
  )

# Samples within 5%, Taxa 10% fewer, TRY samples 25% fewer, BIEN samples
#   and positions unchanged, the table Positions new in 2.0.0, and the
#   links per sample doubled
data_test_counts <-
  tibble::tribble(
    ~metric, ~scope, ~n_v2,
    "table_rows", "Samples", 104,
    "table_rows", "Taxa", 45,
    "table_rows", "Positions", 7,
    "samples", "traits / TRY", 30,
    "samples", "traits / BIEN", 60,
    "positions", "all", 0,
    "sample_links", "all", 2000
  )

list_test_comparison <-
  base::list(
    tolerance = 0.05,
    metric_map = base::list(
      base::list(
        v1_metric = "table_rows",
        v1_scope = "AbioticDataReference",
        metric = "sample_links",
        scope = "all",
        note = "A view in 2.0.0."
      )
    ),
    expected_changes = base::list(
      base::list(
        metrics = c("samples"),
        scopes = c("traits / TRY"),
        reason = "TRY duplicates removed."
      ),
      base::list(
        metrics = c("table_rows"),
        scopes = c("Positions", "PositionLink"),
        reason = "New tables."
      )
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_v1_count_deltas() joins both versions", {
  res <-
    compute_v1_count_deltas(
      data_counts = data_test_counts,
      data_reference = data_test_reference,
      list_comparison = list_test_comparison
    )

  testthat::expect_named(
    res,
    c(
      "metric", "scope", "n_v1", "n_v2", "delta", "relative_change",
      "status", "expected_reason", "note"
    )
  )

  # Reference order first (with the mapped row), then counts only in 2.0.0
  testthat::expect_equal(
    stringr::str_c(dplyr::pull(res, metric), ":", dplyr::pull(res, scope)),
    c(
      "sample_links:all", "table_rows:Samples", "table_rows:Taxa",
      "samples:traits / TRY", "samples:traits / BIEN", "positions:all",
      "table_rows:Positions"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_v1_count_deltas() flags large changes", {
  res <-
    compute_v1_count_deltas(
      data_counts = data_test_counts,
      data_reference = data_test_reference,
      list_comparison = list_test_comparison
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "pass", "flag", "flag", "pass", "pass", "flag")
  )

  testthat::expect_equal(
    dplyr::pull(res, delta),
    c(1000, 4, -5, -10, 0, 0, NA)
  )

  testthat::expect_equal(
    dplyr::pull(res, relative_change),
    c(1, 0.04, -0.1, -0.25, 0, 0, NA)
  )

  testthat::expect_equal(
    dplyr::pull(res, expected_reason),
    c(
      NA, NA, NA, "TRY duplicates removed.", NA, NA, "New tables."
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, note),
    c("A view in 2.0.0.", NA, NA, NA, NA, NA, NA)
  )
})

testthat::test_that("compute_v1_count_deltas() flags a count of one side", {
  res <-
    compute_v1_count_deltas(
      data_counts = dplyr::filter(data_test_counts, scope != "Taxa"),
      data_reference = data_test_reference,
      list_comparison = base::list(tolerance = 0.5)
    )

  data_taxa <-
    dplyr::filter(res, scope == "Taxa")

  testthat::expect_equal(dplyr::pull(data_taxa, status), "flag")

  testthat::expect_true(base::is.na(dplyr::pull(data_taxa, n_v2)))

  # Without a map, the v1 links stay a table count missing in 2.0.0
  testthat::expect_equal(
    dplyr::pull(
      dplyr::filter(res, scope == "AbioticDataReference"),
      status
    ),
    "flag"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_v1_count_deltas() needs a tolerance", {
  testthat::expect_error(
    compute_v1_count_deltas(
      data_counts = data_test_counts,
      data_reference = data_test_reference,
      list_comparison = base::list(tolerance = -1)
    ),
    regexp = "tolerance"
  )
})

testthat::test_that("compute_v1_count_deltas() needs complete map entries", {
  testthat::expect_error(
    compute_v1_count_deltas(
      data_counts = data_test_counts,
      data_reference = data_test_reference,
      list_comparison = base::list(
        tolerance = 0.05,
        metric_map = base::list(base::list(v1_metric = "table_rows"))
      )
    ),
    regexp = "metric_map"
  )
})
