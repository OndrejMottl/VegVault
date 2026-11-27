#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_text_file_sha256() validates its input", {
  dir_files <-
    withr::local_tempdir()

  testthat::expect_error(
    compute_text_file_sha256(path_file = c("a", "b")),
    regexp = "path_file"
  )

  testthat::expect_error(
    compute_text_file_sha256(path_file = NA_character_),
    regexp = "path_file"
  )

  testthat::expect_error(
    compute_text_file_sha256(
      path_file = base::file.path(dir_files, "missing.yml")
    ),
    regexp = "path_file"
  )

  testthat::expect_error(
    compute_text_file_sha256(path_file = dir_files),
    regexp = "path_file"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_text_file_sha256() returns a known checksum", {
  path_file <-
    withr::local_tempfile(fileext = ".R")

  base::writeBin(
    object = base::charToRaw("a\n"),
    con = path_file
  )

  res <-
    compute_text_file_sha256(path_file = path_file)

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  # SHA-256 of the two bytes "a" and LF
  testthat::expect_equal(
    res,
    "87428fc522803d31065e7bce3cf03fe475096631e5e07bbd7a0fde60c4cf25c7"
  )
})

testthat::test_that("compute_text_file_sha256() ignores CRLF line endings", {
  path_lf <-
    withr::local_tempfile(fileext = ".yml")

  path_crlf <-
    withr::local_tempfile(fileext = ".yml")

  base::writeBin(
    object = base::charToRaw("id: one\nversion: 1.0.0\n"),
    con = path_lf
  )

  base::writeBin(
    object = base::charToRaw("id: one\r\nversion: 1.0.0\r\n"),
    con = path_crlf
  )

  res_lf <-
    compute_text_file_sha256(path_file = path_lf)

  res_crlf <-
    compute_text_file_sha256(path_file = path_crlf)

  testthat::expect_equal(res_crlf, res_lf)

  testthat::expect_match(res_lf, "^[0-9a-f]{64}$")
})

testthat::test_that("compute_text_file_sha256() detects changed text", {
  path_first <-
    withr::local_tempfile(fileext = ".yml")

  path_second <-
    withr::local_tempfile(fileext = ".yml")

  base::writeBin(
    object = base::charToRaw("version: 1.0.0\n"),
    con = path_first
  )

  base::writeBin(
    object = base::charToRaw("version: 1.0.1\n"),
    con = path_second
  )

  testthat::expect_false(
    compute_text_file_sha256(path_file = path_first) ==
      compute_text_file_sha256(path_file = path_second)
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("compute_text_file_sha256() keeps a CR without LF", {
  path_lone_cr <-
    withr::local_tempfile(fileext = ".R")

  path_plain <-
    withr::local_tempfile(fileext = ".R")

  base::writeBin(
    object = base::charToRaw("a\rb\n"),
    con = path_lone_cr
  )

  base::writeBin(
    object = base::charToRaw("ab\n"),
    con = path_plain
  )

  testthat::expect_false(
    compute_text_file_sha256(path_file = path_lone_cr) ==
      compute_text_file_sha256(path_file = path_plain)
  )
})

testthat::test_that("compute_text_file_sha256() hashes an empty file", {
  path_empty <-
    withr::local_tempfile(fileext = ".R")

  base::file.create(path_empty)

  # SHA-256 of zero bytes
  testthat::expect_equal(
    compute_text_file_sha256(path_file = path_empty),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
})
