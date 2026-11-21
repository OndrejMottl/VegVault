#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_config_references() validates arguments", {
  list_source <-
    build_test_source_config()

  testthat::expect_error(
    prepare_config_references(list_source = list_source, sel_role = "x"),
    regexp = "sel_role"
  )

  testthat::expect_error(
    prepare_config_references(
      list_source = base::list(dataset_type = "a"),
      sel_role = "taxon"
    ),
    regexp = "references"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_config_references() returns one role", {
  res <-
    prepare_config_references(
      list_source = build_test_source_config(),
      sel_role = "source_type"
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("reference_detail", "mandatory"))
  testthat::expect_equal(
    dplyr::pull(res, reference_detail),
    "Citation of TestSource"
  )
  testthat::expect_identical(dplyr::pull(res, mandatory), TRUE)
})

testthat::test_that("prepare_config_references() returns several or none", {
  list_source <-
    base::list(
      references = base::list(
        base::list(role = "source_type", mandatory = TRUE, detail = "A"),
        base::list(role = "source_type", mandatory = TRUE, detail = "B"),
        base::list(role = "taxon", mandatory = FALSE, detail = "C")
      )
    )

  res_two <-
    prepare_config_references(
      list_source = list_source,
      sel_role = "source_type"
    )

  testthat::expect_equal(dplyr::pull(res_two, reference_detail), c("A", "B"))

  res_none <-
    prepare_config_references(list_source = list_source, sel_role = "trait")

  testthat::expect_equal(base::nrow(res_none), 0L)
  testthat::expect_named(res_none, c("reference_detail", "mandatory"))
  testthat::expect_type(dplyr::pull(res_none, mandatory), "logical")
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_config_references() refuses bad records", {
  # A short local helper: a source entry with one reference record, used by
  #   four of the cases below
  build_list <- function(record) {
    base::list(references = base::list(record))
  }

  testthat::expect_error(
    prepare_config_references(
      list_source = build_list(base::list(role = "taxon", mandatory = TRUE)),
      sel_role = "taxon"
    ),
    regexp = "detail"
  )

  testthat::expect_error(
    prepare_config_references(
      list_source = build_list(
        base::list(role = "taxon", mandatory = "yes", detail = "A")
      ),
      sel_role = "taxon"
    ),
    regexp = "mandatory"
  )

  testthat::expect_error(
    prepare_config_references(
      list_source = build_list(
        base::list(role = "dataset", mandatory = TRUE, detail = "A")
      ),
      sel_role = "taxon"
    ),
    regexp = "dataset"
  )

  testthat::expect_error(
    prepare_config_references(
      list_source = build_list(
        base::list(role = "taxon", mandatory = TRUE, detail = "")
      ),
      sel_role = "taxon"
    ),
    regexp = "detail"
  )

  testthat::expect_error(
    prepare_config_references(
      list_source = base::list(
        references = base::list(
          base::list(role = "taxon", mandatory = FALSE, detail = "A"),
          base::list(role = "taxon", mandatory = FALSE, detail = "A")
        )
      ),
      sel_role = "taxon"
    ),
    regexp = "repeat"
  )
})
