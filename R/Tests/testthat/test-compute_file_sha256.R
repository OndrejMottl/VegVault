#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_file_sha256() hashes the file bytes", {
  path_file <-
    base::file.path(withr::local_tempdir(), "abc.bin")

  base::writeBin(object = base::charToRaw("abc"), con = path_file)

  # The SHA-256 test vector of "abc" (FIPS 180-2)
  testthat::expect_equal(
    compute_file_sha256(path_file = path_file),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})

testthat::test_that("compute_file_sha256() changes with one byte", {
  path_file <-
    base::file.path(withr::local_tempdir(), "abd.bin")

  base::writeBin(object = base::charToRaw("abd"), con = path_file)

  testthat::expect_false(
    compute_file_sha256(path_file = path_file) ==
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_file_sha256() needs an existing file", {
  testthat::expect_error(
    compute_file_sha256(
      path_file = base::file.path(withr::local_tempdir(), "missing.bin")
    ),
    regexp = "path_file"
  )

  testthat::expect_error(
    compute_file_sha256(path_file = c("a", "b")),
    regexp = "path_file"
  )
})
