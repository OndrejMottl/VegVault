#' @title Build the file-name pattern of a producer artefact
#' @description
#' Turn a file-name template of a producer contract into an anchored
#' regular expression with one named group per placeholder.
#' @param name_template
#' Character scalar. File-name template with the placeholders `{date}` and
#' `{hash}` and, depending on the contract, `{partition}` and `{variable}`,
#' for example `"bio{variable}_batch_{partition}_{date}__{hash}__.qs"`.
#' @param partition_scheme
#' Character scalar. `"none"`, `"integer"` or `"letter"`.
#' @param vec_variable_tokens
#' Character vector of the tokens allowed in `{variable}`, or `NULL` when
#' the template has no `{variable}`.
#' @return
#' Character scalar. A regular expression anchored with `^` and `$`. The
#' placeholder `{date}` matches `YYYY-MM-DD`, `{hash}` 32 lower-case
#' hexadecimal characters, `{partition}` one or more digits (scheme
#' `"integer"`) or one capital letter (scheme `"letter"`), and
#' `{variable}` exactly one of `vec_variable_tokens`. Each placeholder is
#' a named group of the same name; every other character is literal.
#' @details
#' The pattern describes names written by `RUtilpol::save_latest_file()`:
#' `<name>_<date>__<hash>__.<extension>`. Aborts when the template lacks
#' `{date}` or `{hash}`, contains an unknown placeholder, contains
#' `{partition}` while the scheme is `"none"` (or lacks it while the scheme
#' is not `"none"`), or when `{variable}` and `vec_variable_tokens` are not
#' both present or both absent.
build_producer_file_regex <- function(
  name_template,
  partition_scheme,
  vec_variable_tokens = NULL
) {
  assertthat::assert_that(
    base::is.character(name_template),
    base::length(name_template) == 1L,
    !base::is.na(name_template),
    msg = "'name_template' must be a single character value."
  )

  assertthat::assert_that(
    base::is.character(partition_scheme),
    base::length(partition_scheme) == 1L,
    partition_scheme %in% c("none", "integer", "letter"),
    msg = "'partition_scheme' must be 'none', 'integer' or 'letter'."
  )

  assertthat::assert_that(
    base::is.null(vec_variable_tokens) ||
      (
        base::is.character(vec_variable_tokens) &&
          base::length(vec_variable_tokens) > 0L &&
          !base::anyNA(vec_variable_tokens) &&
          !base::anyDuplicated(vec_variable_tokens)
      ),
    msg = "'vec_variable_tokens' must be NULL or unique character values."
  )

  mat_placeholders <-
    stringr::str_match_all(
      string = name_template,
      pattern = "\\{([^{}]*)\\}"
    ) |>
    purrr::chuck(1)

  vec_placeholders <- mat_placeholders[, 2]

  vec_unknown <-
    base::setdiff(
      vec_placeholders,
      c("date", "hash", "partition", "variable")
    )

  if (
    base::length(vec_unknown) > 0L
  ) {
    cli::cli_abort(
      "Template {.val {name_template}} has unknown placeholder{?s}
      {.val {vec_unknown}}."
    )
  }

  if (
    base::anyDuplicated(vec_placeholders) > 0L
  ) {
    cli::cli_abort(
      "Template {.val {name_template}} repeats a placeholder."
    )
  }

  if (
    !"date" %in% vec_placeholders
  ) {
    cli::cli_abort("Template {.val {name_template}} lacks {{date}}.")
  }

  if (
    !"hash" %in% vec_placeholders
  ) {
    cli::cli_abort("Template {.val {name_template}} lacks {{hash}}.")
  }

  flag_has_partition <- "partition" %in% vec_placeholders

  if (
    flag_has_partition && partition_scheme == "none"
  ) {
    cli::cli_abort(
      "Template {.val {name_template}} has {{partition}} but the partition
      scheme is {.val none}."
    )
  }

  if (
    !flag_has_partition && partition_scheme != "none"
  ) {
    cli::cli_abort(
      "Partition scheme {.val {partition_scheme}} needs {{partition}} in
      template {.val {name_template}}."
    )
  }

  flag_has_variable <- "variable" %in% vec_placeholders

  if (
    flag_has_variable != !base::is.null(vec_variable_tokens)
  ) {
    cli::cli_abort(
      "Template {.val {name_template}} and {.arg vec_variable_tokens} must
      both have a variable or both lack one."
    )
  }

  # Escape every regular-expression metacharacter, so all text outside the
  #   placeholders is matched literally
  pattern_metacharacters <- "([.\\\\^$|?*+()\\[\\]{}])"

  template_escaped <-
    stringr::str_replace_all(
      string = name_template,
      pattern = pattern_metacharacters,
      replacement = "\\\\\\1"
    )

  group_partition <-
    base::switch(
      partition_scheme,
      "none" = "",
      "integer" = "(?<partition>[0-9]+)",
      "letter" = "(?<partition>[A-Z])"
    )

  group_variable <-
    if (
      flag_has_variable
    ) {
      vec_tokens_escaped <-
        stringr::str_replace_all(
          string = vec_variable_tokens,
          pattern = pattern_metacharacters,
          replacement = "\\\\\\1"
        )

      stringr::str_c(
        "(?<variable>",
        stringr::str_c(vec_tokens_escaped, collapse = "|"),
        ")"
      )
    } else {
      ""
    }

  pattern_body <-
    template_escaped |>
    stringr::str_replace_all(
      pattern = stringr::fixed("\\{date\\}"),
      replacement = "(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})"
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("\\{hash\\}"),
      replacement = "(?<hash>[0-9a-f]{32})"
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("\\{partition\\}"),
      replacement = group_partition
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("\\{variable\\}"),
      replacement = group_variable
    )

  res <-
    stringr::str_c("^", pattern_body, "$")

  return(res)
}
