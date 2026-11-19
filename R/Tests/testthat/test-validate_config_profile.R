#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_config_profile() accepts a loaded profile", {
  res <-
    validate_config_profile(
      profile_loaded = "subset",
      profile_requested = "subset"
    )

  testthat::expect_equal(res, "subset")

  testthat::expect_invisible(
    validate_config_profile(
      profile_loaded = "default",
      profile_requested = "default"
    )
  )
})

testthat::test_that("validate_config_profile() reads an empty request", {
  res <-
    validate_config_profile(
      profile_loaded = "default",
      profile_requested = ""
    )

  testthat::expect_equal(res, "default")
})

testthat::test_that("validate_config_profile() passes the project profiles", {
  vec_profiles <-
    c("default", "subset", "release")

  res <-
    purrr::map_chr(
      .x = vec_profiles,
      .f = ~ {
        withr::local_envvar(R_CONFIG_ACTIVE = .x)

        validate_config_profile()
      }
    )

  testthat::expect_equal(res, vec_profiles)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_config_profile() refuses a mistyped name", {
  testthat::expect_error(
    validate_config_profile(
      profile_loaded = "default",
      profile_requested = "Subset"
    ),
    regexp = "Subset"
  )

  withr::local_envvar(R_CONFIG_ACTIVE = "subsets")

  testthat::expect_error(
    validate_config_profile(),
    regexp = "subsets"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_config_profile() validates arguments", {
  testthat::expect_error(
    validate_config_profile(
      profile_loaded = c("default", "subset"),
      profile_requested = "default"
    ),
    regexp = "profile_loaded"
  )

  testthat::expect_error(
    validate_config_profile(
      profile_loaded = "default",
      profile_requested = 1
    ),
    regexp = "profile_requested"
  )
})
