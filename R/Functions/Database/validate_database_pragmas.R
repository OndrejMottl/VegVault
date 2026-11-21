#' @title Validate the settings of a SQLite connection
#' @description
#' Read the given `PRAGMA` settings of a SQLite connection and abort when
#' any of them differs from its expected value.
#' @param con
#' A valid `DBI` connection to a SQLite database.
#' @param list_pragmas
#' Named list of expected values, one per setting, for example
#' `list(journal_mode = "DELETE", foreign_keys = "ON")`. Allowed names:
#' `journal_mode`, `synchronous`, `foreign_keys`, `temp_store` and
#' `cache_size`. Each value is a text or number scalar.
#' @return
#' Invisibly, a tibble with one row per setting, in the order of
#' `list_pragmas`: `pragma`, `expected` and `value`, both as the text
#' form SQLite reports (see Details).
#' @details
#' SQLite reports some settings as numbers, so names are translated before
#' they are compared: `synchronous` `OFF`, `NORMAL`, `FULL` and `EXTRA` are
#' 0 to 3; `foreign_keys` `OFF` and `ON` are 0 and 1; `temp_store`
#' `DEFAULT`, `FILE` and `MEMORY` are 0 to 2. `journal_mode` is compared
#' in lower case and `cache_size` as a whole number (negative values are
#' KiB). Aborts with one line per setting that differs. Nothing is
#' changed.
#' @seealso [run_database_load()]
#' @examples
#' \dontrun{
#' validate_database_pragmas(
#'   con = con,
#'   list_pragmas = list(journal_mode = "DELETE", foreign_keys = "ON")
#' )
#' }
validate_database_pragmas <- function(
  con,
  list_pragmas
) {
  vec_allowed <-
    c("journal_mode", "synchronous", "foreign_keys", "temp_store", "cache_size")

  assertthat::assert_that(
    methods::is(con, "DBIConnection"),
    DBI::dbIsValid(con),
    msg = "`con` must be a valid DBI connection."
  )

  assertthat::assert_that(
    base::is.list(list_pragmas),
    base::length(list_pragmas) >= 1L,
    !base::is.null(base::names(list_pragmas)),
    base::all(base::nzchar(base::names(list_pragmas))),
    !base::anyDuplicated(base::names(list_pragmas)),
    msg = "`list_pragmas` must be a named list with one value per setting."
  )

  vec_unknown <-
    base::setdiff(base::names(list_pragmas), vec_allowed)

  assertthat::assert_that(
    base::length(vec_unknown) == 0L,
    msg = stringr::str_c(
      "`list_pragmas` names settings that are not allowed: ",
      stringr::str_c(vec_unknown, collapse = ", ")
    )
  )

  vec_scalar <-
    purrr::map_lgl(
      .x = list_pragmas,
      .f = ~ (base::is.character(.x) || base::is.numeric(.x)) &&
        base::length(.x) == 1L &&
        !base::is.na(.x)
    )

  assertthat::assert_that(
    base::all(vec_scalar),
    msg = "Every value of `list_pragmas` must be a text or number scalar."
  )

  # SQLite reports these settings as numbers
  data_codes <-
    tibble::tribble(
      ~pragma, ~word, ~code,
      "synchronous", "off", "0",
      "synchronous", "normal", "1",
      "synchronous", "full", "2",
      "synchronous", "extra", "3",
      "foreign_keys", "off", "0",
      "foreign_keys", "on", "1",
      "temp_store", "default", "0",
      "temp_store", "file", "1",
      "temp_store", "memory", "2"
    )

  data_expected <-
    tibble::tibble(
      pragma = base::names(list_pragmas),
      value_raw = purrr::map_chr(
        .x = base::unname(list_pragmas),
        .f = ~ base::format(.x, scientific = FALSE)
      ),
      value_given = stringr::str_to_lower(value_raw)
    ) |>
    dplyr::left_join(
      data_codes,
      by = dplyr::join_by(pragma, value_given == word),
      relationship = "many-to-one"
    ) |>
    dplyr::mutate(
      flag_code = purrr::map2_lgl(
        .x = pragma,
        .y = value_given,
        .f = ~ .y %in% dplyr::pull(
          dplyr::filter(data_codes, pragma == .x),
          code
        )
      ),
      expected = dplyr::case_when(
        pragma == "journal_mode" &
          stringr::str_detect(
            string = value_given,
            pattern = "^[a-z]+$"
          ) ~ value_given,
        pragma == "cache_size" &
          stringr::str_detect(
            string = value_given,
            pattern = "^-?[0-9]+$"
          ) ~ value_given,
        !base::is.na(code) ~ code,
        flag_code ~ value_given,
        .default = NA_character_
      )
    )

  data_unknown_values <-
    dplyr::filter(data_expected, base::is.na(expected))

  if (
    base::nrow(data_unknown_values) > 0L
  ) {
    vec_unknown_values <-
      stringr::str_c(
        dplyr::pull(data_unknown_values, pragma),
        " = ",
        dplyr::pull(data_unknown_values, value_raw)
      )

    cli::cli_abort(
      c(
        "Unknown value{?s} in {.arg list_pragmas}: {vec_unknown_values}.",
        "i" = "Use a value that SQLite accepts for the setting."
      )
    )
  }

  res <-
    data_expected |>
    dplyr::mutate(
      value = purrr::map_chr(
        .x = pragma,
        .f = ~ DBI::dbGetQuery(
          conn = con,
          statement = stringr::str_c("PRAGMA ", .x)
        ) |>
          dplyr::pull(1L) |>
          base::as.character() |>
          stringr::str_to_lower()
      )
    ) |>
    dplyr::select(pragma, expected, value)

  data_different <-
    dplyr::filter(res, expected != value)

  if (
    base::nrow(data_different) > 0L
  ) {
    vec_differences <-
      stringr::str_c(
        dplyr::pull(data_different, pragma),
        ": expected ",
        dplyr::pull(data_different, expected),
        ", found ",
        dplyr::pull(data_different, value)
      )

    vec_difference_bullets <-
      rlang::set_names(
        vec_differences,
        base::rep("x", base::length(vec_differences))
      )

    cli::cli_abort(
      c(
        "The settings of the database connection differ from the expected
        ones.",
        vec_difference_bullets
      )
    )
  }

  return(invisible(res))
}
