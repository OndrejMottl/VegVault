#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_build_profile() accepts matching settings", {
  list_subset_enabled <-
    list(
      enabled = TRUE,
      box_name = "alaska_yukon",
      lon_min = -170,
      lon_max = -125,
      lat_min = 54,
      lat_max = 72,
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  res_subset <-
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = list_subset_enabled
    )

  testthat::expect_equal(res_subset, "subset")

  testthat::expect_invisible(
    validate_build_profile(
      profile = "release",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE)
    )
  )

  res_default <-
    validate_build_profile(
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE)
    )

  testthat::expect_equal(res_default, "default")
})

testthat::test_that("validate_build_profile() passes the project profiles", {
  vec_profiles <-
    c("default", "subset", "release")

  res <-
    purrr::map_chr(
      .x = vec_profiles,
      .f = ~ {
        withr::local_envvar(R_CONFIG_ACTIVE = .x)

        validate_build_profile(
          profile = load_config_value(value = "profile"),
          flag_git_clean = TRUE,
          list_subset = load_config_value(value = "subset")
        )
      }
    )

  testthat::expect_equal(res, vec_profiles)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_build_profile() validates arguments", {
  testthat::expect_error(
    validate_build_profile(
      profile = "dev",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE)
    ),
    regexp = "profile"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = c("default", "release"),
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE)
    ),
    regexp = "profile"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = "no")
    ),
    regexp = "enabled"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list()
    ),
    regexp = "enabled"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_build_profile() refuses a release subset", {
  list_subset_enabled <-
    list(
      enabled = TRUE,
      box_name = "alaska_yukon",
      lon_min = -170,
      lon_max = -125,
      lat_min = 54,
      lat_max = 72,
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  testthat::expect_error(
    validate_build_profile(
      profile = "release",
      flag_git_clean = TRUE,
      list_subset = list_subset_enabled
    ),
    regexp = "release"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list_subset_enabled
    ),
    regexp = "subset"
  )
})

testthat::test_that("validate_build_profile() needs an enabled subset", {
  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE)
    ),
    regexp = "enabled"
  )
})

testthat::test_that("validate_build_profile() checks the subset box", {
  list_subset_base <-
    list(
      enabled = TRUE,
      box_name = "alaska_yukon",
      lon_min = -170,
      lon_max = -125,
      lat_min = 54,
      lat_max = 72,
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = purrr::list_modify(list_subset_base, lat_max = 50)
    ),
    regexp = "lat_min"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = purrr::list_modify(list_subset_base, box_name = "")
    ),
    regexp = "box_name"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = purrr::list_modify(
        list_subset_base,
        database_file = "D:/Private/VegVault.sqlite"
      )
    ),
    regexp = "relative"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = purrr::list_modify(
        list_subset_base,
        database_file = "../Live/VegVault.sqlite"
      )
    ),
    regexp = "data root"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = purrr::list_modify(
        list_subset_base,
        database_file = purrr::zap()
      )
    ),
    regexp = "database_file"
  )
})


#----------------------------------------------------------#
# Clean checkout -----
#----------------------------------------------------------#

testthat::test_that("validate_build_profile() needs clean code to release", {
  testthat::expect_error(
    validate_build_profile(
      profile = "release",
      flag_git_clean = FALSE,
      list_subset = list(enabled = FALSE)
    ),
    regexp = "uncommitted"
  )

  # Development and rehearsal builds may run uncommitted code
  res_default <-
    validate_build_profile(
      profile = "default",
      flag_git_clean = FALSE,
      list_subset = list(enabled = FALSE)
    )

  testthat::expect_equal(res_default, "default")

  res_subset <-
    validate_build_profile(
      profile = "subset",
      flag_git_clean = FALSE,
      list_subset = list(
        enabled = TRUE,
        box_name = "alaska_yukon",
        lon_min = -170,
        lon_max = -125,
        lat_min = 54,
        lat_max = 72,
        database_file = "Temp/Subset/VegVault_subset.sqlite"
      )
    )

  testthat::expect_equal(res_subset, "subset")
})

testthat::test_that("validate_build_profile() validates the clean flag", {
  testthat::expect_error(
    validate_build_profile(
      profile = "default",
      flag_git_clean = NA,
      list_subset = list(enabled = FALSE)
    ),
    regexp = "flag_git_clean"
  )

  testthat::expect_error(
    validate_build_profile(
      profile = "default",
      flag_git_clean = "yes",
      list_subset = list(enabled = FALSE)
    ),
    regexp = "flag_git_clean"
  )
})
