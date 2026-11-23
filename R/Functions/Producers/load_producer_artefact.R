#' @title Load the files of a resolved producer artefact
#' @description
#' Read every file of one artefact, as resolved by
#' `resolve_producer_artefact()`, with the reader its format needs.
#' @param data_files
#' A data frame as returned by `resolve_producer_artefact()`, with at least
#' the columns `file_name`, `path` and `format`.
#' @param contract
#' The artefact's contract, as returned by `load_producer_contract()`, or
#' `NULL` (default). Required when a file has the format `"csv"`, whose
#' columns are read with the contract's classes.
#' @return
#' A named list with one object per file, named by `file_name` in the order
#' of `data_files`: the form `validate_producer_artefact()` accepts as
#' `data_artefact`.
#' @details
#' `"qs2"` files are read with `qs2::qs_read()`, `"rds"` files with
#' `readRDS()` and `"csv"` files with `load_producer_csv()`. The format
#' comes from the resolved files, never from the file name. The provenance
#' (tag, checksum, size) stays in `data_files`, which the pipeline keeps as
#' its own target. Aborts for another format, and for a `"csv"` file
#' without `contract`. Checksums are verified by
#' `resolve_producer_artefact()`, not here: a file changed after it was
#' resolved is read as it is.
#' @examples
#' \dontrun{
#' list_splot <-
#'   load_producer_artefact(data_files = data_files_splot)
#' }
load_producer_artefact <- function(
  data_files,
  contract = NULL
) {
  validate_data_columns(
    data_source = data_files,
    vec_columns_required = c("file_name", "path", "format"),
    name_argument = "data_files"
  )

  vec_formats <-
    dplyr::pull(data_files, format)

  vec_formats_unknown <-
    base::setdiff(vec_formats, c("qs2", "rds", "csv"))

  if (
    base::length(vec_formats_unknown) > 0L
  ) {
    cli::cli_abort(
      "Unknown file format {.val {vec_formats_unknown}}; known are
      {.val qs2}, {.val rds} and {.val csv}."
    )
  }

  if (
    "csv" %in% vec_formats && base::is.null(contract)
  ) {
    cli::cli_abort(
      "A {.val csv} file is read with the column classes of its contract;
      give {.arg contract}."
    )
  }

  vec_paths <-
    dplyr::pull(data_files, path)

  res <-
    purrr::map(
      .x = base::seq_along(vec_paths),
      .f = ~ base::switch(
        vec_formats[.x],
        "qs2" = qs2::qs_read(file = vec_paths[.x]),
        "rds" = base::readRDS(file = vec_paths[.x]),
        "csv" = load_producer_csv(
          path_file = vec_paths[.x],
          contract = contract
        )
      )
    ) |>
    rlang::set_names(dplyr::pull(data_files, file_name))

  return(res)
}
