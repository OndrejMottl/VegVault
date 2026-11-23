#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

data_counts_test <-
  tibble::tribble(
    ~metric, ~scope, ~n_v2,
    "table_rows", "TraitsValue", 10,
    "samples", "traits / TRY", 4,
    "traits_value_rows", "traits / BIEN", 6,
    "traits_value_rows", "traits / TRY", 4
  )

list_sources_test <-
  base::list(try_traits = "traits / TRY", bien_traits = "traits / BIEN")

list_manifest_test <-
  base::list(
    producer_pins = base::list(
      base::list(artefact_id = "splot_plots", n_rows = 10),
      base::list(artefact_id = "try_traits", n_rows = 4),
      base::list(artefact_id = "bien_traits", n_rows = 6)
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_value_counts() passes equal counts", {
  res <-
    diagnose_trait_value_counts(
      data_counts = data_counts_test,
      list_build_manifest = list_manifest_test,
      list_sources = list_sources_test
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, check_id),
    c("trait_value_counts", "trait_value_counts")
  )

  # In the order of the sources
  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("traits / TRY", "traits / BIEN")
  )

  testthat::expect_equal(dplyr::pull(res, status), c("pass", "pass"))

  testthat::expect_equal(dplyr::pull(res, observed), c("4", "6"))

  testthat::expect_equal(dplyr::pull(res, threshold), c("4", "6"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_value_counts() fails another count", {
  data_counts_short <-
    dplyr::mutate(
      data_counts_test,
      n_v2 = dplyr::if_else(scope == "traits / BIEN", 5, n_v2)
    )

  res <-
    diagnose_trait_value_counts(
      data_counts = data_counts_short,
      list_build_manifest = list_manifest_test,
      list_sources = list_sources_test
    )

  testthat::expect_equal(dplyr::pull(res, status), c("pass", "fail"))

  testthat::expect_match(
    dplyr::pull(res, message)[2],
    "BIEN: 5, .*bien_traits has 6 records"
  )
})

testthat::test_that("diagnose_trait_value_counts() counts a missing source", {
  # No BIEN trait value in the database: 0 rows, which a pin of 0 allows
  data_counts_try <-
    dplyr::filter(data_counts_test, scope != "traits / BIEN")

  list_manifest_none <-
    purrr::modify_in(
      list_manifest_test,
      .where = base::list("producer_pins", 3L, "n_rows"),
      .f = ~ 0
    )

  res_none <-
    diagnose_trait_value_counts(
      data_counts = data_counts_try,
      list_build_manifest = list_manifest_none,
      list_sources = list_sources_test
    )

  testthat::expect_equal(dplyr::pull(res_none, status), c("pass", "pass"))

  testthat::expect_equal(dplyr::pull(res_none, observed)[2], "0")

  res_missing <-
    diagnose_trait_value_counts(
      data_counts = data_counts_try,
      list_build_manifest = list_manifest_test,
      list_sources = list_sources_test
    )

  testthat::expect_equal(dplyr::pull(res_missing, status), c("pass", "fail"))
})

testthat::test_that("diagnose_trait_value_counts() needs a counted pin", {
  # A manifest from before the row counts, and one without the BIEN pin
  list_manifest_old <-
    purrr::modify_in(
      list_manifest_test,
      .where = base::list("producer_pins", 2L),
      .f = ~ purrr::list_modify(.x, n_rows = rlang::zap())
    )

  res_old <-
    diagnose_trait_value_counts(
      data_counts = data_counts_test,
      list_build_manifest = list_manifest_old,
      list_sources = list_sources_test
    )

  testthat::expect_equal(dplyr::pull(res_old, status), c("fail", "pass"))

  testthat::expect_match(dplyr::pull(res_old, message)[1], "row count")

  list_manifest_unpinned <-
    purrr::modify_in(
      list_manifest_test,
      .where = "producer_pins",
      .f = ~ .x[1:2]
    )

  res_unpinned <-
    diagnose_trait_value_counts(
      data_counts = data_counts_test,
      list_build_manifest = list_manifest_unpinned,
      list_sources = list_sources_test
    )

  testthat::expect_equal(
    dplyr::pull(res_unpinned, status),
    c("pass", "fail")
  )

  testthat::expect_match(
    dplyr::pull(res_unpinned, message)[2],
    "not pinned"
  )
})

testthat::test_that("diagnose_trait_value_counts() fails an unknown source", {
  # Trait values whose dataset has no source the settings name
  data_counts_extra <-
    dplyr::bind_rows(
      data_counts_test,
      tibble::tibble(
        metric = "traits_value_rows",
        scope = "traits / (none)",
        n_v2 = 2
      )
    )

  res <-
    diagnose_trait_value_counts(
      data_counts = data_counts_extra,
      list_build_manifest = list_manifest_test,
      list_sources = list_sources_test
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("traits / TRY", "traits / BIEN", "traits / (none)")
  )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("pass", "pass", "fail")
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_trait_value_counts() validates arguments", {
  testthat::expect_error(
    diagnose_trait_value_counts(
      data_counts = dplyr::select(data_counts_test, -n_v2),
      list_build_manifest = list_manifest_test,
      list_sources = list_sources_test
    ),
    regexp = "n_v2"
  )

  testthat::expect_error(
    diagnose_trait_value_counts(
      data_counts = data_counts_test,
      list_build_manifest = list_manifest_test,
      list_sources = base::unname(list_sources_test)
    ),
    regexp = "list_sources"
  )

  testthat::expect_error(
    diagnose_trait_value_counts(
      data_counts = data_counts_test,
      list_build_manifest = list_manifest_test,
      list_sources = base::list(try_traits = 1)
    ),
    regexp = "list_sources"
  )
})
