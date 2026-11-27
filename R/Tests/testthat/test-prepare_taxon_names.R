#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_names() validates arguments", {
  testthat::expect_error(
    prepare_taxon_names(list_source_tables = "a"),
    regexp = "list_source_tables"
  )

  testthat::expect_error(
    prepare_taxon_names(
      list_source_tables = base::list(
        purrr::list_modify(
          build_source_table_template(),
          sample_taxa = purrr::zap()
        )
      )
    ),
    regexp = "sample_taxa"
  )

  testthat::expect_error(
    prepare_taxon_names(
      list_source_tables = base::list(
        purrr::list_modify(
          build_source_table_template(),
          trait_values = tibble::tibble(name = "Betula")
        )
      )
    ),
    regexp = "taxon_name"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_names() collects the names once", {
  list_source_a <-
    purrr::list_modify(
      build_source_table_template(),
      taxa = tibble::tibble(taxon_name = c("Betula", "Alnus")),
      sample_taxa = tibble::tibble(
        sample_name = c("s1", "s1", "s2"),
        taxon_name = c("Betula", "Only in samples", "Betula"),
        value = c(1, 2, 3)
      )
    )

  list_source_b <-
    purrr::list_modify(
      build_source_table_template(),
      taxon_references = tibble::tibble(
        taxon_name = "Only in references",
        reference_detail = "Reference",
        mandatory = FALSE
      ),
      trait_values = tibble::tibble(taxon_name = c("Alnus", "Only in traits"))
    )

  res <-
    prepare_taxon_names(
      list_source_tables = base::list(a = list_source_a, b = list_source_b)
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(
    res,
    c(
      "Alnus", "Betula", "Only in references", "Only in samples",
      "Only in traits"
    )
  )
})

testthat::test_that("prepare_taxon_names() sorts in the C locale", {
  res <-
    prepare_taxon_names(
      list_source_tables = base::list(
        purrr::list_modify(
          build_source_table_template(),
          taxa = tibble::tibble(taxon_name = c("b", "a", "B", "_x"))
        )
      )
    )

  testthat::expect_equal(res, c("B", "_x", "a", "b"))
})

testthat::test_that("prepare_taxon_names() leaves out missing names", {
  res <-
    prepare_taxon_names(
      list_source_tables = base::list(
        purrr::list_modify(
          build_source_table_template(),
          taxa = tibble::tibble(taxon_name = c("Betula", NA))
        )
      )
    )

  testthat::expect_equal(res, "Betula")
})

testthat::test_that("prepare_taxon_names() accepts sources without names", {
  testthat::expect_equal(
    prepare_taxon_names(list_source_tables = base::list()),
    base::character(0)
  )

  testthat::expect_equal(
    prepare_taxon_names(
      list_source_tables = base::list(build_source_table_template())
    ),
    base::character(0)
  )
})

testthat::test_that("prepare_taxon_names() reads the prepared sources", {
  list_source_tables <-
    build_test_database_sources() |>
    purrr::chuck("list_source_tables")

  res <-
    prepare_taxon_names(list_source_tables = list_source_tables)

  vec_expected <-
    list_source_tables |>
    purrr::map(
      .f = ~ c(
        dplyr::pull(purrr::chuck(.x, "taxa"), taxon_name),
        dplyr::pull(purrr::chuck(.x, "sample_taxa"), taxon_name),
        dplyr::pull(purrr::chuck(.x, "trait_values"), taxon_name)
      )
    ) |>
    purrr::list_c() |>
    base::unique()

  testthat::expect_setequal(res, vec_expected)

  testthat::expect_gt(base::length(res), 0L)
})
