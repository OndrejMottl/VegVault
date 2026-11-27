#' @title Load the tables, columns and references of a DBML file
#' @description
#' Read the conceptual database diagram (`Data/SQL/database_structure.dbml`)
#' into tables of its columns and its references, so that it can be
#' compared with the executable schema.
#' @param path_dbml
#' Character scalar. Path of an existing DBML file, read as UTF-8.
#' @return
#' A list of two tibbles:
#' \itemize{
#'   \item `columns`: one row per column, in file order, with
#'     `table_name`, `column_name`, `column_type` (as written, for
#'     example `"INTEGER"`), `flag_primary_key` (the column is the
#'     primary key, or part of a composite one) and `flag_not_null`;
#'   \item `references`: one row per `Ref`, written as the referencing
#'     column and the column it refers to: `table_name`, `column_name`,
#'     `ref_table_name` and `ref_column_name`.
#' }
#' @details
#' Reads the subset of DBML that the project uses:
#' \itemize{
#'   \item `Table <name> { ... }` blocks (the keyword in any case), with
#'     one column per line, `<name> <type> [settings]`. The settings
#'     `pk` or `primary key` and `not null` are read; other settings,
#'     such as `unique`, `default:` and `note:`, are allowed and ignored.
#'   \item An `indexes { ... }` block inside a table, whose `[pk]` entry
#'     (for example `(sample_id, reference_id) [pk]`) marks a composite
#'     primary key; other index entries are ignored.
#'   \item `Note:` lines and `''' ... '''` notes, the `Project` block and
#'     `//` comments, which are skipped.
#'   \item Top-level `Ref: A.x > B.y` (`A.x` refers to `B.y`), `<` (the
#'     other direction) and `-` (read as `>`).
#' }
#' A table must open with `{` at the end of its first line and close with
#' `}` on a line of its own. Aborts on any other line inside a table or at
#' the top level (for example an `Enum` or a `Ref` it cannot read), on an
#' unclosed block, string or note, on a table defined twice and on a file
#' without tables, so that a DBML construct the parser does not know is
#' never skipped silently.
#' @seealso [build_database_schema()]
#' @examples
#' \dontrun{
#' list_dbml <-
#'   load_dbml_structure(
#'     path_dbml = here::here("Data", "SQL", "database_structure.dbml")
#'   )
#' }
load_dbml_structure <- function(path_dbml) {
  assertthat::assert_that(
    base::is.character(path_dbml),
    base::length(path_dbml) == 1L,
    !base::is.na(path_dbml),
    base::file.exists(path_dbml),
    msg = "`path_dbml` must be the path of an existing DBML file."
  )

  text_dbml <-
    base::readLines(con = path_dbml, warn = FALSE, encoding = "UTF-8") |>
    stringr::str_c(collapse = "\n")

  # Notes, strings and expressions can hold braces, quotes or `//`, so they
  #   are emptied first, together with the comments. The regex engine scans
  #   from left to right, so a token found first hides what lies inside it.
  pattern_token <-
    stringr::str_c(
      "'''[\\s\\S]*?(?:'''|\\z)",
      "|'(?:[^'\\\\\\n]|\\\\.)*'?",
      "|`[^`\\n]*`?",
      "|//[^\\n]*"
    )

  vec_tokens <-
    stringr::str_extract_all(string = text_dbml, pattern = pattern_token) |>
    purrr::chuck(1)

  vec_is_closed <-
    dplyr::case_when(
      stringr::str_starts(string = vec_tokens, pattern = "//") ~ TRUE,
      stringr::str_starts(string = vec_tokens, pattern = "'''") ~
        base::nchar(vec_tokens) >= 6L &
          stringr::str_ends(string = vec_tokens, pattern = "'''"),
      stringr::str_starts(string = vec_tokens, pattern = "'") ~
        stringr::str_detect(
          string = vec_tokens,
          pattern = "^'(?:[^'\\\\\\n]|\\\\.)*'$"
        ),
      .default = stringr::str_detect(
        string = vec_tokens,
        pattern = "^`[^`\\n]*`$"
      )
    )

  if (
    !base::all(vec_is_closed)
  ) {
    cli::cli_abort(
      "A note, string or expression of the DBML file is not closed."
    )
  }

  vec_lines <-
    stringr::str_replace_all(
      string = text_dbml,
      pattern = pattern_token,
      replacement = function(vec_matches) {
        res_replacement <-
          dplyr::case_when(
            stringr::str_starts(string = vec_matches, pattern = "//") ~ "",
            stringr::str_starts(string = vec_matches, pattern = "`") ~ "``",
            .default = "''"
          )

        return(res_replacement)
      }
    ) |>
    stringr::str_split_1(pattern = "\n") |>
    stringr::str_squish() |>
    purrr::discard(.p = ~ .x == "")

  # Depth of the braces before and after each line. A block that opens at
  #   depth 0 is a table or the project; one that opens at depth 1 is a
  #   block inside it, such as `indexes`.
  pattern_table <-
    stringr::str_c(
      "^(?i:table)\\s+\"?([A-Za-z_][A-Za-z0-9_]*)\"?",
      "(?:\\s+\\[[^\\]]*\\])?\\s*\\{$"
    )

  data_lines <-
    tibble::tibble(line = vec_lines) |>
    dplyr::mutate(
      n_open = stringr::str_count(string = line, pattern = "\\{"),
      n_close = stringr::str_count(string = line, pattern = "\\}"),
      depth_after = base::cumsum(n_open - n_close),
      depth_before = dplyr::lag(depth_after, default = 0L),
      is_close = line == "}",
      table_opened = dplyr::if_else(
        depth_before == 0L & n_open > 0L,
        dplyr::coalesce(
          stringr::str_match(string = line, pattern = pattern_table)[, 2],
          stringr::str_c(
            "<",
            stringr::str_extract(string = line, pattern = "^\\S+"),
            ">"
          )
        ),
        NA_character_
      ),
      block_opened = dplyr::if_else(
        depth_before == 1L & n_open > 0L,
        stringr::str_to_lower(
          stringr::str_extract(string = line, pattern = "^[A-Za-z_]+")
        ),
        NA_character_
      )
    )

  if (
    base::any(dplyr::pull(data_lines, depth_after) < 0L)
  ) {
    cli::cli_abort("The DBML file closes a block that was never opened.")
  }

  if (
    dplyr::last(dplyr::pull(data_lines, depth_after), default = 0L) != 0L
  ) {
    cli::cli_abort("A block of the DBML file is not closed.")
  }

  data_lines_owned <-
    data_lines |>
    dplyr::mutate(
      owner = dplyr::case_when(
        !base::is.na(table_opened) ~ table_opened,
        depth_before == 0L ~ "<top>"
      ),
      block = dplyr::case_when(
        !base::is.na(block_opened) ~ block_opened,
        depth_before <= 1L ~ "<none>"
      )
    ) |>
    tidyr::fill(owner, block, .direction = "down") |>
    dplyr::mutate(
      is_table = !stringr::str_detect(string = owner, pattern = "^<")
    )

  # Blocks at the top level other than tables and the project, for example
  #   an `Enum` or a `Ref` block, are not read
  vec_owners_unknown <-
    data_lines_owned |>
    dplyr::filter(
      !base::is.na(table_opened),
      !is_table,
      stringr::str_to_lower(table_opened) != "<project>"
    ) |>
    dplyr::pull(line)

  vec_top_unknown <-
    data_lines_owned |>
    dplyr::filter(
      owner == "<top>",
      base::is.na(table_opened),
      !stringr::str_detect(string = line, pattern = "^Ref\\b")
    ) |>
    dplyr::pull(line)

  data_table_lines <-
    data_lines_owned |>
    dplyr::filter(
      is_table,
      depth_before == 1L,
      !is_close,
      base::is.na(block_opened)
    ) |>
    dplyr::mutate(
      is_note = stringr::str_detect(
        string = line,
        pattern = "^(?i:note)\\s*:"
      )
    ) |>
    dplyr::filter(!is_note)

  pattern_column <-
    stringr::str_c(
      "^\"?([A-Za-z_][A-Za-z0-9_]*)\"?\\s+",
      "([A-Za-z][A-Za-z0-9_]*(?:\\([0-9, ]*\\))?)\\s*(\\[.*\\])?$"
    )

  mat_columns <-
    stringr::str_match(
      string = dplyr::pull(data_table_lines, line),
      pattern = pattern_column
    )

  vec_lines_unknown <-
    c(
      vec_owners_unknown,
      vec_top_unknown,
      dplyr::pull(data_table_lines, line)[base::is.na(mat_columns[, 1])]
    )

  if (
    base::length(vec_lines_unknown) > 0L
  ) {
    # Braces would be read as cli expressions, so they are doubled
    vec_bullets_unknown <-
      stringr::str_replace_all(
        string = vec_lines_unknown,
        pattern = c("\\{" = "{{", "\\}" = "}}")
      ) |>
      rlang::set_names(base::rep("x", base::length(vec_lines_unknown)))

    cli::cli_abort(
      c(
        "The DBML file has {base::length(vec_lines_unknown)} line{?s} that
        cannot be read:",
        vec_bullets_unknown
      )
    )
  }

  vec_tables <-
    data_lines_owned |>
    dplyr::filter(!base::is.na(table_opened), is_table) |>
    dplyr::pull(table_opened)

  if (
    base::length(vec_tables) == 0L
  ) {
    cli::cli_abort("The DBML file defines no table.")
  }

  vec_tables_twice <-
    base::unique(vec_tables[base::duplicated(vec_tables)])

  if (
    base::length(vec_tables_twice) > 0L
  ) {
    cli::cli_abort(
      "The DBML file defines {cli::qty(vec_tables_twice)}{?a table/tables}
      twice: {.val {vec_tables_twice}}."
    )
  }

  # Composite primary keys: the `[pk]` entry of an `indexes` block
  data_keys_composite <-
    data_lines_owned |>
    dplyr::filter(
      is_table,
      block == "indexes",
      depth_before == 2L,
      stringr::str_detect(
        string = line,
        pattern = "^\\([^)]*\\)\\s*\\[[^\\]]*\\bpk\\b[^\\]]*\\]$"
      )
    ) |>
    dplyr::mutate(
      column_name = stringr::str_match(
        string = line,
        pattern = "^\\(([^)]*)\\)"
      )[, 2] |>
        stringr::str_split(pattern = ",")
    ) |>
    tidyr::unnest_longer(column_name) |>
    dplyr::mutate(
      table_name = owner,
      column_name = stringr::str_trim(column_name),
      flag_composite_key = TRUE
    ) |>
    dplyr::select(table_name, column_name, flag_composite_key)

  vec_settings <-
    dplyr::coalesce(mat_columns[, 4], "")

  data_columns <-
    tibble::tibble(
      table_name = dplyr::pull(data_table_lines, owner),
      column_name = mat_columns[, 2],
      column_type = mat_columns[, 3],
      flag_inline_key = stringr::str_detect(
        string = vec_settings,
        pattern = "(?i)\\b(?:pk|primary key)\\b"
      ),
      flag_not_null = stringr::str_detect(
        string = vec_settings,
        pattern = "(?i)\\bnot null\\b"
      )
    ) |>
    dplyr::left_join(
      y = data_keys_composite,
      by = dplyr::join_by(table_name, column_name),
      relationship = "one-to-one"
    ) |>
    dplyr::mutate(
      flag_primary_key = flag_inline_key |
        dplyr::coalesce(flag_composite_key, FALSE)
    ) |>
    dplyr::select(
      table_name, column_name, column_type, flag_primary_key, flag_not_null
    )

  vec_ref_lines <-
    data_lines_owned |>
    dplyr::filter(
      owner == "<top>",
      stringr::str_detect(string = line, pattern = "^Ref\\b")
    ) |>
    dplyr::pull(line)

  pattern_ref <-
    stringr::str_c(
      "^Ref(?:\\s+[A-Za-z_][A-Za-z0-9_]*)?\\s*:\\s*",
      "\"?([A-Za-z_][A-Za-z0-9_]*)\"?\\.\"?([A-Za-z_][A-Za-z0-9_]*)\"?",
      "\\s*([<>-])\\s*",
      "\"?([A-Za-z_][A-Za-z0-9_]*)\"?\\.\"?([A-Za-z_][A-Za-z0-9_]*)\"?",
      "\\s*(?:\\[[^\\]]*\\])?$"
    )

  mat_refs <-
    stringr::str_match(string = vec_ref_lines, pattern = pattern_ref)

  vec_refs_unknown <-
    vec_ref_lines[base::is.na(mat_refs[, 1])]

  if (
    base::length(vec_refs_unknown) > 0L
  ) {
    vec_bullets_refs <-
      stringr::str_replace_all(
        string = vec_refs_unknown,
        pattern = c("\\{" = "{{", "\\}" = "}}")
      ) |>
      rlang::set_names(base::rep("x", base::length(vec_refs_unknown)))

    cli::cli_abort(
      c(
        "The DBML file has {base::length(vec_refs_unknown)} Ref line{?s}
        that cannot be read:",
        vec_bullets_refs
      )
    )
  }

  # `A.x < B.y` is the same reference as `B.y > A.x`
  vec_is_reversed <-
    mat_refs[, 4] == "<"

  data_references <-
    tibble::tibble(
      table_name = dplyr::if_else(
        vec_is_reversed,
        mat_refs[, 5],
        mat_refs[, 2]
      ),
      column_name = dplyr::if_else(
        vec_is_reversed,
        mat_refs[, 6],
        mat_refs[, 3]
      ),
      ref_table_name = dplyr::if_else(
        vec_is_reversed,
        mat_refs[, 2],
        mat_refs[, 5]
      ),
      ref_column_name = dplyr::if_else(
        vec_is_reversed,
        mat_refs[, 3],
        mat_refs[, 6]
      )
    )

  res <-
    list(
      columns = data_columns,
      references = data_references
    )

  return(res)
}
