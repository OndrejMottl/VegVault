#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_build_manifest() writes next to the database", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:100), con = path_database)

  res <-
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L),
      time_build = base::as.POSIXct("2026-11-19 10:00:00", tz = "UTC")
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(
    res,
    resolve_build_manifest_path(path_database = path_database)
  )

  testthat::expect_true(base::file.exists(res))
})

testthat::test_that("save_build_manifest() records the build", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault_subset.sqlite")

  base::writeBin(object = base::as.raw(1:100), con = path_database)

  base::Sys.setFileTime(
    path = path_database,
    time = base::as.POSIXct("2026-11-19 09:30:15", tz = "UTC")
  )

  list_subset <-
    list(
      enabled = TRUE,
      box_name = "alaska_yukon",
      lon_min = -170,
      lon_max = -125,
      lat_min = 54,
      lat_max = 72,
      database_file = "Temp/Subset/VegVault_subset.sqlite"
    )

  list_pins <-
    list(
      list(
        contract_id = "splot_plots",
        file_name = "data_splot_2000-01-01__abc__.qs"
      )
    )

  path_manifest <-
    base::file.path(dir_build, "manifest.yml")

  testthat::expect_invisible(
    save_build_manifest(
      path_database = path_database,
      profile = "subset",
      flag_git_clean = TRUE,
      list_subset = list_subset,
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      list_producer_pins = list_pins,
      git_commit = base::strrep("0123456789", 4L),
      time_build = base::as.POSIXct("2026-11-19 10:00:00", tz = "UTC"),
      path_manifest = path_manifest
    )
  )

  list_written <-
    yaml::read_yaml(file = path_manifest)

  testthat::expect_named(
    list_written,
    c(
      "manifest_version", "database", "profile", "subset", "version",
      "producer_pins", "git_commit", "git_clean", "build_time_utc"
    )
  )

  testthat::expect_equal(purrr::chuck(list_written, "manifest_version"), 1L)

  testthat::expect_equal(
    purrr::chuck(list_written, "database"),
    list(
      file_name = "VegVault_subset.sqlite",
      size_bytes = 100,
      modified_time_utc = "2026-11-19T09:30:15Z"
    )
  )

  testthat::expect_equal(purrr::chuck(list_written, "profile"), "subset")

  testthat::expect_equal(purrr::chuck(list_written, "subset"), list_subset)

  testthat::expect_equal(
    purrr::chuck(list_written, "version", "version"),
    "2.0.0"
  )

  testthat::expect_equal(
    purrr::chuck(list_written, "producer_pins"),
    list_pins
  )

  testthat::expect_equal(
    purrr::chuck(list_written, "git_commit"),
    base::strrep("0123456789", 4L)
  )

  testthat::expect_equal(
    purrr::chuck(list_written, "build_time_utc"),
    "2026-11-19T10:00:00Z"
  )
})

testthat::test_that("save_build_manifest() never records the path", {
  dir_build <-
    withr::local_tempdir(pattern = "private_folder_")

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L)
    )

  vec_lines <-
    base::readLines(con = path_manifest)

  testthat::expect_false(
    base::any(stringr::str_detect(vec_lines, "private_folder_"))
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_build_manifest() replaces an old manifest", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_manifest <-
    resolve_build_manifest_path(path_database = path_database)

  base::writeLines(text = "old: manifest", con = path_manifest)

  save_build_manifest(
    path_database = path_database,
    profile = "default",
    flag_git_clean = TRUE,
    list_subset = list(enabled = FALSE),
    list_version = list(
      version = "2.0.0",
      update_date = "2026-08-28",
      changelog = "Test build"
    ),
    git_commit = base::strrep("a", 40L)
  )

  list_written <-
    yaml::read_yaml(file = path_manifest)

  testthat::expect_false("old" %in% base::names(list_written))

  testthat::expect_equal(
    purrr::chuck(list_written, "database", "size_bytes"),
    10
  )
})

testthat::test_that("save_build_manifest() checks the profile first", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "release",
      flag_git_clean = TRUE,
      list_subset = list(
        enabled = TRUE,
        box_name = "alaska_yukon",
        lon_min = -170,
        lon_max = -125,
        lat_min = 54,
        lat_max = 72,
        database_file = "Temp/Subset/VegVault_subset.sqlite"
      ),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L)
    ),
    regexp = "release"
  )

  testthat::expect_false(
    base::file.exists(
      resolve_build_manifest_path(path_database = path_database)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_build_manifest() needs the database file", {
  dir_build <-
    withr::local_tempdir(pattern = "private_folder_")

  res_error <-
    testthat::expect_error(
      save_build_manifest(
        path_database = base::file.path(dir_build, "missing.sqlite"),
        profile = "default",
        flag_git_clean = TRUE,
        list_subset = list(enabled = FALSE),
        list_version = list(
          version = "2.0.0",
          update_date = "2026-08-28",
          changelog = "Test build"
        ),
        git_commit = base::strrep("a", 40L)
      ),
      regexp = "does not exist"
    )

  testthat::expect_false(
    stringr::str_detect(
      base::conditionMessage(res_error),
      stringr::fixed("private_folder_")
    )
  )
})

testthat::test_that("save_build_manifest() validates arguments", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  list_version <-
    list(
      version = "2.0.0",
      update_date = "2026-08-28",
      changelog = "Test build"
    )

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list(version = "2.0.0"),
      git_commit = base::strrep("a", 40L)
    ),
    regexp = "list_version"
  )

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list_version,
      git_commit = "abc123"
    ),
    regexp = "git_commit"
  )

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list_version,
      list_producer_pins = "none",
      git_commit = base::strrep("a", 40L)
    ),
    regexp = "list_producer_pins"
  )

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list_version,
      git_commit = base::strrep("a", 40L),
      time_build = "2026-11-19"
    ),
    regexp = "time_build"
  )
})


#----------------------------------------------------------#
# Clean checkout -----
#----------------------------------------------------------#

testthat::test_that("save_build_manifest() records the clean flag", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = FALSE,
      list_subset = list(enabled = FALSE),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L)
    )

  list_written <-
    yaml::read_yaml(file = path_manifest)

  testthat::expect_false(purrr::chuck(list_written, "git_clean"))
})

testthat::test_that("save_build_manifest() refuses a dirty release", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  testthat::expect_error(
    save_build_manifest(
      path_database = path_database,
      profile = "release",
      flag_git_clean = FALSE,
      list_subset = list(enabled = FALSE),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L)
    ),
    regexp = "uncommitted"
  )

  testthat::expect_false(
    base::file.exists(
      resolve_build_manifest_path(path_database = path_database)
    )
  )
})
