#' @title Load the statements of an SQL file
#' @description
#' Read an SQL file and split it into single statements, so that each can
#' be executed on its own with `DBI::dbExecute()`. Semicolons inside
#' quoted strings, quoted names and comments do not end a statement.
#' @param path_sql
#' Character scalar. Path of an existing SQL file, read as UTF-8.
#' @return
#' A tibble with one row per statement, in file order:
#' \itemize{
#'   \item `statement_id`: integer, 1 to the number of statements;
#'   \item `object_type`: `"table"`, `"view"` or `"index"` for a
#'     `CREATE TABLE`, `CREATE VIEW` or `CREATE INDEX` statement (also
#'     `UNIQUE`, `TEMP` and `IF NOT EXISTS` forms), `"other"` for any
#'     other statement;
#'   \item `object_name`: the name of the created object without quotes
#'     (`"..."`, `[...]` or backticks), `NA` for `"other"`;
#'   \item `statement`: the statement text without comments, without the
#'     final semicolon and trimmed.
#' }
#' @details
#' The file is read token by token: single-quoted strings (with `''` as
#' an escaped quote), double-quoted, bracketed and backticked names,
#' `--` line comments and `/* */` block comments. A semicolon outside
#' these ends a statement. Text after the last semicolon is a statement
#' too, unless it holds only comments and white space.
#' Aborts when a string, quoted name or block comment is not closed, when
#' the file holds no statement, and on `CREATE TRIGGER`, whose body holds
#' semicolons of its own and is not supported.
#' @examples
#' \dontrun{
#' data_statements <-
#'   load_sql_statements(
#'     path_sql = here::here("Data", "SQL", "make_tables.sql")
#'   )
#' }
load_sql_statements <- function(path_sql) {
  assertthat::assert_that(
    base::is.character(path_sql),
    base::length(path_sql) == 1L,
    !base::is.na(path_sql),
    base::file.exists(path_sql),
    msg = "`path_sql` must be the path of an existing SQL file."
  )

  text_sql <-
    base::readLines(con = path_sql, warn = FALSE, encoding = "UTF-8") |>
    stringr::str_c(collapse = "\n")

  # One alternative per token that can hide a semicolon, then the semicolon
  #   itself. The regex engine scans from left to right, so a token found
  #   first (for example a string) hides what lies inside it (for example
  #   `--`). Closing quotes are optional, so that an unclosed token is
  #   found and reported instead of being split.
  pattern_token <-
    stringr::str_c(
      "'(?:[^']|'')*'?",
      "|\"(?:[^\"]|\"\")*\"?",
      "|`[^`]*`?",
      "|\\[[^\\]]*\\]?",
      "|--[^\\n]*",
      "|/\\*[\\s\\S]*?(?:\\*/|\\z)",
      "|;"
    )

  mat_tokens <-
    stringr::str_locate_all(string = text_sql, pattern = pattern_token) |>
    purrr::chuck(1)

  data_tokens <-
    tibble::tibble(
      start = mat_tokens[, "start"],
      end = mat_tokens[, "end"]
    ) |>
    dplyr::mutate(
      token = stringr::str_sub(string = text_sql, start = start, end = end),
      kind = dplyr::case_when(
        token == ";" ~ "semicolon",
        stringr::str_starts(string = token, pattern = "--") ~ "comment",
        stringr::str_starts(string = token, pattern = "/\\*") ~ "comment",
        .default = "quoted"
      ),
      is_closed = dplyr::case_when(
        kind == "semicolon" ~ TRUE,
        stringr::str_starts(string = token, pattern = "--") ~ TRUE,
        stringr::str_starts(string = token, pattern = "/\\*") ~
          stringr::str_detect(string = token, pattern = "^/\\*[\\s\\S]*\\*/$"),
        stringr::str_starts(string = token, pattern = "'") ~
          stringr::str_detect(string = token, pattern = "^'(?:[^']|'')*'$"),
        stringr::str_starts(string = token, pattern = "\"") ~
          stringr::str_detect(
            string = token,
            pattern = "^\"(?:[^\"]|\"\")*\"$"
          ),
        stringr::str_starts(string = token, pattern = "`") ~
          stringr::str_detect(string = token, pattern = "^`[^`]*`$"),
        .default = stringr::str_detect(
          string = token,
          pattern = "^\\[[^\\]]*\\]$"
        )
      )
    )

  data_unclosed <-
    dplyr::filter(data_tokens, !is_closed)

  if (
    base::nrow(data_unclosed) > 0L
  ) {
    text_unclosed <-
      data_unclosed |>
      dplyr::pull(token) |>
      dplyr::first() |>
      stringr::str_trunc(width = 40L)

    cli::cli_abort(
      c(
        "A quoted string, quoted name or block comment is not closed in the
        SQL file.",
        "i" = "It starts with {.code {text_unclosed}}."
      )
    )
  }

  # Comments become blanks of the same length, so that every position in
  #   the text stays valid for the split below
  data_comments <-
    dplyr::filter(data_tokens, kind == "comment")

  vec_positions_comment <-
    purrr::map2(
      .x = dplyr::pull(data_comments, start),
      .y = dplyr::pull(data_comments, end),
      .f = ~ base::seq.int(from = .x, to = .y)
    ) |>
    purrr::list_c(ptype = integer())

  text_code <-
    base::strsplit(x = text_sql, split = "")[[1]] |>
    base::replace(list = vec_positions_comment, values = " ") |>
    stringr::str_c(collapse = "")

  vec_positions_semicolon <-
    data_tokens |>
    dplyr::filter(kind == "semicolon") |>
    dplyr::pull(start)

  vec_statements <-
    stringr::str_sub(
      string = text_code,
      start = c(1L, vec_positions_semicolon + 1L),
      end = c(vec_positions_semicolon - 1L, base::nchar(text_code))
    ) |>
    stringr::str_trim() |>
    purrr::discard(.p = ~ .x == "")

  if (
    base::length(vec_statements) == 0L
  ) {
    cli::cli_abort("The SQL file holds no statement.")
  }

  pattern_create <-
    stringr::str_c(
      "(?i)^CREATE\\s+(?:(?:TEMP|TEMPORARY)\\s+)?(?:UNIQUE\\s+)?",
      "(TABLE|VIEW|INDEX|TRIGGER)\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?",
      "(\"(?:[^\"]|\"\")*\"|\\[[^\\]]*\\]|`[^`]*`|[A-Za-z_][A-Za-z0-9_$]*)"
    )

  mat_create <-
    stringr::str_match(string = vec_statements, pattern = pattern_create)

  vec_types <-
    stringr::str_to_lower(mat_create[, 2])

  if (
    base::any(vec_types %in% "trigger")
  ) {
    cli::cli_abort(
      c(
        "The SQL file holds a CREATE TRIGGER statement, which is not
        supported.",
        "i" = "A trigger body holds semicolons of its own, so it cannot be
        split into statements here."
      )
    )
  }

  vec_names_quoted <-
    mat_create[, 3]

  res <-
    tibble::tibble(
      statement_id = base::seq_along(vec_statements),
      object_type = dplyr::coalesce(vec_types, "other"),
      object_name = dplyr::case_when(
        stringr::str_starts(string = vec_names_quoted, pattern = "\"") ~
          stringr::str_sub(string = vec_names_quoted, start = 2L, end = -2L) |>
          stringr::str_replace_all(
            pattern = stringr::fixed("\"\""),
            replacement = "\""
          ),
        stringr::str_detect(string = vec_names_quoted, pattern = "^[\\[`]") ~
          stringr::str_sub(string = vec_names_quoted, start = 2L, end = -2L),
        .default = vec_names_quoted
      ),
      statement = vec_statements
    )

  return(res)
}
