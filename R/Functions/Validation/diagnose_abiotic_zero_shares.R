#' @title Diagnose the shares of zeros in the abiotic values
#' @description
#' Compute, in a built VegVault database and read-only, the share of
#' abiotic values exactly 0 per variable, age and latitude band, and flag
#' the shares that the quality rules of the abiotic producer find
#' implausible: a high share, a jump between neighbouring bands, and a
#' share far above the other ages of the same band.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param data_rules
#' A tibble of value rules, as returned by `build_abiotic_value_rules()`;
#' `artefact_id`, `variable`, `age_min` and `age_max` assign each value to
#' its artefact.
#' @param list_thresholds
#' Named list of thresholds by artefact, rule and variable, from
#' `validation: abiotic_values: zero_share` in `config.yml`, for example
#' `list(chelsa_neoclimate = list(max = list(bio1 = 0.05), step =
#' list(bio1 = 0.05)))`. The rules are `max`, `step` and, optionally,
#' `age_deviation`. Only the artefacts listed are evaluated.
#' @param list_exceptions
#' List of accepted exceptions, from `validation: abiotic_values:
#' zero_share_exceptions`. Each entry has `artefact_id`, `variables`,
#' `rules`, `reason` and, optionally, `lat_min` and `lat_max` in degrees.
#' Default: none.
#' @param min_values_per_band
#' Whole number, at least 1. A band with fewer values is not evaluated.
#' Default: 30.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `abiotic_zero_shares`. An artefact and variable without a flagged band
#' gives one `pass` row, scope `<variable> / <artefact>`; otherwise each
#' age with a flagged band gives one `flag` row, scope
#' `<variable> / <artefact> / age <age>`, with the number of flagged bands
#' and rules as the observed value and the first findings in the message.
#' Every row counts the bands not evaluated and the accepted exceptions.
#' @details
#' A band is 1 degree of latitude, from its southern edge up to but not
#' including its northern edge, and a value belongs to the band of the
#' latitude of its gridpoint dataset. The rules, each flagged when its
#' value is above the threshold of the variable:
#' \itemize{
#'   \item `max`: the share of values exactly 0;
#'   \item `step`: the absolute change of that share from the band
#'     directly to the north, reported on the southern band (a cut such as
#'     the v1 bio4 zeros south of 65.7 degrees north jumps there);
#'   \item `age_deviation`: the share minus the median share of the other
#'     ages of the same artefact and variable in the same band.
#' }
#' The rules and thresholds are those of the raster quality check of the
#' abiotic producer (VegVault-abiotic_data issue 16). Its shares are over
#' raster cells, these over gridpoints, which sample the rasters unevenly,
#' so the result asks a reviewer for a judgement and never fails. An
#' exception applies to a band that lies within its latitude limits. The
#' counts are aggregated in SQL in one query. Opens the database
#' read-only. Aborts when the database is not the one of the manifest or
#' when an evaluated artefact lacks the `max` or `step` threshold of one of
#' its variables.
#' @seealso [build_abiotic_value_rules()], [diagnose_abiotic_values()]
#' @examples
#' \dontrun{
#' diagnose_abiotic_zero_shares(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   data_rules = build_abiotic_value_rules(),
#'   list_thresholds = load_config_value(
#'     value = c("validation", "abiotic_values", "zero_share")
#'   )
#' )
#' }
diagnose_abiotic_zero_shares <- function(
  path_database,
  list_build_manifest,
  data_rules,
  list_thresholds,
  list_exceptions = base::list(),
  min_values_per_band = 30L
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  assertthat::assert_that(
    base::is.data.frame(data_rules),
    base::all(
      c("artefact_id", "variable", "age_min", "age_max") %in%
        base::names(data_rules)
    ),
    msg = "'data_rules' must be a table of build_abiotic_value_rules()."
  )

  assertthat::assert_that(
    base::is.list(list_thresholds),
    base::is.list(list_exceptions),
    msg = "'list_thresholds' and 'list_exceptions' must be lists."
  )

  assertthat::assert_that(
    assertthat::is.count(min_values_per_band),
    msg = "'min_values_per_band' must be a whole number of at least 1."
  )

  # Thresholds as a table: artefact_id, rule, variable, threshold
  vec_thresholds <-
    base::unlist(list_thresholds)

  mat_keys <-
    stringr::str_split_fixed(
      base::names(vec_thresholds),
      pattern = stringr::fixed("."),
      n = 3L
    )

  data_thresholds <-
    tibble::tibble(
      artefact_id = mat_keys[, 1L],
      rule = mat_keys[, 2L],
      variable = mat_keys[, 3L],
      threshold = base::as.numeric(vec_thresholds)
    )

  data_rules_evaluated <-
    data_rules |>
    dplyr::filter(artefact_id %in% base::names(list_thresholds)) |>
    dplyr::select(artefact_id, variable, age_min, age_max) |>
    dplyr::mutate(rule_order = dplyr::row_number())

  vec_missing <-
    tidyr::expand_grid(
      dplyr::select(data_rules_evaluated, artefact_id, variable),
      rule = c("max", "step")
    ) |>
    dplyr::anti_join(
      data_thresholds,
      by = dplyr::join_by(artefact_id, variable, rule)
    ) |>
    dplyr::mutate(
      key = stringr::str_c(artefact_id, " ", rule, " ", variable)
    ) |>
    dplyr::pull(key)

  if (
    base::length(vec_missing) > 0L
  ) {
    cli::cli_abort(
      "Zero-share threshold{?s} missing for {.val {vec_missing}}."
    )
  }

  data_exceptions <-
    dplyr::bind_rows(
      tibble::tibble(
        artefact_id = base::character(0),
        variable = base::character(0),
        rule = base::character(0),
        lat_min = base::numeric(0),
        lat_max = base::numeric(0),
        reason = base::character(0)
      ),
      purrr::map(
        .x = list_exceptions,
        .f = ~ tidyr::expand_grid(
          artefact_id = purrr::chuck(.x, "artefact_id"),
          variable = base::unlist(purrr::chuck(.x, "variables")),
          rule = base::unlist(purrr::chuck(.x, "rules")),
          lat_min = base::as.numeric(
            purrr::pluck(.x, "lat_min", .default = -Inf)
          ),
          lat_max = base::as.numeric(
            purrr::pluck(.x, "lat_max", .default = Inf)
          ),
          reason = purrr::chuck(.x, "reason")
        )
      )
    )

  # Values and zeros per variable, age and 1-degree band (floor of the
  #   latitude, without the math functions SQLite may lack)
  data_counts <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT v.abiotic_variable_name AS variable, s.age AS age,",
        "CAST(d.coord_lat AS INTEGER) -",
        "(d.coord_lat < CAST(d.coord_lat AS INTEGER)) AS band_south,",
        "COUNT(a.abiotic_value) AS n_values,",
        "COALESCE(SUM(a.abiotic_value = 0), 0) AS n_zero",
        "FROM AbioticData AS a",
        "JOIN AbioticVariable AS v",
        "ON v.abiotic_variable_id = a.abiotic_variable_id",
        "JOIN Samples AS s ON s.sample_id = a.sample_id",
        "JOIN DatasetSample AS ds ON ds.sample_id = a.sample_id",
        "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
        "WHERE s.age IS NOT NULL AND d.coord_lat IS NOT NULL",
        "GROUP BY 1, 2, 3"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      age = base::as.numeric(age),
      band_south = base::as.integer(band_south),
      n_values = base::as.integer(n_values),
      n_zero = base::as.integer(n_zero)
    )

  # `between()` is part of the join_by() syntax, so it is not namespaced
  data_bands <-
    data_counts |>
    dplyr::inner_join(
      data_rules_evaluated,
      by = dplyr::join_by(variable, between(age, age_min, age_max))
    ) |>
    dplyr::mutate(
      flag_evaluated = n_values >= min_values_per_band,
      share_zero = n_zero / n_values
    )

  data_evaluated <-
    dplyr::filter(data_bands, flag_evaluated)

  # The three rules, each value compared with its threshold
  data_max <-
    data_evaluated |>
    dplyr::mutate(
      rule = "max",
      value = share_zero,
      text_value = base::sprintf("%.3g", share_zero)
    )

  data_step <-
    data_evaluated |>
    dplyr::inner_join(
      dplyr::transmute(
        data_evaluated,
        artefact_id, variable, age,
        band_south = band_south - 1L,
        share_north = share_zero
      ),
      by = dplyr::join_by(artefact_id, variable, age, band_south)
    ) |>
    dplyr::mutate(
      rule = "step",
      value = base::abs(share_zero - share_north),
      text_value = stringr::str_c(
        base::sprintf("%.3g", share_zero), " against ",
        base::sprintf("%.3g", share_north),
        " to the north"
      )
    )

  data_age <-
    data_evaluated |>
    dplyr::group_by(artefact_id, variable, band_south) |>
    dplyr::filter(dplyr::n() > 1L) |>
    dplyr::mutate(
      share_other = purrr::map_dbl(
        .x = dplyr::row_number(),
        .f = ~ stats::median(share_zero[-.x])
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      rule = "age_deviation",
      value = share_zero - share_other,
      text_value = stringr::str_c(
        base::sprintf("%.3g", share_zero),
        " against a median of ",
        base::sprintf("%.3g", share_other),
        " at the other ages"
      )
    )

  data_findings <-
    dplyr::bind_rows(data_max, data_step, data_age) |>
    dplyr::inner_join(
      data_thresholds,
      by = dplyr::join_by(artefact_id, variable, rule)
    ) |>
    dplyr::filter(value > threshold) |>
    dplyr::mutate(band_north = band_south + 1L) |>
    dplyr::left_join(
      data_exceptions,
      by = dplyr::join_by(
        artefact_id, variable, rule,
        band_south >= lat_min, band_north <= lat_max
      ),
      multiple = "first"
    ) |>
    dplyr::mutate(
      flag_excepted = !base::is.na(reason),
      text_finding = stringr::str_c(
        dplyr::case_when(
          rule == "max" ~ "zero share",
          rule == "step" ~ "zero-share step",
          .default = "zero-share deviation"
        ),
        " above ", base::sprintf("%.3g", threshold),
        " in band ", band_south, " to ", band_north, " (", text_value, ")"
      )
    )

  # Totals per artefact and variable, over all ages
  data_totals <-
    data_rules_evaluated |>
    dplyr::left_join(
      data_bands |>
        dplyr::group_by(artefact_id, variable) |>
        dplyr::summarise(
          n_evaluated = base::sum(flag_evaluated),
          n_skipped = base::sum(!flag_evaluated),
          .groups = "drop"
        ),
      by = dplyr::join_by(artefact_id, variable)
    ) |>
    dplyr::left_join(
      data_findings |>
        dplyr::filter(flag_excepted) |>
        dplyr::count(artefact_id, variable, name = "n_excepted"),
      by = dplyr::join_by(artefact_id, variable)
    ) |>
    dplyr::mutate(
      dplyr::across(
        .cols = c(n_evaluated, n_skipped, n_excepted),
        .fns = ~ dplyr::coalesce(base::as.integer(.x), 0L)
      ),
      text_totals = stringr::str_c(
        "Over all ages, bands evaluated: ", n_evaluated,
        ", not evaluated (fewer than ", min_values_per_band, " values): ",
        n_skipped, ", accepted exceptions: ", n_excepted, "."
      )
    )

  data_flags <-
    data_findings |>
    dplyr::filter(!flag_excepted) |>
    dplyr::arrange(age, band_south, rule) |>
    dplyr::group_by(artefact_id, variable, age) |>
    dplyr::summarise(
      n_findings = dplyr::n(),
      text_findings = stringr::str_c(
        utils::head(text_finding, 5L),
        collapse = "; "
      ),
      .groups = "drop"
    ) |>
    dplyr::inner_join(
      data_totals,
      by = dplyr::join_by(artefact_id, variable)
    ) |>
    dplyr::transmute(
      rule_order,
      age,
      scope = stringr::str_c(
        variable, " / ", artefact_id, " / age ",
        base::sprintf("%.7g", age)
      ),
      status = "flag",
      observed = n_findings,
      message = stringr::str_c(
        stringr::str_replace(text_findings, "^z", "Z"),
        dplyr::if_else(
          n_findings > 5L,
          stringr::str_c("; and ", n_findings - 5L, " more"),
          ""
        ),
        ". ", text_totals
      )
    )

  data_passes <-
    data_totals |>
    dplyr::anti_join(
      data_flags,
      by = dplyr::join_by(rule_order)
    ) |>
    dplyr::transmute(
      rule_order,
      age = -Inf,
      scope = stringr::str_c(variable, " / ", artefact_id),
      status = "pass",
      observed = 0L,
      message = stringr::str_c("No flagged band. ", text_totals)
    )

  data_result <-
    dplyr::bind_rows(data_flags, data_passes) |>
    dplyr::arrange(rule_order, age)

  res <-
    build_check_result(
      check_id = "abiotic_zero_shares",
      scope = dplyr::pull(data_result, scope),
      status = dplyr::pull(data_result, status),
      observed = dplyr::pull(data_result, observed),
      message = dplyr::pull(data_result, message)
    )

  return(res)
}
