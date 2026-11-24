#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_corrected_classification() checks its data", {
  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = "Pinus Picea",
      list_corrections = NULL,
      verbose = FALSE
    ),
    regexp = "`data_classification` must be a data frame"
  )

  data_without_family <-
    tibble::tibble(
      taxon_name = "Pinus Picea",
      species_name = "Abies alba",
      genus_name = "Abies"
    )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_without_family,
      list_corrections = NULL,
      verbose = FALSE
    ),
    regexp = "`data_classification` must be a data frame"
  )

  data_repeated <-
    tibble::tibble(
      taxon_name = c("Betula", "Betula"),
      species_name = c(NA_character_, NA_character_),
      genus_name = c("Betula", "Betula"),
      family_name = c("Betulaceae", "Betulaceae")
    )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_repeated,
      list_corrections = NULL,
      verbose = FALSE
    ),
    regexp = "more than once"
  )
})

testthat::test_that("prepare_corrected_classification() checks its arguments", {
  data_classification <-
    tibble::tibble(
      taxon_name = "Pinus Picea",
      species_name = "Abies alba",
      genus_name = "Abies",
      family_name = "Pinaceae"
    )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = "Pinus Picea",
      verbose = FALSE
    ),
    regexp = "`list_corrections` must be a list of corrections"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = data_classification,
      verbose = FALSE
    ),
    regexp = "`list_corrections` must be a list of corrections"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = NULL,
      verbose = NA
    ),
    regexp = "`verbose` must be TRUE or FALSE"
  )
})

testthat::test_that("prepare_corrected_classification() checks corrections", {
  data_classification <-
    tibble::tibble(
      taxon_name = "Pinus Picea",
      species_name = "Abies alba",
      genus_name = "Abies",
      family_name = "Pinaceae"
    )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(family_name = "Pinaceae")
      ),
      verbose = FALSE
    ),
    regexp = "lacks `taxon_name`"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", order_name = "Pinales")
      ),
      verbose = FALSE
    ),
    regexp = "order_name"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(
          taxon_name = "Pinus Picea",
          family_name = c("Pinaceae", "Abietaceae")
        )
      ),
      verbose = FALSE
    ),
    regexp = "single text"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", family_name = 1)
      ),
      verbose = FALSE
    ),
    regexp = "single text"
  )

  testthat::expect_error(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", family_name = "Pinaceae"),
        base::list(taxon_name = "Pinus Picea", genus_name = "Pinus")
      ),
      verbose = FALSE
    ),
    regexp = "more than once"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_corrected_classification() keeps the layout", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Pinus Picea", "Betula"),
      species_name = c("Quercus robur", "Abies alba", NA_character_),
      genus_name = c("Quercus", "Abies", "Betula"),
      family_name = c("Fagaceae", "Pinaceae", "Betulaceae")
    )

  res <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", family_name = "Pinaceae")
      ),
      verbose = FALSE
    )

  testthat::expect_s3_class(res, "data.frame")

  testthat::expect_named(
    res,
    c("taxon_name", "species_name", "genus_name", "family_name")
  )

  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Quercus robur", "Pinus Picea", "Betula")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_corrected_classification() sets the given ranks", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Pinus Picea", "Betula"),
      species_name = c("Quercus robur", "Abies alba", NA_character_),
      genus_name = c("Quercus", "Abies", "Betula"),
      family_name = c("Fagaceae", "Pinaceae", "Betulaceae")
    )

  res <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", family_name = "Pinaceae")
      ),
      verbose = FALSE
    )

  data_expected <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Pinus Picea", "Betula"),
      species_name = c("Quercus robur", NA_character_, NA_character_),
      genus_name = c("Quercus", NA_character_, "Betula"),
      family_name = c("Fagaceae", "Pinaceae", "Betulaceae")
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_corrected_classification() sets several ranks", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Dryas sp", "Betula"),
      species_name = c(NA_character_, NA_character_),
      genus_name = c(NA_character_, "Betula"),
      family_name = c(NA_character_, "Betulaceae")
    )

  res <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(
          taxon_name = "Dryas sp",
          genus_name = "Dryas",
          family_name = "Rosaceae"
        )
      ),
      verbose = FALSE
    )

  data_expected <-
    tibble::tibble(
      taxon_name = c("Dryas sp", "Betula"),
      species_name = c(NA_character_, NA_character_),
      genus_name = c("Dryas", "Betula"),
      family_name = c("Rosaceae", "Betulaceae")
    )

  testthat::expect_equal(res, data_expected)
})

testthat::test_that("prepare_corrected_classification() keeps names as given", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Pinus Picea"),
      species_name = c("Quercus robur", "Abies alba"),
      genus_name = c("Quercus", "Abies"),
      family_name = c("Fagaceae", "Pinaceae")
    )

  res_null <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = NULL,
      verbose = FALSE
    )

  res_empty <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(),
      verbose = FALSE
    )

  testthat::expect_equal(res_null, data_classification)

  testthat::expect_equal(res_empty, data_classification)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_corrected_classification() skips absent names", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Betula"),
      species_name = c("Quercus robur", NA_character_),
      genus_name = c("Quercus", "Betula"),
      family_name = c("Fagaceae", "Betulaceae")
    )

  res <-
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = base::list(
        base::list(taxon_name = "Pinus Picea", family_name = "Pinaceae")
      ),
      verbose = FALSE
    )

  testthat::expect_equal(res, data_classification)
})


#----------------------------------------------------------#
# Messages -----
#----------------------------------------------------------#

testthat::test_that("prepare_corrected_classification() reports when verbose", {
  data_classification <-
    tibble::tibble(
      taxon_name = c("Quercus robur", "Pinus Picea"),
      species_name = c("Quercus robur", "Abies alba"),
      genus_name = c("Quercus", "Abies"),
      family_name = c("Fagaceae", "Pinaceae")
    )

  list_corrections <-
    base::list(
      base::list(taxon_name = "Pinus Picea", family_name = "Pinaceae"),
      base::list(taxon_name = "Abies Picea", family_name = "Pinaceae")
    )

  testthat::expect_message(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = list_corrections,
      verbose = TRUE
    ),
    regexp = "Corrected the classification of 1 name"
  )

  testthat::expect_message(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = list_corrections,
      verbose = TRUE
    ),
    regexp = "Abies Picea"
  )

  testthat::expect_no_message(
    prepare_corrected_classification(
      data_classification = data_classification,
      list_corrections = list_corrections,
      verbose = FALSE
    )
  )
})
