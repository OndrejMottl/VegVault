load_local_trait_artifacts <- function(
    file_prefix,
    producer_root = base::file.path(
      base::dirname(here::here()),
      "VegVault-Trait_data"
    )) {
  path_output <- base::file.path(producer_root, "Outputs", "Data")
  vec_paths <-
    base::list.files(
      path_output,
      pattern = base::paste0("^", file_prefix, ".*[.]qs$"),
      full.names = TRUE
    )

  if (base::length(vec_paths) == 0L) {
    cli::cli_abort("No local producer artifacts match {.file {file_prefix}}.")
  }

  data_file_inventory <-
    tibble::tibble(
      path = vec_paths,
      modified = base::file.info(vec_paths)$mtime,
      partition = stringr::str_match(
        base::basename(vec_paths),
        base::paste0("^", file_prefix, "([0-9]+)_")
      )[, 2]
    )

  data_selected_files <-
    if (base::all(base::is.na(data_file_inventory$partition))) {
      data_file_inventory %>%
      dplyr::slice_max(.data$modified, n = 1L, with_ties = FALSE)
  } else {
      data_file_inventory %>%
      dplyr::filter(!base::is.na(.data$partition)) %>%
      dplyr::group_by(.data$partition) %>%
      dplyr::slice_max(.data$modified, n = 1L, with_ties = FALSE) %>%
      dplyr::ungroup() %>%
      dplyr::arrange(base::as.integer(.data$partition))
  }

  data_result <-
    data_selected_files$path %>%
    purrr::map(qs::qread) %>%
    dplyr::bind_rows()

  vec_required <-
    c(
      "source_provider", "source_dataset_key", "source_record_id",
      "source_trait_id", "original_value_string", "original_unit",
      "normalized_original_unit", "conversion_rule_key",
      "conversion_status", "disposition", "derivation_rule_key",
      "trait_value", "trait_unit"
    )
  vec_missing <- base::setdiff(vec_required, base::names(data_result))

  if (base::length(vec_missing) > 0L) {
    cli::cli_abort(
      c(
        "Local producer artifacts predate the v2 trait contract.",
        "x" = "Missing columns: {vec_missing}."
      )
    )
  }
  if (!base::all(data_result$disposition == "published")) {
    cli::cli_abort("Integration artifacts may contain only published rows.")
  }

  data_result_with_provenance <-
    structure(
      data_result,
      producer_files = data_selected_files$path
    )

  return(data_result_with_provenance)
}
