#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_build_manifest() reads a saved manifest back", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:100), con = path_database)

  list_version <-
    list(
      version = "2.0.0",
      update_date = "2026-08-28",
      changelog = "Test build"
    )

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = "default",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list_version,
      git_commit = base::strrep("a", 40L),
      time_build = base::as.POSIXct("2026-11-19 10:00:00", tz = "UTC")
    )

  res <-
    load_build_manifest(path_manifest = path_manifest)

  testthat::expect_type(res, "list")

  testthat::expect_named(
    res,
    c(
      "manifest_version", "database", "profile", "subset", "version",
      "producer_pins", "git_commit", "git_clean", "build_time_utc"
    )
  )

  testthat::expect_equal(purrr::chuck(res, "profile"), "default")

  testthat::expect_equal(purrr::chuck(res, "version"), list_version)

  testthat::expect_equal(
    purrr::chuck(res, "database", "file_name"),
    "VegVault.sqlite"
  )

  testthat::expect_equal(purrr::chuck(res, "producer_pins"), list())

  testthat::expect_equal(
    purrr::chuck(res, "build_time_utc"),
    "2026-11-19T10:00:00Z"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_build_manifest() checks the database file", {
  dir_build <-
    withr::local_tempdir(pattern = "private_folder_")

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:100), con = path_database)

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

  res <-
    load_build_manifest(
      path_manifest = path_manifest,
      path_database = path_database
    )

  testthat::expect_equal(purrr::chuck(res, "database", "size_bytes"), 100)

  # A copy under another name is not the database of this manifest
  path_copy <-
    base::file.path(dir_build, "VegVault_copy.sqlite")

  base::file.copy(from = path_database, to = path_copy)

  testthat::expect_error(
    load_build_manifest(
      path_manifest = path_manifest,
      path_database = path_copy
    ),
    regexp = "file name"
  )

  # The same size but a later modification time
  base::Sys.setFileTime(
    path = path_database,
    time = base::file.mtime(path_database) + 60
  )

  testthat::expect_error(
    load_build_manifest(
      path_manifest = path_manifest,
      path_database = path_database
    ),
    regexp = "changed after the build"
  )

  # A different size with the original modification time
  time_modified_original <-
    base::as.POSIXct(
      purrr::chuck(res, "database", "modified_time_utc"),
      format = "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )

  base::writeBin(object = base::as.raw(1:50), con = path_database)

  base::Sys.setFileTime(path = path_database, time = time_modified_original)

  res_error <-
    testthat::expect_error(
      load_build_manifest(
        path_manifest = path_manifest,
        path_database = path_database
      ),
      regexp = "changed after the build"
    )

  testthat::expect_false(
    stringr::str_detect(
      base::conditionMessage(res_error),
      stringr::fixed("private_folder_")
    )
  )

  base::file.remove(path_database)

  testthat::expect_error(
    load_build_manifest(
      path_manifest = path_manifest,
      path_database = path_database
    ),
    regexp = "does not exist"
  )
})

testthat::test_that("load_build_manifest() checks the expected profile", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault_subset.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = "subset",
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
    )

  res <-
    load_build_manifest(
      path_manifest = path_manifest,
      profile_expected = "subset"
    )

  testthat::expect_equal(purrr::chuck(res, "profile"), "subset")

  testthat::expect_error(
    load_build_manifest(
      path_manifest = path_manifest,
      profile_expected = "release"
    ),
    regexp = "release"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_build_manifest() needs the manifest file", {
  testthat::expect_error(
    load_build_manifest(
      path_manifest = base::file.path(base::tempdir(), "missing.yml")
    ),
    regexp = "manifest"
  )

  testthat::expect_error(
    load_build_manifest(path_manifest = c("a.yml", "b.yml")),
    regexp = "path_manifest"
  )
})

testthat::test_that("load_build_manifest() checks the format", {
  dir_build <-
    withr::local_tempdir()

  path_manifest <-
    base::file.path(dir_build, "VegVault_build_manifest.yml")

  base::writeLines(
    text = c("manifest_version: 1", "profile: default"),
    con = path_manifest
  )

  testthat::expect_error(
    load_build_manifest(path_manifest = path_manifest),
    regexp = "git_commit"
  )

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_saved <-
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

  vec_lines_future <-
    base::readLines(con = path_saved) |>
    stringr::str_replace(
      pattern = "^manifest_version: 1$",
      replacement = "manifest_version: 2"
    )

  base::writeLines(text = vec_lines_future, con = path_saved)

  testthat::expect_error(
    load_build_manifest(path_manifest = path_saved),
    regexp = "manifest_version"
  )
})


#----------------------------------------------------------#
# Clean checkout -----
#----------------------------------------------------------#

testthat::test_that("load_build_manifest() needs a clean release", {
  dir_build <-
    withr::local_tempdir()

  path_database <-
    base::file.path(dir_build, "VegVault.sqlite")

  base::writeBin(object = base::as.raw(1:10), con = path_database)

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = "release",
      flag_git_clean = TRUE,
      list_subset = list(enabled = FALSE),
      list_version = list(
        version = "2.0.0",
        update_date = "2026-08-28",
        changelog = "Test build"
      ),
      git_commit = base::strrep("a", 40L)
    )

  res <-
    load_build_manifest(
      path_manifest = path_manifest,
      profile_expected = "release"
    )

  testthat::expect_true(purrr::chuck(res, "git_clean"))

  # A manifest edited by hand to a dirty release is not accepted
  vec_lines_dirty <-
    base::readLines(con = path_manifest) |>
    stringr::str_replace(
      pattern = "^git_clean: .*$",
      replacement = "git_clean: no"
    )

  base::writeLines(text = vec_lines_dirty, con = path_manifest)

  testthat::expect_error(
    load_build_manifest(
      path_manifest = path_manifest,
      profile_expected = "release"
    ),
    regexp = "uncommitted"
  )

  # Without a release expectation the flag is only reported
  res_unchecked <-
    load_build_manifest(path_manifest = path_manifest)

  testthat::expect_false(purrr::chuck(res_unchecked, "git_clean"))
})
