#' @title Diagnose the abiotic values against their contracts
#' @description
#' Count, in a built VegVault database and read-only, the abiotic values
#' that break the value rules of their contract: missing values, values
#' outside the plausible range, forbidden values, values that are not
#' allowed and values that are not whole numbers. Values at a known
#' storage cap of the source are counted separately.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param data_rules
#' A tibble of value rules, as returned by `build_abiotic_value_rules()`.
#' @param list_capped_values
#' Named list of storage caps by artefact and variable, for example
#' `list(chelsa_neoclimate = list(bio12 = 6553.5))`, from
#' `validation: abiotic_values: capped_values` in `config.yml`. Default:
#' no caps.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `abiotic_values`: one row per rule, scope `<variable> / <artefact>`,
#' then one row per ruled variable with values at ages no rule covers,
#' scope `<variable> / no rule`. A rule row fails when any value breaks a
#' rule, with the number of such values as the observed value; otherwise
#' it is a `flag` when values sit at the storage cap, with their number as
#' the observed value; otherwise it passes. The message gives the number
#' of values, their range and each count above zero. A row of values
#' without a rule fails.
#' @details
#' A value belongs to the rule of its variable whose ages include the age
#' of its sample. Forbidden values and caps match with the relative
#' tolerance of the producer validator (`1e-9`, at least `1e-9`); allowed
#' values must match exactly. A value at a cap is a lower bound, not an
#' error: VegVault 2.0.0 keeps the CHELSA V2.1 bio12 values at 6553.5 and
#' documents them (VegVault issue 78). The values of each rule are read in
#' one query, aggregated in SQL. Opens the database read-only. Aborts when
#' the database is not the one of the manifest.
#' @seealso [build_abiotic_value_rules()], [diagnose_abiotic_zero_shares()]
#' @examples
#' \dontrun{
#' diagnose_abiotic_values(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   data_rules = build_abiotic_value_rules(),
#'   list_capped_values = list(chelsa_neoclimate = list(bio12 = 6553.5))
#' )
#' }
diagnose_abiotic_values <- function(
  path_database,
  list_build_manifest,
  data_rules,
  list_capped_values = base::list()
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  vec_columns_rules <-
    c(
      "artefact_id", "variable", "age_min", "age_max", "range_min",
      "range_max", "flag_min_inclusive", "flag_max_inclusive",
      "list_forbidden", "list_allowed", "flag_whole_number"
    )

  assertthat::assert_that(
    base::is.data.frame(data_rules),
    base::all(vec_columns_rules %in% base::names(data_rules)),
    msg = "'data_rules' must be a table of build_abiotic_value_rules()."
  )

  assertthat::assert_that(
    base::is.list(list_capped_values),
    msg = "'list_capped_values' must be a list."
  )

  # One SQL condition per rule part; "0" when the contract sets none.
  #   Forbidden values and caps match within the validator's tolerance
  sql_value <- "a.abiotic_value"

  data_conditions <-
    data_rules |>
    dplyr::mutate(
      value_cap = purrr::map2_dbl(
        .x = artefact_id,
        .y = variable,
        .f = ~ base::as.numeric(
          purrr::pluck(list_capped_values, .x, .y, .default = NA_real_)
        )
      ),
      sql_below = dplyr::case_when(
        !base::is.finite(range_min) ~ "0",
        flag_min_inclusive ~ stringr::str_c(
          sql_value, " < ", base::sprintf("%.17g", range_min)
        ),
        .default = stringr::str_c(
          sql_value, " <= ", base::sprintf("%.17g", range_min)
        )
      ),
      sql_above = dplyr::case_when(
        !base::is.finite(range_max) ~ "0",
        flag_max_inclusive ~ stringr::str_c(
          sql_value, " > ", base::sprintf("%.17g", range_max)
        ),
        .default = stringr::str_c(
          sql_value, " >= ", base::sprintf("%.17g", range_max)
        )
      ),
      sql_forbidden = purrr::map_chr(
        .x = list_forbidden,
        .f = ~ dplyr::if_else(
          base::length(.x) == 0L,
          "0",
          stringr::str_c(
            "(",
            stringr::str_c(
              sql_value, " BETWEEN ",
              base::sprintf("%.17g", .x - 1e-9 * base::pmax(1, base::abs(.x))),
              " AND ",
              base::sprintf("%.17g", .x + 1e-9 * base::pmax(1, base::abs(.x))),
              collapse = " OR "
            ),
            ")"
          )
        )
      ),
      sql_not_allowed = purrr::map_chr(
        .x = list_allowed,
        .f = ~ dplyr::if_else(
          base::length(.x) == 0L,
          "0",
          stringr::str_c(
            sql_value, " NOT IN (",
            stringr::str_c(base::sprintf("%.17g", .x), collapse = ", "),
            ")"
          )
        )
      ),
      sql_not_whole = dplyr::if_else(
        flag_whole_number,
        stringr::str_c(sql_value, " <> CAST(", sql_value, " AS INTEGER)"),
        "0"
      ),
      sql_capped = dplyr::if_else(
        base::is.na(value_cap),
        "0",
        stringr::str_c(
          sql_value, " BETWEEN ",
          base::sprintf("%.17g", value_cap - 1e-9 * base::pmax(1, value_cap)),
          " AND ",
          base::sprintf("%.17g", value_cap + 1e-9 * base::pmax(1, value_cap))
        )
      ),
      sql_age = stringr::str_c(
        dplyr::if_else(
          base::is.finite(age_min),
          stringr::str_c("s.age >= ", base::sprintf("%.17g", age_min)),
          "1"
        ),
        " AND ",
        dplyr::if_else(
          base::is.finite(age_max),
          stringr::str_c("s.age <= ", base::sprintf("%.17g", age_max)),
          "1"
        )
      ),
      sql_missing = stringr::str_c(sql_value, " IS NULL"),
      statement = stringr::str_c(
        "SELECT COUNT(*) AS n_values,",
        " COALESCE(SUM(", sql_missing, "), 0) AS n_missing,",
        " COALESCE(SUM(", sql_below, "), 0) AS n_below,",
        " COALESCE(SUM(", sql_above, "), 0) AS n_above,",
        " COALESCE(SUM(", sql_forbidden, "), 0) AS n_forbidden,",
        " COALESCE(SUM(", sql_not_allowed, "), 0) AS n_not_allowed,",
        " COALESCE(SUM(", sql_not_whole, "), 0) AS n_not_whole,",
        " COALESCE(SUM(", sql_missing, " OR ", sql_below, " OR ", sql_above,
        " OR ", sql_forbidden, " OR ", sql_not_allowed, " OR ",
        sql_not_whole, "), 0) AS n_bad,",
        " COALESCE(SUM(", sql_capped, "), 0) AS n_capped,",
        " MIN(", sql_value, ") AS value_min,",
        " MAX(", sql_value, ") AS value_max",
        " FROM AbioticData AS a",
        " JOIN AbioticVariable AS v",
        " ON v.abiotic_variable_id = a.abiotic_variable_id",
        " JOIN Samples AS s ON s.sample_id = a.sample_id",
        " WHERE v.abiotic_variable_name = ? AND ", sql_age
      )
    )

  data_counts <-
    purrr::map2(
      .x = dplyr::pull(data_conditions, statement),
      .y = dplyr::pull(data_conditions, variable),
      .f = ~ run_with_database(
        path_database = path_database,
        fn = DBI::dbGetQuery,
        statement = .x,
        params = base::list(.y),
        flag_read_only = TRUE
      )
    ) |>
    dplyr::bind_rows() |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::starts_with("n_"),
        .fns = base::as.integer
      )
    )

  data_ruled <-
    dplyr::bind_cols(
      dplyr::select(
        data_conditions,
        artefact_id, variable, range_min, range_max, flag_min_inclusive,
        flag_max_inclusive, value_cap
      ),
      data_counts
    ) |>
    dplyr::mutate(
      scope = stringr::str_c(variable, " / ", artefact_id),
      status = dplyr::case_when(
        n_bad > 0L ~ "fail",
        n_capped > 0L ~ "flag",
        .default = "pass"
      ),
      observed = dplyr::case_when(
        status == "fail" ~ n_bad,
        status == "flag" ~ n_capped,
        .default = 0L
      ),
      # Numbers in the message, each formatted on its own
      text_min = base::sprintf("%.7g", value_min),
      text_max = base::sprintf("%.7g", value_max),
      text_range_min = base::sprintf("%.7g", range_min),
      text_range_max = base::sprintf("%.7g", range_max),
      text_cap = base::sprintf("%.7g", value_cap),
      part_missing = dplyr::if_else(
        n_missing > 0L,
        stringr::str_c("missing: ", n_missing),
        NA_character_
      ),
      part_below = dplyr::if_else(
        n_below > 0L,
        stringr::str_c(
          dplyr::if_else(flag_min_inclusive, "below ", "at or below "),
          text_range_min, ": ", n_below
        ),
        NA_character_
      ),
      part_above = dplyr::if_else(
        n_above > 0L,
        stringr::str_c(
          dplyr::if_else(flag_max_inclusive, "above ", "at or above "),
          text_range_max, ": ", n_above
        ),
        NA_character_
      ),
      part_forbidden = dplyr::if_else(
        n_forbidden > 0L,
        stringr::str_c("equal to a forbidden value: ", n_forbidden),
        NA_character_
      ),
      part_not_allowed = dplyr::if_else(
        n_not_allowed > 0L,
        stringr::str_c("not an allowed value: ", n_not_allowed),
        NA_character_
      ),
      part_not_whole = dplyr::if_else(
        n_not_whole > 0L,
        stringr::str_c("not a whole number: ", n_not_whole),
        NA_character_
      ),
      part_capped = dplyr::if_else(
        n_capped > 0L,
        stringr::str_c(
          "at the storage cap ", text_cap,
          ", a lower bound: ", n_capped
        ),
        NA_character_
      ),
      text_parts = purrr::map_chr(
        .x = base::seq_along(part_missing),
        .f = ~ stringr::str_c(
          stats::na.omit(
            c(
              part_missing[.x], part_below[.x], part_above[.x],
              part_forbidden[.x], part_not_allowed[.x], part_not_whole[.x],
              part_capped[.x]
            )
          ),
          collapse = "; "
        )
      ),
      message = dplyr::case_when(
        n_values == 0L ~ "No values.",
        base::nzchar(text_parts) ~ stringr::str_c(
          n_values, " values from ", text_min, " to ", text_max, "; ",
          text_parts, "."
        ),
        .default = stringr::str_c(
          n_values, " values from ", text_min, " to ", text_max, "."
        )
      )
    )

  # Values of a ruled variable at ages that no rule covers
  data_totals <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT v.abiotic_variable_name AS variable, COUNT(*) AS n_total",
        "FROM AbioticData AS a JOIN AbioticVariable AS v",
        "ON v.abiotic_variable_id = a.abiotic_variable_id GROUP BY 1"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble()

  data_unruled <-
    data_ruled |>
    dplyr::group_by(variable) |>
    dplyr::summarise(n_matched = base::sum(n_values), .groups = "drop") |>
    dplyr::inner_join(data_totals, by = dplyr::join_by(variable)) |>
    dplyr::mutate(n_unruled = base::as.integer(n_total - n_matched)) |>
    dplyr::filter(n_unruled > 0L) |>
    dplyr::arrange(
      base::match(variable, dplyr::pull(data_ruled, variable))
    ) |>
    dplyr::transmute(
      scope = stringr::str_c(variable, " / no rule"),
      status = "fail",
      observed = n_unruled,
      message = stringr::str_c(
        "Values without an age or at ages that no rule covers: ",
        n_unruled, " of ", n_total, "."
      )
    )

  data_result <-
    dplyr::bind_rows(
      dplyr::select(data_ruled, scope, status, observed, message),
      data_unruled
    )

  res <-
    build_check_result(
      check_id = "abiotic_values",
      scope = dplyr::pull(data_result, scope),
      status = dplyr::pull(data_result, status),
      observed = dplyr::pull(data_result, observed),
      threshold = 0L,
      message = dplyr::pull(data_result, message)
    )

  return(res)
}
