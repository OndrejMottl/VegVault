#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_release_file() puts a checked file in place", {
  path_source <-
    base::file.path(withr::local_tempdir(), "release.qs")

  base::writeBin(object = base::charToRaw("abc"), con = path_source)

  sha_source <-
    compute_file_sha256(path_file = path_source)

  path_cache <-
    base::file.path(withr::local_tempdir(), sha_source, "release.qs")

  res <-
    save_release_file(
      url = stringr::str_c(
        "file:///",
        stringr::str_remove(
          base::normalizePath(path_source, winslash = "/"),
          "^/"
        )
      ),
      path_cache = path_cache,
      sha256_expected = sha_source
    )

  testthat::expect_equal(res, path_cache)

  testthat::expect_equal(compute_file_sha256(path_file = res), sha_source)

  testthat::expect_false(
    base::file.exists(stringr::str_c(path_cache, ".partial"))
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_release_file() refuses a changed file", {
  path_source <-
    base::file.path(withr::local_tempdir(), "release.qs")

  base::writeBin(object = base::charToRaw("abd"), con = path_source)

  path_cache <-
    base::file.path(withr::local_tempdir(), "sha", "release.qs")

  testthat::expect_error(
    save_release_file(
      url = stringr::str_c(
        "file:///",
        stringr::str_remove(
          base::normalizePath(path_source, winslash = "/"),
          "^/"
        )
      ),
      path_cache = path_cache,
      sha256_expected = base::strrep("a", 64L)
    ),
    regexp = "release.qs.*checksum"
  )

  testthat::expect_false(base::file.exists(path_cache))

  testthat::expect_false(
    base::file.exists(stringr::str_c(path_cache, ".partial"))
  )
})

testthat::test_that("save_release_file() reports a failed download", {
  dir_missing <-
    base::file.path(withr::local_tempdir(), "missing")

  path_cache <-
    base::file.path(withr::local_tempdir(), "sha", "release.qs")

  testthat::expect_error(
    save_release_file(
      url = stringr::str_c(
        "file:///",
        stringr::str_remove(
          base::normalizePath(dir_missing, winslash = "/", mustWork = FALSE),
          "^/"
        ),
        "/release.qs"
      ),
      path_cache = path_cache,
      sha256_expected = base::strrep("a", 64L)
    ),
    regexp = "could not be downloaded"
  )

  testthat::expect_false(base::file.exists(path_cache))
})

testthat::test_that("save_release_file() replaces a broken cached file", {
  path_source <-
    base::file.path(withr::local_tempdir(), "release.qs")

  base::writeBin(object = base::charToRaw("abc"), con = path_source)

  sha_source <-
    compute_file_sha256(path_file = path_source)

  path_cache <-
    base::file.path(withr::local_tempdir(), sha_source, "release.qs")

  base::dir.create(base::dirname(path_cache), recursive = TRUE)

  base::writeBin(object = base::charToRaw("broken"), con = path_cache)

  save_release_file(
    url = stringr::str_c(
      "file:///",
      stringr::str_remove(
        base::normalizePath(path_source, winslash = "/"),
        "^/"
      )
    ),
    path_cache = path_cache,
    sha256_expected = sha_source
  )

  testthat::expect_equal(
    compute_file_sha256(path_file = path_cache),
    sha_source
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_release_file() validates its arguments", {
  testthat::expect_error(
    save_release_file(
      url = "file:///x",
      path_cache = "x",
      sha256_expected = "abc"
    ),
    regexp = "sha256_expected"
  )

  testthat::expect_error(
    save_release_file(
      url = c("a", "b"),
      path_cache = "x",
      sha256_expected = base::strrep("a", 64L)
    ),
    regexp = "url"
  )
})
