#' @title Load a producer artefact contract
#' @description
#' Read one producer artefact contract from its YAML file, check that it
#' follows the contract format described in `Data/Contracts/README.md`,
#' and return it with its file-name templates compiled to regular
#' expressions.
#' @param path_contract
#' Character scalar. Path to an existing contract file with the extension
#' `.yml`.
#' @return
#' A named list with the fields of the contract. Optional fields that are
#' absent are filled with their defaults: `extra_columns` (`"allow"`),
#' `min_rows` (`1`), `keys`, `rounded_keys`, `dependencies`, `relations`
#' and `notes` (empty lists), `variables` (`NULL`) and, in
#' `partitioning`, `contiguous` (`TRUE`). `keys` is returned as a list of
#' character vectors, one per key. The field `file` gains
#' `name_patterns`, a character vector with one anchored regular
#' expression per entry of `file$name_templates`, built with
#' `build_producer_file_regex()`.
#' @details
#' Required top-level fields are `contract_id`, `contract_version`,
#' `status`, `title`, `producer` (with `repository` and `directory`),
#' `consumers`, `file` (with `name_templates`), `partitioning` (with
#' `scheme`) and `columns`. `contract_id` must equal the file name without
#' its extension, `contract_version` must be a semantic version such as
#' `1.0.0`, and `status` must be `"active"`, `"conditional"` or
#' `"retired"`; a status other than `"active"` needs a `status_note`.
#' A partition scheme other than `"none"` needs `partitioning$first`, the
#' first partition (a whole number for `"integer"`, a capital letter for
#' `"letter"`), and may give `partitioning$count`, the exact number of
#' partitions per variable (a whole number of at least 1).
#' `min_rows` is the least number of rows of every file (a whole number of
#' at least 0). `rounded_keys` entries have `columns` and `digits` (a
#' whole number of at least 0): the columns must be unique after rounding
#' their numeric columns to `digits` decimals.
#' Keys, rounded keys and dependencies may refer only to top-level
#' columns, and `variables$value_column` must be one. When `variables` is
#' present, every template must contain `{variable}` and its `table` gives
#' one entry per variable with `variable`, `file_token`, `unit`,
#' `description`, `evidence` and optional `checks`; variables and tokens
#' must be unique.
#' Aborts with every problem found, naming the contract file and the field.
load_producer_contract <- function(path_contract) {
  assertthat::assert_that(
    base::is.character(path_contract),
    base::length(path_contract) == 1L,
    !base::is.na(path_contract),
    base::file.exists(path_contract),
    stringr::str_detect(path_contract, "[.]yml$"),
    msg = "'path_contract' must be the path to an existing .yml file."
  )

  file_contract <-
    base::basename(path_contract)

  id_expected <-
    stringr::str_remove(file_contract, "[.]yml$")

  list_raw <-
    yaml::read_yaml(file = path_contract)

  if (
    !base::is.list(list_raw) || base::is.null(base::names(list_raw))
  ) {
    cli::cli_abort(
      "Contract {.file {file_contract}} must be a YAML map of fields."
    )
  }

  vec_fields <-
    base::names(list_raw)

  vec_required <-
    c(
      "contract_id", "contract_version", "status", "title", "producer",
      "consumers", "file", "partitioning", "columns"
    )

  vec_optional <-
    c(
      "status_note", "description", "extra_columns", "min_rows", "keys",
      "rounded_keys", "dependencies", "variables", "relations", "notes"
    )

  #--------------------------------------------------#
  ## Top-level fields -----
  #--------------------------------------------------#

  list_text_fields <-
    list_raw[base::intersect(vec_fields, c("contract_id", "title"))]

  is_text <-
    purrr::map_lgl(
      .x = list_text_fields,
      .f = ~ base::is.character(.x) && base::length(.x) == 1L &&
        !base::is.na(.x) && .x != ""
    )

  value_id <-
    purrr::pluck(list_raw, "contract_id", .default = NA_character_)

  value_version <-
    purrr::pluck(list_raw, "contract_version", .default = NA_character_)

  value_status <-
    purrr::pluck(list_raw, "status", .default = NA_character_)

  value_status_note <-
    purrr::pluck(list_raw, "status_note")

  value_consumers <-
    purrr::pluck(list_raw, "consumers")

  value_extra <-
    purrr::pluck(list_raw, "extra_columns", .default = "allow")

  value_min_rows <-
    purrr::pluck(list_raw, "min_rows", .default = 1L)

  vec_problems_top <-
    c(
      stringr::str_c(
        "missing field '", base::setdiff(vec_required, vec_fields), "'."
      ),
      stringr::str_c(
        "unknown field '",
        base::setdiff(vec_fields, c(vec_required, vec_optional)),
        "'."
      ),
      stringr::str_c(
        base::as.character(base::names(is_text)[!is_text]),
        ": must be a non-empty text value."
      ),
      if (
        "contract_id" %in% vec_fields &&
          !base::identical(value_id, id_expected)
      ) {
        stringr::str_c(
          "contract_id: must equal the file name '", id_expected, "'."
        )
      },
      if (
        "contract_version" %in% vec_fields &&
          !(
            base::is.character(value_version) &&
              base::length(value_version) == 1L &&
              stringr::str_detect(
                value_version,
                "^[0-9]+[.][0-9]+[.][0-9]+$"
              ) %in% TRUE
          )
      ) {
        "contract_version: must be a semantic version such as 1.0.0."
      },
      if (
        "status" %in% vec_fields &&
          !(
            base::length(value_status) == 1L &&
              value_status %in% c("active", "conditional", "retired")
          )
      ) {
        "status: must be 'active', 'conditional' or 'retired'."
      },
      if (
        base::length(value_status) == 1L &&
          value_status %in% c("conditional", "retired") &&
          !(
            base::is.character(value_status_note) &&
              base::length(value_status_note) == 1L &&
              !base::is.na(value_status_note)
          )
      ) {
        "status_note: is required when status is not 'active'."
      },
      if (
        "consumers" %in% vec_fields &&
          !(
            base::is.character(value_consumers) &&
              base::length(value_consumers) > 0L &&
              !base::anyNA(value_consumers)
          )
      ) {
        "consumers: must be a non-empty list of paths."
      },
      if (
        !(
          base::length(value_extra) == 1L &&
            value_extra %in% c("allow", "error")
        )
      ) {
        "extra_columns: must be 'allow' or 'error'."
      },
      if (
        !(
          base::is.numeric(value_min_rows) &&
            base::length(value_min_rows) == 1L &&
            !base::is.na(value_min_rows) &&
            value_min_rows >= 0 &&
            value_min_rows == base::round(value_min_rows)
        )
      ) {
        "min_rows: must be a whole number of at least 0."
      }
    )

  #--------------------------------------------------#
  ## Producer, file and partitioning -----
  #--------------------------------------------------#

  list_producer <-
    purrr::pluck(list_raw, "producer", .default = base::list())

  list_file <-
    purrr::pluck(list_raw, "file", .default = base::list())

  list_partitioning <-
    purrr::pluck(list_raw, "partitioning", .default = base::list())

  vec_templates <-
    purrr::pluck(list_file, "name_templates")

  value_scheme <-
    purrr::pluck(list_partitioning, "scheme", .default = NA_character_)

  value_first <-
    purrr::pluck(list_partitioning, "first")

  value_count <-
    purrr::pluck(list_partitioning, "count")

  value_contiguous <-
    purrr::pluck(list_partitioning, "contiguous", .default = TRUE)

  flag_scheme_valid <-
    base::length(value_scheme) == 1L &&
    value_scheme %in% c("none", "integer", "letter")

  vec_problems_file <-
    c(
      if (
        "producer" %in% vec_fields
      ) {
        c(
          stringr::str_c(
            "producer: missing field '",
            base::setdiff(
              c("repository", "directory"),
              base::as.character(base::names(list_producer))
            ),
            "'."
          ),
          stringr::str_c(
            "producer: unknown field '",
            base::setdiff(
              base::as.character(base::names(list_producer)),
              c("repository", "directory")
            ),
            "'."
          )
        )
      },
      if (
        "file" %in% vec_fields
      ) {
        c(
          if (
            !(
              base::is.character(vec_templates) &&
                base::length(vec_templates) > 0L &&
                !base::anyNA(vec_templates)
            )
          ) {
            "file.name_templates: must be a non-empty list of templates."
          },
          stringr::str_c(
            "file: unknown field '",
            base::setdiff(
              base::as.character(base::names(list_file)),
              c("name_templates", "evidence")
            ),
            "'."
          )
        )
      },
      if (
        "partitioning" %in% vec_fields
      ) {
        c(
          if (
            !flag_scheme_valid
          ) {
            "partitioning.scheme: must be 'none', 'integer' or 'letter'."
          },
          if (
            flag_scheme_valid &&
              value_scheme == "integer" &&
              !(
                base::is.numeric(value_first) &&
                  base::length(value_first) == 1L &&
                  value_first == base::round(value_first)
              )
          ) {
            "partitioning.first: must be a whole number for 'integer'."
          },
          if (
            flag_scheme_valid &&
              value_scheme == "letter" &&
              !(
                base::is.character(value_first) &&
                  base::length(value_first) == 1L &&
                  value_first %in% base::LETTERS
              )
          ) {
            "partitioning.first: must be a capital letter for 'letter'."
          },
          if (
            !base::is.null(value_count) &&
              !(
                base::is.numeric(value_count) &&
                  base::length(value_count) == 1L &&
                  !base::is.na(value_count) &&
                  value_count >= 1 &&
                  value_count == base::round(value_count) &&
                  base::isTRUE(value_scheme %in% c("integer", "letter"))
              )
          ) {
            stringr::str_c(
              "partitioning.count: must be a whole number of at least 1, ",
              "for a partitioned artefact."
            )
          },
          if (
            !(
              base::is.logical(value_contiguous) &&
                base::length(value_contiguous) == 1L &&
                !base::is.na(value_contiguous)
            )
          ) {
            "partitioning.contiguous: must be true or false."
          },
          stringr::str_c(
            "partitioning: unknown field '",
            base::setdiff(
              base::as.character(base::names(list_partitioning)),
              c("scheme", "first", "count", "contiguous", "evidence")
            ),
            "'."
          )
        )
      }
    )

  #--------------------------------------------------#
  ## Columns, keys and dependencies -----
  #--------------------------------------------------#

  list_columns <-
    purrr::pluck(list_raw, "columns")

  vec_problems_columns <-
    if (
      "columns" %in% vec_fields
    ) {
      diagnose_producer_column_specs(
        list_columns = list_columns,
        field_path = "columns"
      )
    }

  vec_column_names <-
    purrr::map_chr(
      .x = list_columns,
      .f = ~ purrr::pluck(.x, "name", .default = NA_character_) |>
        base::as.character()
    )

  # YAML reads `[[a], [b]]` as the vector c("a", "b"), so a key list made
  #   of single columns arrives as a vector; one element is one key
  list_keys <-
    purrr::pluck(list_raw, "keys", .default = base::list()) |>
    base::as.list()

  vec_key_columns <-
    base::unlist(list_keys, use.names = FALSE) |>
    base::as.character()

  list_rounded_keys <-
    purrr::pluck(list_raw, "rounded_keys", .default = base::list())

  is_rounded_key_valid <-
    purrr::map_lgl(
      .x = list_rounded_keys,
      .f = ~ {
        value_digits <- purrr::pluck(.x, "digits")

        base::is.list(.x) &&
          base::is.character(purrr::pluck(.x, "columns")) &&
          base::is.numeric(value_digits) &&
          base::length(value_digits) == 1L &&
          !base::is.na(value_digits) &&
          value_digits >= 0 &&
          value_digits == base::round(value_digits)
      }
    )

  vec_rounded_key_columns <-
    purrr::map(
      .x = list_rounded_keys,
      .f = ~ purrr::pluck(.x, "columns")
    ) |>
    base::unlist(use.names = FALSE) |>
    base::as.character()

  list_dependencies <-
    purrr::pluck(list_raw, "dependencies", .default = base::list())

  vec_dependency_columns <-
    purrr::map(
      .x = list_dependencies,
      .f = ~ c(
        purrr::pluck(.x, "determinant"),
        purrr::pluck(.x, "dependent")
      )
    ) |>
    base::unlist(use.names = FALSE) |>
    base::as.character()

  is_dependency_valid <-
    purrr::map_lgl(
      .x = list_dependencies,
      .f = ~ base::is.list(.x) &&
        base::is.character(purrr::pluck(.x, "determinant")) &&
        base::is.character(purrr::pluck(.x, "dependent"))
    )

  vec_problems_keys <-
    c(
      stringr::str_c(
        "keys: '", base::setdiff(vec_key_columns, vec_column_names),
        "' is not a top-level column."
      ),
      stringr::str_c(
        "rounded_keys: '",
        base::setdiff(vec_rounded_key_columns, vec_column_names),
        "' is not a top-level column."
      ),
      if (
        !base::all(is_rounded_key_valid)
      ) {
        stringr::str_c(
          "rounded_keys: each needs 'columns' and 'digits', a whole ",
          "number of at least 0."
        )
      },
      stringr::str_c(
        "dependencies: '",
        base::setdiff(vec_dependency_columns, vec_column_names),
        "' is not a top-level column."
      ),
      if (
        !base::all(is_dependency_valid)
      ) {
        "dependencies: each needs 'determinant' and 'dependent' columns."
      }
    )

  #--------------------------------------------------#
  ## Variables and relations -----
  #--------------------------------------------------#

  list_variables <-
    purrr::pluck(list_raw, "variables")

  list_table <-
    purrr::pluck(list_variables, "table", .default = base::list())

  value_value_column <-
    purrr::pluck(list_variables, "value_column", .default = NA_character_)

  vec_variable_names <-
    purrr::map_chr(
      .x = list_table,
      .f = ~ purrr::pluck(.x, "variable", .default = NA_character_) |>
        base::as.character()
    )

  # NULL when the contract has no variables, as build_producer_file_regex()
  #   expects
  vec_variable_tokens <-
    if (
      base::is.null(list_variables)
    ) {
      NULL
    } else {
      purrr::map_chr(
        .x = list_table,
        .f = ~ purrr::pluck(.x, "file_token", .default = NA_character_) |>
          base::as.character()
      )
    }

  vec_problems_entries <-
    purrr::imap(
      .x = list_table,
      .f = ~ {
        path_entry <-
          stringr::str_c("variables.table[", .y, "]")

        vec_entry_fields <-
          base::as.character(base::names(.x))

        c(
          stringr::str_c(
            path_entry, ": missing field '",
            base::setdiff(
              c("variable", "file_token", "unit", "description", "evidence"),
              vec_entry_fields
            ),
            "'."
          ),
          stringr::str_c(
            path_entry, ": unknown field '",
            base::setdiff(
              vec_entry_fields,
              c(
                "variable", "file_token", "unit", "description",
                "evidence", "checks"
              )
            ),
            "'."
          ),
          diagnose_producer_check_specs(
            list_checks = purrr::pluck(.x, "checks"),
            field_path = stringr::str_c(path_entry, ".checks")
          )
        )
      }
    ) |>
    base::unlist(use.names = FALSE)

  vec_problems_variables <-
    if (
      base::is.null(list_variables)
    ) {
      base::character(0)
    } else {
      c(
        stringr::str_c(
          "variables: unknown field '",
          base::setdiff(
            base::as.character(base::names(list_variables)),
            c("value_column", "table")
          ),
          "'."
        ),
        if (
          base::length(list_table) == 0L
        ) {
          "variables.table: must list at least one variable."
        },
        if (
          !value_value_column %in% vec_column_names
        ) {
          "variables.value_column: must be a top-level column."
        },
        if (
          base::anyNA(vec_variable_names) ||
            base::anyDuplicated(vec_variable_names) > 0L
        ) {
          "variables.table: 'variable' must be present and unique."
        },
        if (
          base::anyNA(vec_variable_tokens) ||
            base::anyDuplicated(vec_variable_tokens) > 0L
        ) {
          "variables.table: 'file_token' must be present and unique."
        },
        vec_problems_entries
      )
    }

  list_relations <-
    purrr::pluck(list_raw, "relations", .default = base::list())

  is_relation_valid <-
    purrr::map_lgl(
      .x = list_relations,
      .f = ~ base::is.list(.x) &&
        base::is.character(purrr::pluck(.x, "contract_id")) &&
        base::is.character(purrr::pluck(.x, "columns")) &&
        base::is.character(purrr::pluck(.x, "description"))
    )

  vec_problems_relations <-
    if (
      !base::all(is_relation_valid)
    ) {
      "relations: each needs 'contract_id', 'columns' and 'description'."
    }

  #--------------------------------------------------#
  ## File-name templates -----
  #--------------------------------------------------#

  flag_tokens_usable <-
    base::is.null(vec_variable_tokens) ||
    (
      !base::anyNA(vec_variable_tokens) &&
        base::anyDuplicated(vec_variable_tokens) == 0L
    )

  flag_templates_usable <-
    base::is.character(vec_templates) &&
    flag_scheme_valid &&
    flag_tokens_usable

  # Each template gives either a pattern or the reason it cannot be built
  data_templates <-
    if (
      flag_templates_usable
    ) {
      purrr::map(
        .x = vec_templates,
        .f = ~ base::tryCatch(
          expr = tibble::tibble(
            pattern = build_producer_file_regex(
              name_template = .x,
              partition_scheme = value_scheme,
              vec_variable_tokens = vec_variable_tokens
            ),
            problem = NA_character_
          ),
          error = function(error) {
            tibble::tibble(
              pattern = NA_character_,
              problem = base::conditionMessage(error)
            )
          }
        )
      ) |>
        purrr::list_rbind()
    } else {
      tibble::tibble(
        pattern = base::character(0),
        problem = base::character(0)
      )
    }

  vec_template_problems <-
    data_templates |>
    dplyr::filter(!base::is.na(.data[["problem"]])) |>
    dplyr::pull("problem")

  vec_problems_templates <-
    stringr::str_c("file.name_templates: ", vec_template_problems)

  #--------------------------------------------------#
  ## Report or return -----
  #--------------------------------------------------#

  vec_problems <-
    c(
      base::character(0),
      vec_problems_top,
      vec_problems_file,
      vec_problems_columns,
      vec_problems_keys,
      vec_problems_variables,
      vec_problems_relations,
      vec_problems_templates
    )

  if (
    base::length(vec_problems) > 0L
  ) {
    # Messages may quote templates such as {date}; cli would read braces
    #   as glue expressions, so they are doubled
    vec_problems_escaped <-
      vec_problems |>
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
        "Contract {.file {file_contract}} does not follow the contract
        format.",
        vec_problems_escaped
      )
    )
  }

  list_partitioning_complete <-
    c(
      list_partitioning[
        base::setdiff(base::names(list_partitioning), "contiguous")
      ],
      base::list(contiguous = value_contiguous)
    )

  list_file_complete <-
    c(
      list_file,
      base::list(name_patterns = dplyr::pull(data_templates, "pattern"))
    )

  # Fields with defaults replace their raw values as a whole; a recursive
  #   merge would mix old and new key lists
  list_completed <-
    base::list(
      extra_columns = value_extra,
      min_rows = base::as.integer(value_min_rows),
      keys = list_keys,
      rounded_keys = list_rounded_keys,
      dependencies = list_dependencies,
      relations = list_relations,
      notes = purrr::pluck(list_raw, "notes", .default = base::list()),
      partitioning = list_partitioning_complete,
      file = list_file_complete
    )

  res <-
    c(
      list_raw[base::setdiff(vec_fields, base::names(list_completed))],
      list_completed
    )

  return(res)
}
