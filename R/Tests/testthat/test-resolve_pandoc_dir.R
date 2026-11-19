#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_pandoc_dir() finds the pandoc of Quarto", {
  dir_quarto <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_quarto, "tools"))

  path_quarto <-
    base::file.path(dir_quarto, "quarto.exe")

  base::writeLines(text = "fake", con = path_quarto)

  base::writeLines(
    text = "fake",
    con = base::file.path(dir_quarto, "tools", "pandoc.exe")
  )

  res <-
    resolve_pandoc_dir(path_quarto = c(quarto = path_quarto))

  testthat::expect_type(res, "character")

  testthat::expect_null(base::names(res))

  testthat::expect_equal(
    res,
    base::normalizePath(
      base::file.path(dir_quarto, "tools"),
      winslash = "/"
    )
  )
})

testthat::test_that("resolve_pandoc_dir() accepts pandoc without .exe", {
  dir_quarto <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_quarto, "tools"))

  path_quarto <-
    base::file.path(dir_quarto, "quarto")

  base::writeLines(text = "fake", con = path_quarto)

  base::writeLines(
    text = "fake",
    con = base::file.path(dir_quarto, "tools", "pandoc")
  )

  res <-
    resolve_pandoc_dir(path_quarto = path_quarto)

  testthat::expect_match(res, "/tools$")
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("resolve_pandoc_dir() aborts without Quarto", {
  testthat::expect_error(
    resolve_pandoc_dir(path_quarto = c(quarto = "")),
    regexp = "Quarto"
  )
})

testthat::test_that("resolve_pandoc_dir() aborts without its pandoc", {
  dir_quarto <-
    withr::local_tempdir()

  path_quarto <-
    base::file.path(dir_quarto, "quarto.exe")

  base::writeLines(text = "fake", con = path_quarto)

  testthat::expect_error(
    resolve_pandoc_dir(path_quarto = path_quarto),
    regexp = "pandoc"
  )
})

testthat::test_that("resolve_pandoc_dir() validates its input", {
  testthat::expect_error(
    resolve_pandoc_dir(path_quarto = c("a", "b")),
    regexp = "path_quarto"
  )
})
