#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("is_release_tag() accepts semantic-version tags", {
  testthat::expect_true(is_release_tag(tag = "v2.0.0"))

  testthat::expect_true(is_release_tag(tag = "v10.12.3"))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("is_release_tag() refuses everything else", {
  list_invalid <-
    list(
      "main", "2.0.0", "v2.0", "v2.0.0-zenodo", "v2.0.0 ", "V2.0.0",
      stringr::str_c("v2.0.0", base::intToUtf8(10L)),
      NA_character_, c("v1.0.0", "v2.0.0"), 2, NULL
    )

  vec_res <-
    purrr::map_lgl(.x = list_invalid, .f = is_release_tag)

  testthat::expect_equal(
    vec_res,
    base::rep(FALSE, base::length(list_invalid))
  )
})
