#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_upstream_profile() validates arguments", {
  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "default",
      profile = "default",
      runner = NA_character_
    ),
    regexp = "runner"
  )

  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "default",
      profile = "default",
      runner = c("a.R", "b.R")
    ),
    regexp = "runner"
  )

  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "default",
      profile = "full",
      runner = "R/Analyses/01_Producer_import/00_run.R"
    ),
    regexp = "`profile`"
  )

  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "default",
      profile = c("default", "subset"),
      runner = "R/Analyses/01_Producer_import/00_run.R"
    ),
    regexp = "`profile`"
  )
})

testthat::test_that("validate_upstream_profile() needs a valid upstream", {
  list_bad <-
    base::list(NULL, NA_character_, "full", "", c("default", "subset"), 1)

  purrr::walk(
    .x = list_bad,
    .f = ~ testthat::expect_error(
      validate_upstream_profile(
        profile_upstream = .x,
        profile = "default",
        runner = "R/Analyses/01_Producer_import/00_run.R"
      ),
      regexp = "01_Producer_import.*no valid profile"
    )
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_upstream_profile() accepts the same profile", {
  vec_profiles <-
    c("default", "subset", "release")

  res <-
    purrr::map_chr(
      .x = vec_profiles,
      .f = ~ validate_upstream_profile(
        profile_upstream = .x,
        profile = .x,
        runner = "R/Analyses/02_Gridpoints/00_run.R"
      )
    )

  testthat::expect_equal(res, vec_profiles)

  testthat::expect_invisible(
    validate_upstream_profile(
      profile_upstream = "subset",
      profile = "subset",
      runner = "R/Analyses/02_Gridpoints/00_run.R"
    )
  )
})

testthat::test_that("validate_upstream_profile() passes the project profiles", {
  vec_profiles <-
    c("default", "subset", "release")

  res <-
    purrr::map_chr(
      .x = vec_profiles,
      .f = ~ {
        withr::local_envvar(R_CONFIG_ACTIVE = .x)

        validate_upstream_profile(
          profile_upstream = .x,
          profile = load_config_value(value = "profile"),
          runner = "R/Analyses/01_Producer_import/00_run.R"
        )
      }
    )

  testthat::expect_equal(res, vec_profiles)
})

testthat::test_that("validate_upstream_profile() refuses another profile", {
  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "subset",
      profile = "release",
      runner = "R/Analyses/01_Producer_import/00_run.R"
    ),
    regexp = "01_Producer_import.*subset.*release"
  )

  testthat::expect_error(
    validate_upstream_profile(
      profile_upstream = "default",
      profile = "subset",
      runner = "R/Analyses/02_Gridpoints/00_run.R"
    ),
    regexp = "R/Analyses/02_Gridpoints/00_run.R"
  )
})
