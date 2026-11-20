#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_release_url() fills the raw GitHub template", {
  res <-
    build_release_url(
      url_template = stringr::str_c(
        "https://raw.githubusercontent.com/",
        "{repository}/{tag}/{directory}/{file_name}"
      ),
      repository = "OndrejMottl/VegVault-Trait_data",
      tag = "v2.0.0",
      directory = "Outputs/Data",
      file_name = "data_trait_try_2026-01-01__abc__.qs"
    )

  testthat::expect_equal(
    res,
    stringr::str_c(
      "https://raw.githubusercontent.com/OndrejMottl/VegVault-Trait_data/",
      "v2.0.0/Outputs/Data/data_trait_try_2026-01-01__abc__.qs"
    )
  )
})

testthat::test_that("build_release_url() fills a local stand-in", {
  res <-
    build_release_url(
      url_template = "file:///D:/remote/{repository}/{tag}/{file_name}",
      repository = "OndrejMottl/VegVault-Trait_data",
      tag = "v2.0.0",
      directory = "Outputs/Data",
      file_name = "x.qs"
    )

  testthat::expect_equal(
    res,
    "file:///D:/remote/OndrejMottl/VegVault-Trait_data/v2.0.0/x.qs"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_release_url() needs a release tag", {
  testthat::expect_error(
    build_release_url(
      url_template = "https://host/{repository}/{tag}/{file_name}",
      repository = "OndrejMottl/VegVault-Trait_data",
      tag = "main",
      directory = "Outputs/Data",
      file_name = "x.qs"
    ),
    regexp = "release tag"
  )
})

testthat::test_that("build_release_url() checks the template", {
  testthat::expect_error(
    build_release_url(
      url_template = "https://host/{repository}/{file_name}",
      repository = "OndrejMottl/VegVault-Trait_data",
      tag = "v2.0.0",
      directory = "Outputs/Data",
      file_name = "x.qs"
    ),
    regexp = "\\{tag\\}"
  )

  testthat::expect_error(
    build_release_url(
      url_template = "https://host/{owner}/{tag}/{file_name}",
      repository = "OndrejMottl/VegVault-Trait_data",
      tag = "v2.0.0",
      directory = "Outputs/Data",
      file_name = "x.qs"
    ),
    regexp = "owner"
  )
})
