#' @title Load a producer CSV file with the classes of its contract
#' @description
#' Read one CSV file of a producer artefact, such as a rule registry kept
#' in the producer repository, giving each column the class its contract
#' describes.
#' @param path_file
#' Character scalar. Path of an existing CSV file.
#' @param contract
#' The artefact's contract, as returned by `load_producer_contract()`.
#' @return
#' A tibble with one row per data line and the columns of the file, in the
#' file's order.
#' @details
#' A column the contract describes is read as its `class`: `character`,
#' `numeric` or `double` (double), `integer`, `logical` or `Date`
#' (`YYYY-MM-DD`). Every other column is read as text. Empty fields and
#' `NA` are missing values. A column the contract lists but the file lacks
#' is not read; `validate_producer_artefact()` reports it. Aborts, naming
#' the file, row, column and value, when a value cannot be read as its
#' class, and aborts when a column of the file has a class that a CSV file
#' cannot hold (`list`, `data.frame`, `matrix` or `factor`). The file is
#' read completely, so it is not left open.
#' @seealso [validate_producer_artefact()], which reads `.csv` files with
#' this function
#' @examples
#' \dontrun{
#' data_conversions <-
#'   load_producer_csv(
#'     path_file = here::here(
#'       "config", "trait_units", "unit_conversions.csv"
#'     ),
#'     contract = load_producer_contract(
#'       path_contract = here::here(
#'         "Data", "Contracts", "trait_unit_conversions.yml"
#'       )
#'     )
#'   )
#' }
load_producer_csv <- function(
  path_file,
  contract
) {
  assertthat::assert_that(
    base::is.character(path_file),
    base::length(path_file) == 1L,
    !base::is.na(path_file),
    base::file.exists(path_file),
    !base::dir.exists(path_file),
    msg = "`path_file` must be the path of an existing file."
  )

  assertthat::assert_that(
    base::is.list(contract),
    base::is.list(purrr::pluck(contract, "columns")),
    base::is.character(purrr::pluck(contract, "contract_id")),
    msg = "`contract` must be a contract from load_producer_contract()."
  )

  file_name <-
    base::basename(path_file)

  list_columns <-
    purrr::chuck(contract, "columns")

  vec_classes <-
    purrr::map_chr(
      .x = list_columns,
      .f = ~ purrr::chuck(.x, "class")
    ) |>
    rlang::set_names(
      purrr::map_chr(
        .x = list_columns,
        .f = ~ purrr::chuck(.x, "name")
      )
    )

  # Only the columns the file has, so a missing one gives no warning here
  vec_names_file <-
    readr::read_csv(
      file = path_file,
      n_max = 0L,
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE,
      progress = FALSE,
      lazy = FALSE
    ) |>
    base::names()

  vec_classes_file <-
    vec_classes[base::names(vec_classes) %in% vec_names_file]

  vec_classes_csv <-
    c("character", "numeric", "double", "integer", "logical", "Date")

  vec_names_not_csv <-
    base::names(vec_classes_file)[!vec_classes_file %in% vec_classes_csv]

  if (
    base::length(vec_names_not_csv) > 0L
  ) {
    cli::cli_abort(
      c(
        "A csv file cannot hold the class the contract
          {.val {purrr::chuck(contract, 'contract_id')}} gives to
          {.val {vec_names_not_csv}}.",
        "i" = "Read from csv: {.val {vec_classes_csv}}."
      )
    )
  }

  list_collectors <-
    purrr::map(
      .x = vec_classes_file,
      .f = ~ base::switch(
        .x,
        "character" = readr::col_character(),
        "numeric" = readr::col_double(),
        "double" = readr::col_double(),
        "integer" = readr::col_integer(),
        "logical" = readr::col_logical(),
        "Date" = readr::col_date(format = "%Y-%m-%d")
      )
    )

  # readr's warning about a value it cannot read is replaced by the error
  #   below, which names the file and the column
  data_read <-
    base::withCallingHandlers(
      readr::read_csv(
        file = path_file,
        col_types = rlang::exec(
          readr::cols,
          !!!list_collectors,
          .default = readr::col_character()
        ),
        na = c("", "NA"),
        show_col_types = FALSE,
        progress = FALSE,
        lazy = FALSE
      ),
      vroom_parse_issue = function(warning) {
        base::invokeRestart("muffleWarning")
      }
    )

  data_problems <-
    readr::problems(data_read)

  if (
    base::nrow(data_problems) > 0L
  ) {
    vec_columns_problem <-
      dplyr::pull(data_problems, col)

    vec_names_problem <-
      dplyr::coalesce(
        base::names(data_read)[vec_columns_problem],
        base::as.character(vec_columns_problem),
        "?"
      )

    vec_problems <-
      stringr::str_c(
        "row ", dplyr::coalesce(
          base::as.character(dplyr::pull(data_problems, row)), "?"
        ),
        ", column ", vec_names_problem,
        ": '", dplyr::coalesce(dplyr::pull(data_problems, actual), ""),
        "' is not ",
        dplyr::coalesce(dplyr::pull(data_problems, expected), "readable"),
        "."
      ) |>
      utils::head(n = 10L) |>
      rlang::set_names("x")

    cli::cli_abort(
      c(
        "{.file {file_name}} has value{?s} that cannot be read as the
          class{?es} of {.val {purrr::chuck(contract, 'contract_id')}}
          ({base::nrow(data_problems)} in all).",
        vec_problems
      )
    )
  }

  # A plain tibble, without the reading specification readr attaches
  res <-
    data_read |>
    base::as.data.frame() |>
    tibble::as_tibble()

  return(res)
}
