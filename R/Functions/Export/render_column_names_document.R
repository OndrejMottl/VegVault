#' @title Render the column names of all tables as a Word document
#' @description
#' Write `<dir_export>/Column_names/VegVault_column_names.docx`: one table
#' per database table with the column names, their types and an empty
#' `Description` column to be filled in by hand, preceded by a note on how
#' the position tables link samples to gridpoints when they are exported.
#' @param data_column_types
#' A tibble with the columns `table_name`, `column_name` and `data_type`,
#' covering every exported table (see `load_table_column_types()`).
#' @param dir_export
#' Character scalar. Folder of the flat-file export (see
#' `resolve_output_dir()`). The `Column_names` folder in it is created when
#' missing.
#' @param dir_pandoc
#' Character scalar. Folder of the `pandoc` executable used for rendering
#' (see `resolve_pandoc_dir()`).
#' @return
#' Character scalar: the path of the document, so that the function can be
#' the command of a `{targets}` target with `format = "file"`.
#' @details
#' Tables appear in the order of `data_column_types`, each captioned
#' `Table X: Column names and types for table <name>` as in the v1 export.
#' When `Positions`, `SamplePosition` and `PositionLink` are all among the
#' tables, the document starts with the section "Links between samples and
#' gridpoints": it explains the three tables and gives the SQL join that
#' yields one row per sample and linked gridpoint, the rows of the view
#' `AbioticDataReference`, which the flat files leave out (see
#' `load_database_table_names()`). Renders with `arsenal::write2word()`,
#' after pointing `rmarkdown` at `dir_pandoc` for the rest of the R
#' session. The document is always
#' written, replacing an existing one: in the pipeline, `{targets}` decides
#' when it is written again (see `build_export_cue()`). Aborts before
#' writing anything when `dir_pandoc` holds no `pandoc` executable.
#' @examples
#' \dontrun{
#' path_docx <-
#'   render_column_names_document(
#'     data_column_types = data_column_types,
#'     dir_export = dir_export,
#'     dir_pandoc = resolve_pandoc_dir()
#'   )
#' }
render_column_names_document <- function(
  data_column_types,
  dir_export,
  dir_pandoc
) {
  vec_columns_required <-
    c("table_name", "column_name", "data_type")

  assertthat::assert_that(
    base::is.data.frame(data_column_types),
    base::all(vec_columns_required %in% base::names(data_column_types)),
    base::nrow(data_column_types) > 0L,
    msg = stringr::str_c(
      "`data_column_types` must have the columns `table_name`, ",
      "`column_name` and `data_type`, and at least one row."
    )
  )

  assertthat::assert_that(
    base::is.character(dir_export),
    base::length(dir_export) == 1L,
    !base::is.na(dir_export),
    base::nzchar(dir_export),
    base::is.character(dir_pandoc),
    base::length(dir_pandoc) == 1L,
    !base::is.na(dir_pandoc),
    msg = "`dir_export` and `dir_pandoc` must be character scalars."
  )

  # Checked here, because rmarkdown would otherwise fall back to a pandoc
  #   found earlier in the session
  if (
    !base::any(
      base::file.exists(base::file.path(dir_pandoc, c("pandoc.exe", "pandoc")))
    )
  ) {
    cli::cli_abort(
      "No pandoc executable in {.arg dir_pandoc}."
    )
  }

  dir_column_names <-
    base::file.path(dir_export, "Column_names")

  path_docx <-
    base::file.path(dir_column_names, "VegVault_column_names.docx")

  # The tables and captions of the v1 export
  list_tables <-
    data_column_types |>
    dplyr::pull(table_name) |>
    base::unique() |>
    purrr::set_names() |>
    purrr::map(
      .f = ~ data_column_types |>
        dplyr::filter(table_name == .x) |>
        dplyr::select(
          `Column name` = column_name,
          `Data type` = data_type
        ) |>
        dplyr::mutate(Description = NA_character_) |>
        knitr::kable(
          caption = stringr::str_c(
            "Table X: Column names and types for table ",
            .x
          ),
          align = "l"
        )
    )

  # Since 2.0.0 the links are stored once per position, so the flat files
  #   hold three position tables instead of the view that joins them; the
  #   note says how to rebuild the view's rows
  vec_tables_position <-
    c("Positions", "SamplePosition", "PositionLink")

  flag_position_note <-
    base::all(
      vec_tables_position %in% dplyr::pull(data_column_types, table_name)
    )

  list_note <-
    if (
      flag_position_note
    ) {
      base::list(
        position_links = stringr::str_c(
          "## Links between samples and gridpoints\n\n",
          "The links between samples and gridpoints are stored once per ",
          "position, not once per sample. `SamplePosition` gives the ",
          "position (`position_id`) of every sample that is not a ",
          "gridpoint. `Positions` holds the longitude, latitude and age of ",
          "each position. `PositionLink` lists the gridpoint samples ",
          "(`sample_ref_id`) linked to each position, with their distance ",
          "in kilometres (`distance_in_km`) and in years ",
          "(`distance_in_years`).\n\n",
          "To get one row per sample and linked gridpoint, as in the table ",
          "AbioticDataReference of VegVault 1.0.0, join `SamplePosition` ",
          "to `PositionLink` on `position_id`:\n\n",
          "    SELECT sp.sample_id, pl.sample_ref_id,\n",
          "           pl.distance_in_km, pl.distance_in_years\n",
          "    FROM SamplePosition AS sp\n",
          "    JOIN PositionLink AS pl ON pl.position_id = sp.position_id\n\n",
          "The SQLite database provides the same rows as the view ",
          "AbioticDataReference. The flat files leave that view out, ",
          "because it repeats the links of a position for every sample ",
          "there.\n"
        )
      )
    } else {
      base::list()
    }

  rmarkdown::find_pandoc(
    cache = FALSE,
    dir = dir_pandoc
  )

  base::dir.create(
    path = dir_column_names,
    recursive = TRUE,
    showWarnings = FALSE
  )

  # `quiet` is passed on to rmarkdown::render()
  arsenal::write2word(
    object = c(list_note, list_tables),
    file = path_docx,
    quiet = TRUE
  )

  res <- path_docx

  return(res)
}
