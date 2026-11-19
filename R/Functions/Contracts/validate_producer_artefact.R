#' @title Validate a producer artefact against its contract
#' @description
#' Check one producer artefact, given either as files or as objects in
#' memory, against its contract in `Data/Contracts/`, and stop with a list
#' of every violation when it does not satisfy the contract.
#' @param contract
#' A contract as returned by `load_producer_contract()`, or the path to a
#' contract file, which is then loaded.
#' @param data_artefact
#' The artefact in memory: a data frame, or a named list of data frames
#' whose names are file base names (see `diagnose_producer_artefact()`).
#' Give exactly one of `data_artefact` and `path_artefact`.
#' @param path_artefact
#' Character vector of paths to every file of the artefact (every
#' partition and, for contracts with variables, every variable or every
#' variable in `vec_variables`). Files ending in `.qs` are read with
#' `qs2::qs_read()` and files ending in `.rds` with `readRDS()`.
#' @param vec_variables
#' Character vector of the variables to validate, for contracts with
#' `variables` that are validated one or some variables at a time; `NULL`
#' (default) expects every variable of the contract.
#' @param verbose
#' Logical. If `TRUE` (default), a success message is printed via `cli`.
#' @return
#' Invisibly, the artefact unchanged: `data_artefact` as given, or, for
#' `path_artefact`, a named list of the objects read, named by file base
#' name, in the order of `path_artefact`.
#' @details
#' Violations are found with `diagnose_producer_artefact()`; a file that
#' cannot be read, or has another extension, is reported as
#' `file_unreadable`, and an empty list as `no_files`. When any violation
#' is found the function aborts with an error of class
#' `producer_contract_error` that names the contract, each file and column
#' and the violated rule, and carries the full findings tibble in its
#' field `findings`. The message lists at most 50 findings. The function
#' never writes to a database or a file and never changes the data.
#' @examples
#' \dontrun{
#' validate_producer_artefact(
#'   contract = here::here("Data", "Contracts", "splot_plots.yml"),
#'   path_artefact = vec_paths_splot
#' )
#' }
validate_producer_artefact <- function(
  contract,
  data_artefact = NULL,
  path_artefact = NULL,
  vec_variables = NULL,
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.null(data_artefact) != base::is.null(path_artefact),
    msg = "Give exactly one of 'data_artefact' and 'path_artefact'."
  )

  assertthat::assert_that(
    base::is.null(path_artefact) ||
      (
        base::is.character(path_artefact) &&
          base::length(path_artefact) > 0L &&
          base::all(base::file.exists(path_artefact))
      ),
    msg = "'path_artefact' must be paths to existing files."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "'verbose' must be TRUE or FALSE."
  )

  contract_loaded <-
    if (
      base::is.character(contract)
    ) {
      load_producer_contract(path_contract = contract)
    } else {
      contract
    }

  assertthat::assert_that(
    base::is.list(contract_loaded),
    base::is.character(purrr::pluck(contract_loaded, "contract_id")),
    msg = "'contract' must be a loaded contract or a contract file path."
  )

  vec_table_variables <-
    purrr::pluck(
      contract_loaded, "variables", "table",
      .default = base::list()
    ) |>
    purrr::map_chr(.f = ~ base::as.character(purrr::chuck(.x, "variable")))

  assertthat::assert_that(
    base::is.null(vec_variables) ||
      (
        base::is.character(vec_variables) &&
          base::length(vec_variables) > 0L &&
          base::all(vec_variables %in% vec_table_variables)
      ),
    msg = "'vec_variables' must be NULL or variables of the contract."
  )

  contract_id <-
    purrr::chuck(contract_loaded, "contract_id")

  contract_version <-
    purrr::chuck(contract_loaded, "contract_version")

  #--------------------------------------------------#
  ## Read files -----
  #--------------------------------------------------#

  vec_file_names <-
    if (
      base::is.null(path_artefact)
    ) {
      base::character(0)
    } else {
      base::basename(path_artefact)
    }

  # One entry per file: the object read, or the reason it could not be
  list_read <-
    purrr::map(
      .x = path_artefact,
      .f = ~ {
        path_file <- .x

        extension_file <-
          stringr::str_extract(path_file, "(?<=[.])[^.]+$")

        base::tryCatch(
          expr = base::list(
            object = base::switch(
              base::ifelse(
                extension_file %in% c("qs", "rds"),
                extension_file,
                "other"
              ),
              "qs" = qs2::qs_read(file = path_file, validate_checksum = TRUE),
              "rds" = base::readRDS(file = path_file),
              "other" = cli::cli_abort("Extension is not .qs or .rds.")
            ),
            problem = NA_character_
          ),
          error = function(error) {
            base::list(
              object = NULL,
              problem = base::conditionMessage(error)
            )
          }
        )
      }
    )

  vec_problems <-
    purrr::map_chr(
      .x = list_read,
      .f = ~ purrr::chuck(.x, "problem")
    )

  is_readable <-
    base::is.na(vec_problems)

  data_findings_read <-
    build_producer_findings(
      contract_id = contract_id,
      check = base::rep("file_unreadable", base::sum(!is_readable)),
      message = stringr::str_c(
        "File cannot be read: ",
        stringr::str_squish(vec_problems[!is_readable])
      ),
      file_name = vec_file_names[!is_readable]
    )

  data_checked <-
    if (
      base::is.null(path_artefact)
    ) {
      data_artefact
    } else {
      list_read[is_readable] |>
        purrr::map(.f = ~ purrr::pluck(.x, "object")) |>
        rlang::set_names(vec_file_names[is_readable])
    }

  #--------------------------------------------------#
  ## Diagnose and report -----
  #--------------------------------------------------#

  # An empty list has nothing to diagnose: it is reported as no files,
  #   unless every file was unreadable and has been reported already
  flag_empty_list <-
    !base::is.data.frame(data_checked) &&
    base::length(data_checked) == 0L

  data_findings_content <-
    if (
      !flag_empty_list
    ) {
      diagnose_producer_artefact(
        data_artefact = data_checked,
        contract = contract_loaded,
        vec_variables = vec_variables
      )
    } else if (
      base::nrow(data_findings_read) == 0L
    ) {
      build_producer_findings(
        contract_id = contract_id,
        check = "no_files",
        message = "No files or objects were given for the artefact."
      )
    }

  data_findings <-
    dplyr::bind_rows(
      build_producer_findings(
        contract_id = contract_id,
        check = base::character(0),
        message = base::character(0)
      ),
      data_findings_read,
      data_findings_content
    )

  n_findings <-
    base::nrow(data_findings)

  if (
    n_findings > 0L
  ) {
    vec_lines <-
      stringr::str_c(
        dplyr::coalesce(dplyr::pull(data_findings, "file_name"), "(artefact)"),
        " | ",
        dplyr::coalesce(dplyr::pull(data_findings, "column"), "-"),
        " | ",
        dplyr::pull(data_findings, "check"),
        ": ",
        dplyr::pull(data_findings, "message")
      )

    vec_lines_shown <-
      c(
        utils::head(vec_lines, 50L),
        if (
          n_findings > 50L
        ) {
          stringr::str_c(
            "... and ", n_findings - 50L, " more; see the error's findings."
          )
        }
      )

    # Messages may quote file-name templates such as {date}; cli would read
    #   braces as glue expressions, so they are doubled
    vec_lines_escaped <-
      vec_lines_shown |>
      stringr::str_replace_all(
        pattern = stringr::fixed("{"),
        replacement = "{{"
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("}"),
        replacement = "}}"
      ) |>
      rlang::set_names("x")

    cli::cli_abort(
      c(
        "Producer artefact {.val {contract_id}} violates contract version
        {contract_version}: {n_findings} problem{?s}.",
        vec_lines_escaped
      ),
      class = "producer_contract_error",
      findings = data_findings
    )
  }

  if (
    base::isTRUE(verbose)
  ) {
    n_objects <-
      base::ifelse(
        base::is.data.frame(data_checked),
        1L,
        base::length(data_checked)
      )

    cli::cli_alert_success(
      "Producer artefact {.val {contract_id}} satisfies contract version
      {contract_version} ({n_objects} object{?s})."
    )
  }

  res <- data_checked

  return(base::invisible(res))
}
