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

testthat::test_that("render_column_names_document() explains position links", {
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

  data_column_types <-
    tibble::tibble(
      table_name = c("PositionLink", "Positions", "SamplePosition", "Samples"),
      column_name = c("position_id", "position_id", "sample_id", "sample_id"),
      data_type = "integer"
    )

  dir_with_positions <-
    withr::local_tempdir()

  dir_without_positions <-
    withr::local_tempdir()

  render_column_names_document(
    data_column_types = data_column_types,
    dir_export = dir_with_positions,
    dir_pandoc = dir_pandoc
  )

  render_column_names_document(
    data_column_types = dplyr::filter(
      data_column_types,
      table_name == "Samples"
    ),
    dir_export = dir_without_positions,
    dir_pandoc = dir_pandoc
  )

  vec_text_document <-
    purrr::map_chr(
      .x = c(dir_with_positions, dir_without_positions),
      .f = ~ {
        dir_unzipped <-
          withr::local_tempdir()

        utils::unzip(
          zipfile = base::file.path(
            .x,
            "Column_names",
            "VegVault_column_names.docx"
          ),
          files = "word/document.xml",
          exdir = dir_unzipped
        )

        base::readLines(
          con = base::file.path(dir_unzipped, "word", "document.xml"),
          warn = FALSE,
          encoding = "UTF-8"
        ) |>
          stringr::str_c(collapse = "")
      }
    )

  text_with_positions <-
    vec_text_document[1]

  text_without_positions <-
    vec_text_document[2]

  # The note comes before the first table and gives the join of the view
  #   that the flat files leave out
  position_note <-
    stringr::str_locate(
      string = text_with_positions,
      pattern = "Links between samples and gridpoints"
    )[, "start"]

  position_first_caption <-
    stringr::str_locate(
      string = text_with_positions,
      pattern = "Column names and types for table"
    )[, "start"]

  testthat::expect_false(base::is.na(position_note))

  testthat::expect_true(position_note < position_first_caption)

  testthat::expect_true(
    stringr::str_detect(text_with_positions, "AbioticDataReference")
  )

  testthat::expect_true(
    stringr::str_detect(text_with_positions, "JOIN PositionLink")
  )

  # Without the position tables there is nothing to explain
  testthat::expect_false(
    stringr::str_detect(
      text_without_positions,
      "Links between samples and gridpoints"
    )
  )
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
