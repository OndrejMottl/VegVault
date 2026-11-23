#' @title Diagnose the units of the trait values
#' @description
#' Check, read-only, that every trait value of a built VegVault database
#' is stored in the unit its conversion rules produce, and that every
#' value is a finite number: what the schema's keys and foreign keys
#' cannot express.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check `trait_units`:
#' one `pass` row with scope `TraitsValue` and the number of trait values
#' as the observed value when every value is right, otherwise one `fail`
#' row per trait domain with wrong values, scope the domain name, the
#' number of wrong values as the observed value, 0 as the threshold, and
#' the count of each kind of problem in the message.
#' @details
#' The unit of a value is the unit of its trait's domain
#' (`TraitsDomain.trait_unit`). It must equal the unit its rules produce:
#' the `output_unit` of its derivation (`TraitDerivation`) when it has one,
#' otherwise the `standardized_unit` of its conversion
#' (`TraitUnitConversion`). A derivation must start from the unit the
#' conversion produces (`input_unit` equals `standardized_unit`). A value
#' must be present and finite. The schema already requires a conversion
#' rule for every value, one unit per domain and unique keys, and
#' `diagnose_foreign_keys()` checks that the rules exist; a value whose
#' rule or domain is missing fails here too. A value with a missing domain
#' is reported under `(none)`. Opens the database read-only. Aborts only
#' when the database is not the one of the manifest.
#' @seealso [diagnose_foreign_keys()]
#' @examples
#' \dontrun{
#' diagnose_trait_units(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_trait_units <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  # Per domain: the values, and the values with each kind of problem. An
  #   infinite REAL is larger than the largest double; NaN is stored as NULL
  data_domains <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT COALESCE(d.trait_domain_name, '(none)') AS scope,",
        "COUNT(*) AS n_values,",
        "SUM(COALESCE(r.output_unit, c.standardized_unit)",
        "IS NOT d.trait_unit) AS n_unit,",
        "SUM(v.trait_derivation_id IS NOT NULL",
        "AND r.input_unit IS NOT c.standardized_unit) AS n_input,",
        "SUM(v.trait_value IS NULL",
        "OR ABS(v.trait_value) > 1.7976931348623157e308) AS n_value,",
        "SUM(",
        "COALESCE(r.output_unit, c.standardized_unit) IS NOT d.trait_unit",
        "OR (v.trait_derivation_id IS NOT NULL",
        "AND r.input_unit IS NOT c.standardized_unit)",
        "OR v.trait_value IS NULL",
        "OR ABS(v.trait_value) > 1.7976931348623157e308",
        ") AS n_wrong",
        "FROM TraitsValue AS v",
        "LEFT JOIN Traits AS t ON t.trait_id = v.trait_id",
        "LEFT JOIN TraitsDomain AS d ON d.trait_domain_id = t.trait_domain_id",
        "LEFT JOIN TraitUnitConversion AS c",
        "ON c.trait_unit_conversion_id = v.trait_unit_conversion_id",
        "LEFT JOIN TraitDerivation AS r",
        "ON r.trait_derivation_id = v.trait_derivation_id",
        "GROUP BY 1",
        sep = " "
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = c(n_values, n_unit, n_input, n_value, n_wrong),
        .fns = ~ base::as.integer(dplyr::coalesce(.x, 0))
      )
    ) |>
    dplyr::arrange(scope)

  data_wrong <-
    dplyr::filter(data_domains, n_wrong > 0L)

  res <-
    if (
      base::nrow(data_wrong) == 0L
    ) {
      build_check_result(
        check_id = "trait_units",
        scope = "TraitsValue",
        status = "pass",
        observed = base::sum(dplyr::pull(data_domains, n_values)),
        threshold = 0L,
        message = stringr::str_c(
          "Every trait value is finite and in the unit of its rules."
        )
      )
    } else {
      build_check_result(
        check_id = "trait_units",
        scope = dplyr::pull(data_wrong, scope),
        status = "fail",
        observed = dplyr::pull(data_wrong, n_wrong),
        threshold = 0L,
        message = stringr::str_c(
          "Trait values of ", dplyr::pull(data_wrong, scope), ": ",
          dplyr::pull(data_wrong, n_unit),
          " not in the unit of its rule, ",
          dplyr::pull(data_wrong, n_input),
          " with a derivation from another input unit, ",
          dplyr::pull(data_wrong, n_value),
          " missing or not finite (of ",
          dplyr::pull(data_wrong, n_values), ")."
        )
      )
    }

  return(res)
}
