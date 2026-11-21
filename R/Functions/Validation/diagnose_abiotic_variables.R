#' @title Diagnose the abiotic variables against their contracts
#' @description
#' Compare the abiotic variables of a built VegVault database, read-only,
#' with the variables of the climate and soil contracts: every contract
#' variable is present with the contract's unit and description, and no
#' other variable exists.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param data_rules
#' A tibble of value rules, as returned by `build_abiotic_value_rules()`;
#' only `variable`, `unit` and `details` are read.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `abiotic_variables`, with one row per contract variable in rule order
#' and then one per database variable without a rule. A row fails when the
#' variable is missing, occurs more than once, or has another unit or
#' description, and when a database variable has no rule. The observed
#' value is the stored unit and the threshold the contract unit.
#' @details
#' The contracts give the label strings the import writes, so a different
#' label is the defect of VegVault issue 76 (a value published under a
#' unit it does not have), for example the v1 unit of bio4. A missing
#' `details` in a rule is not compared. A variable without a rule fails,
#' because no check covers its values. Opens the database read-only.
#' Aborts only when the database is not the one of the manifest.
#' @seealso [build_abiotic_value_rules()]
#' @examples
#' \dontrun{
#' diagnose_abiotic_variables(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   data_rules = build_abiotic_value_rules()
#' )
#' }
diagnose_abiotic_variables <- function(
  path_database,
  list_build_manifest,
  data_rules
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  assertthat::assert_that(
    base::is.data.frame(data_rules),
    base::all(c("variable", "unit", "details") %in% base::names(data_rules)),
    msg = "'data_rules' must have the columns variable, unit and details."
  )

  data_stored <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT abiotic_variable_name AS variable,",
        "abiotic_variable_unit AS unit_stored,",
        "measure_details AS details_stored",
        "FROM AbioticVariable ORDER BY abiotic_variable_id"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble()

  data_stored_names <-
    data_stored |>
    dplyr::group_by(variable) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      unit_stored = dplyr::first(unit_stored),
      details_stored = dplyr::first(details_stored),
      .groups = "drop"
    )

  # Labels agree per variable across artefacts (build_abiotic_value_rules())
  data_ruled <-
    data_rules |>
    dplyr::distinct(variable, unit, details) |>
    dplyr::left_join(data_stored_names, by = dplyr::join_by(variable)) |>
    dplyr::mutate(
      flag_missing = base::is.na(n_rows),
      flag_repeated = dplyr::coalesce(n_rows > 1L, FALSE),
      flag_unit = !flag_missing & !dplyr::coalesce(unit_stored == unit, FALSE),
      flag_details = !flag_missing & !base::is.na(details) &
        !dplyr::coalesce(details_stored == details, FALSE),
      status = dplyr::if_else(
        flag_missing | flag_repeated | flag_unit | flag_details,
        "fail",
        "pass"
      ),
      message = dplyr::case_when(
        flag_missing ~ stringr::str_c(
          "Variable not in AbioticVariable; the contract expects unit '",
          unit, "'."
        ),
        .default = stringr::str_c(
          dplyr::if_else(
            flag_repeated,
            stringr::str_c(
              "Name in ", n_rows, " rows of AbioticVariable. "
            ),
            ""
          ),
          dplyr::if_else(
            flag_unit,
            stringr::str_c(
              "Stored unit '", dplyr::coalesce(unit_stored, "(none)"),
              "' differs from the contract unit '", unit, "'. "
            ),
            ""
          ),
          dplyr::if_else(
            flag_details,
            stringr::str_c(
              "Stored description '",
              dplyr::coalesce(details_stored, "(none)"),
              "' differs from the contract description '", details, "'. "
            ),
            ""
          ),
          dplyr::if_else(
            status == "pass",
            dplyr::if_else(
              base::is.na(details),
              "Unit as in the contract, which gives no description.",
              "Unit and description as in the contract."
            ),
            ""
          )
        ) |>
          stringr::str_squish()
      )
    )

  # Variables no contract describes
  data_unruled <-
    data_stored |>
    dplyr::distinct(variable, .keep_all = TRUE) |>
    dplyr::filter(!variable %in% dplyr::pull(data_ruled, variable)) |>
    dplyr::transmute(
      variable,
      status = "fail",
      unit_stored,
      unit = NA_character_,
      message = "Has no contract rule, so no check covers its values."
    )

  data_result <-
    dplyr::bind_rows(
      dplyr::select(data_ruled, variable, status, unit_stored, unit, message),
      data_unruled
    )

  res <-
    build_check_result(
      check_id = "abiotic_variables",
      scope = dplyr::pull(data_result, variable),
      status = dplyr::pull(data_result, status),
      observed = dplyr::pull(data_result, unit_stored),
      threshold = dplyr::pull(data_result, unit),
      message = dplyr::pull(data_result, message)
    )

  return(res)
}
