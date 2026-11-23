#' @title Build the producer pins of a database build
#' @description
#' Turn the resolved files of every producer artefact into the record of
#' producer pins that the build manifest keeps: per artefact the contract
#' version, the mode, the tag, the number of rows handed on, and the name,
#' size and SHA-256 of every file.
#' @param list_data_files
#' List of data frames, each as returned by `resolve_producer_artefact()`
#' for one artefact.
#' @param data_manifest
#' The producer manifest as returned by `load_producer_manifest()`, with at
#' least `artefact_id` and `contract_version`.
#' @param vec_n_rows
#' Named numeric vector, one whole, non-negative number per artefact of
#' `list_data_files`, named by artefact id: the rows stage 01 hands on
#' (`compute_artefact_rows()`, after the subset cut, summed over the
#' variables of an artefact with variables).
#' @return
#' A list with one element per artefact, in the order of
#' `list_data_files`, each a list of `artefact_id`, `contract_version`,
#' `mode`, `tag` (`NULL` in the `dev` mode), `n_rows` and `files` (a list
#' of lists of `file_name`, `size` and `sha256`): the form
#' `save_build_manifest()` writes as `producer_pins`.
#' @details
#' File paths are not recorded, because they are machine-local. Aborts when
#' a data frame holds no files or more than one artefact, when an artefact
#' is listed twice, when an artefact is not in `data_manifest`, or when
#' `vec_n_rows` does not give exactly one whole, non-negative count per
#' artefact. The validation stage compares `n_rows` with the rows the
#' database holds (`diagnose_trait_value_counts()`).
#' @examples
#' \dontrun{
#' list_producer_pins <-
#'   build_producer_pins(
#'     list_data_files = list(data_files_splot_plots, data_files_bien_plots),
#'     data_manifest = data_producer_manifest,
#'     vec_n_rows = c(splot_plots = 67022, bien_plots = 24161)
#'   )
#' }
build_producer_pins <- function(
  list_data_files,
  data_manifest,
  vec_n_rows
) {
  assertthat::assert_that(
    base::is.list(list_data_files),
    !base::is.data.frame(list_data_files),
    base::length(list_data_files) > 0L,
    base::all(purrr::map_lgl(.x = list_data_files, .f = base::is.data.frame)),
    msg = "`list_data_files` must be a non-empty list of data frames."
  )

  validate_data_columns(
    data_source = data_manifest,
    vec_columns_required = c("artefact_id", "contract_version"),
    name_argument = "data_manifest"
  )

  purrr::walk(
    .x = list_data_files,
    .f = ~ validate_data_columns(
      data_source = .x,
      vec_columns_required = c(
        "artefact_id", "mode", "tag", "file_name", "size", "sha256"
      ),
      name_argument = "list_data_files"
    )
  )

  vec_n_artefacts <-
    purrr::map_int(
      .x = list_data_files,
      .f = ~ base::length(base::unique(dplyr::pull(.x, artefact_id)))
    )

  if (
    base::any(vec_n_artefacts != 1L)
  ) {
    cli::cli_abort(
      "Each data frame of {.arg list_data_files} must hold the files of one
        artefact."
    )
  }

  vec_artefact_ids <-
    purrr::map_chr(
      .x = list_data_files,
      .f = ~ base::unique(dplyr::pull(.x, artefact_id))
    )

  vec_ids_repeated <-
    vec_artefact_ids[base::duplicated(vec_artefact_ids)] |>
    base::unique()

  if (
    base::length(vec_ids_repeated) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_ids_repeated}} {?is/are} listed more than once."
    )
  }

  vec_ids_unknown <-
    base::setdiff(vec_artefact_ids, dplyr::pull(data_manifest, artefact_id))

  if (
    base::length(vec_ids_unknown) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_ids_unknown}} {?is/are} not in the producer manifest."
    )
  }

  vec_names_rows <-
    base::names(vec_n_rows)

  assertthat::assert_that(
    base::is.numeric(vec_n_rows),
    !base::is.null(vec_names_rows),
    !base::anyDuplicated(vec_names_rows),
    base::setequal(vec_names_rows, vec_artefact_ids),
    base::all(base::is.finite(vec_n_rows)),
    base::all(vec_n_rows >= 0),
    base::all(vec_n_rows == base::round(vec_n_rows)),
    msg = stringr::str_c(
      "`vec_n_rows` must give one whole, non-negative number of rows per ",
      "artefact, named by artefact id."
    )
  )

  res <-
    purrr::map2(
      .x = list_data_files,
      .y = vec_artefact_ids,
      .f = ~ {
        sel_artefact_id <- .y

        value_tag <-
          dplyr::pull(.x, tag) |>
          base::unique()

        list(
          artefact_id = sel_artefact_id,
          contract_version = data_manifest |>
            dplyr::filter(artefact_id == sel_artefact_id) |>
            dplyr::pull(contract_version),
          mode = base::unique(dplyr::pull(.x, mode)),
          # NULL is written as YAML null; a dev pin has no tag
          tag = if (
            base::all(base::is.na(value_tag))
          ) {
            NULL
          } else {
            value_tag
          },
          n_rows = base::unname(vec_n_rows[sel_artefact_id]),
          files = purrr::pmap(
            .l = list(
              file_name = dplyr::pull(.x, file_name),
              size = dplyr::pull(.x, size),
              sha256 = dplyr::pull(.x, sha256)
            ),
            .f = list
          )
        )
      }
    )

  return(res)
}
