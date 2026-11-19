#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("render_column_names_document() writes the document", {
  dir_pandoc <-
    base::tryCatch(
      expr = resolve_pandoc_dir(),
      error = function(cnd) {
        NULL
      }
    )

  testthat::skip_if(
    base::is.null(dir_pandoc),
    message = "Quarto and its pandoc are not available"
  )

  dir_export <-
    withr::local_tempdir()

  data_column_types <-
    tibble::tibble(
      table_name = c("Samples", "Datasets", "Datasets"),
      column_name = c("sample_id", "dataset_id", "dataset_name"),
      data_type = c("integer", "integer", "character")
    )

  res <-
    render_column_names_document(
      data_column_types = data_column_types,
      dir_export = dir_export,
      dir_pandoc = dir_pandoc
    )

  path_docx <-
    base::file.path(
      dir_export,
      "Column_names",
      "VegVault_column_names.docx"
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(res, path_docx)

  testthat::expect_true(base::file.exists(path_docx))

  dir_unzipped <-
    withr::local_tempdir()

  utils::unzip(
    zipfile = path_docx,
    files = "word/document.xml",
    exdir = dir_unzipped
  )

  text_document <-
    base::readLines(
      con = base::file.path(dir_unzipped, "word", "document.xml"),
      warn = FALSE,
      encoding = "UTF-8"
    ) |>
    stringr::str_c(collapse = "")

  # Captions follow the order of the input, Samples before Datasets
  vec_caption_position <-
    stringr::str_locate(
      string = text_document,
      pattern = stringr::str_c(
        "Column names and types for table ",
        c("Samples", "Datasets")
      )
    )[, "start"]

  testthat::expect_true(base::all(!base::is.na(vec_caption_position)))

  testthat::expect_true(vec_caption_position[1] < vec_caption_position[2])

  testthat::expect_true(
    stringr::str_detect(text_document, "dataset_name")
  )

  testthat::expect_true(
    stringr::str_detect(text_document, "Description")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("render_column_names_document() replaces a document", {
  dir_pandoc <-
    base::tryCatch(
      expr = resolve_pandoc_dir(),
      error = function(cnd) {
        NULL
      }
    )

  testthat::skip_if(
    base::is.null(dir_pandoc),
    message = "Quarto and its pandoc are not available"
  )

  dir_export <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_export, "Column_names"))

  path_docx <-
    base::file.path(
      dir_export,
      "Column_names",
      "VegVault_column_names.docx"
    )

  base::writeLines(text = "old content", con = path_docx)

  render_column_names_document(
    data_column_types = tibble::tibble(
      table_name = "Datasets",
      column_name = "dataset_id",
      data_type = "integer"
    ),
    dir_export = dir_export,
    dir_pandoc = dir_pandoc
  )

  # A Word document is a zip archive, which starts with "PK"
  vec_bytes_start <-
    base::readBin(con = path_docx, what = "raw", n = 2L)

  testthat::expect_equal(base::rawToChar(vec_bytes_start), "PK")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("render_column_names_document() validates arguments", {
  data_column_types <-
    tibble::tibble(
      table_name = "Datasets",
      column_name = "dataset_id",
      data_type = "integer"
    )

  testthat::expect_error(
    render_column_names_document(
      data_column_types = tibble::tibble(table_name = "Datasets"),
      dir_export = withr::local_tempdir(),
      dir_pandoc = withr::local_tempdir()
    ),
    regexp = "data_column_types"
  )

  testthat::expect_error(
    render_column_names_document(
      data_column_types = tibble::tibble(
        table_name = base::character(0),
        column_name = base::character(0),
        data_type = base::character(0)
      ),
      dir_export = withr::local_tempdir(),
      dir_pandoc = withr::local_tempdir()
    ),
    regexp = "data_column_types"
  )

  # An empty folder holds no pandoc, and nothing is written
  dir_export <-
    withr::local_tempdir()

  testthat::expect_error(
    render_column_names_document(
      data_column_types = data_column_types,
      dir_export = dir_export,
      dir_pandoc = withr::local_tempdir()
    ),
    regexp = "pandoc"
  )

  testthat::expect_equal(base::list.files(dir_export), base::character(0))
})
