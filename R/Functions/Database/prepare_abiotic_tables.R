#' @title Prepare the tables of one abiotic variable
#' @description
#' Attach the values of one climate or soil variable to the gridpoint
#' samples of the same rounded coordinates and age, and return them with
#' the variable and its references as source tables of
#' `build_source_table_template()`.
#' @param data_values
#' A data frame of one variable with `long`, `lat` and `value`, and
#' `time_id` when `sel_age_rule` is `"time_id"`.
#' @param data_gridpoints
#' A data frame with `coord_long`, `coord_lat`, `age` and `sample_name`,
#' one row per gridpoint (see `prepare_position_tables()`).
#' @param list_variable
#' Named list with the text scalars `name`, `unit` and `details` of the
#' variable, for example from the `variables` table of the producer
#' contract.
#' @param data_references
#' A data frame with `reference_detail` and `mandatory`: the references of
#' the variable in this artefact (see `prepare_config_references()` with
#' the role `"abiotic_variable"`).
#' @param sel_age_rule
#' Character scalar: `"present"` for present-day and soil values (age 0),
#' or `"time_id"` for palaeoclimate values, whose age is
#' `-time_id * 100 + 2000` (years before 1950).
#' @param n_coordinate_digits
#' Whole number. Decimals of the gridpoint coordinates (`link:
#' coordinate_digits` in `config.yml`). Default: 2.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`: `abiotic_variables` (one row),
#' `abiotic_variable_references` and `abiotic_values` (`sample_name`,
#' `abiotic_variable_name`, `abiotic_value`), the other elements empty.
#' @details
#' Coordinates are rounded to `n_coordinate_digits` and matched exactly to
#' the gridpoints, as v1.0.0 matched the names `geo_<long>_<lat>_<age>`.
#' Values of cells or ages without a gridpoint are not stored, because only
#' linked gridpoints exist. With the `"time_id"` rule, values of age 0 are
#' left out: the present-day artefact gives the values of age 0, as in
#' v1.0.0. A missing value is stored as missing. Aborts when a column is
#' missing, when `list_variable` lacks a field, or when two rows of
#' `data_values` reach the same gridpoint.
#' @seealso [build_database_tables()]
#' @examples
#' \dontrun{
#' list_bio1_tables <-
#'   prepare_abiotic_tables(
#'     data_values = data_chelsa_neoclimate_bio1,
#'     data_gridpoints = purrr::chuck(list_positions, "gridpoints"),
#'     list_variable = base::list(
#'       name = "bio1",
#'       unit = "C (degree Celsius)",
#'       details = "mean annual air temperature"
#'     ),
#'     data_references = data_chelsa_references,
#'     sel_age_rule = "present"
#'   )
#' }
prepare_abiotic_tables <- function(
  data_values,
  data_gridpoints,
  list_variable,
  data_references,
  sel_age_rule,
  n_coordinate_digits = 2L,
  verbose = TRUE
) {
  vec_rules <-
    c("present", "time_id")

  assertthat::assert_that(
    base::is.character(sel_age_rule),
    base::length(sel_age_rule) == 1L,
    sel_age_rule %in% vec_rules,
    msg = "`sel_age_rule` must be \"present\" or \"time_id\"."
  )

  vec_required <-
    c(
      "long", "lat", "value",
      if (
        sel_age_rule == "time_id"
      ) {
        "time_id"
      }
    )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_values))

  assertthat::assert_that(
    base::is.data.frame(data_values),
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_values` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
    )
  )

  assertthat::assert_that(
    base::is.data.frame(data_gridpoints),
    base::all(
      c("coord_long", "coord_lat", "age", "sample_name") %in%
        base::names(data_gridpoints)
    ),
    msg = stringr::str_c(
      "`data_gridpoints` must hold `coord_long`, `coord_lat`, `age` and ",
      "`sample_name`."
    )
  )

  vec_absent_fields <-
    base::setdiff(c("name", "unit", "details"), base::names(list_variable))

  assertthat::assert_that(
    base::is.list(list_variable),
    base::length(vec_absent_fields) == 0L,
    msg = stringr::str_c(
      "`list_variable` lacks the fields: ",
      stringr::str_c(vec_absent_fields, collapse = ", ")
    )
  )

  assertthat::assert_that(
    base::is.data.frame(data_references),
    base::all(
      c("reference_detail", "mandatory") %in% base::names(data_references)
    ),
    msg = "`data_references` must hold `reference_detail` and `mandatory`."
  )

  assertthat::assert_that(
    base::is.numeric(n_coordinate_digits),
    base::length(n_coordinate_digits) == 1L,
    !base::is.na(n_coordinate_digits),
    n_coordinate_digits >= 0,
    n_coordinate_digits == base::round(n_coordinate_digits),
    msg = "`n_coordinate_digits` must be a whole number of at least 0."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  name_variable <-
    base::as.character(purrr::chuck(list_variable, "name"))

  # Rounded as the gridpoint cells were, aged by the rule of the artefact
  data_placed <-
    data_values |>
    dplyr::mutate(
      coord_long = base::round(base::as.numeric(long), n_coordinate_digits),
      coord_lat = base::round(base::as.numeric(lat), n_coordinate_digits),
      age = if (
        sel_age_rule == "time_id"
      ) {
        -base::as.numeric(time_id) * 100 + 2000
      } else {
        0
      }
    )

  # The palaeoclimate values of age 0 are given by the present-day data
  data_aged <-
    if (
      sel_age_rule == "time_id"
    ) {
      dplyr::filter(data_placed, age > 0)
    } else {
      data_placed
    }

  data_matched <-
    dplyr::inner_join(
      dplyr::select(data_aged, coord_long, coord_lat, age, value),
      dplyr::select(data_gridpoints, coord_long, coord_lat, age, sample_name),
      by = dplyr::join_by(coord_long, coord_lat, age),
      relationship = "many-to-one"
    )

  n_repeated <-
    data_matched |>
    dplyr::count(sample_name) |>
    dplyr::filter(n > 1L) |>
    base::nrow()

  if (
    n_repeated > 0L
  ) {
    cli::cli_abort(
      "{name_variable}: {n_repeated} gridpoint{?s} get{?s/} more than one
      value from rows of the same rounded coordinates and age."
    )
  }

  data_variable <-
    tibble::tibble(
      abiotic_variable_name = name_variable,
      abiotic_variable_unit = base::as.character(
        purrr::chuck(list_variable, "unit")
      ),
      measure_details = base::as.character(
        purrr::chuck(list_variable, "details")
      )
    )

  list_tables <-
    base::list(
      abiotic_variables = data_variable,
      abiotic_variable_references = dplyr::cross_join(
        dplyr::select(data_variable, abiotic_variable_name),
        dplyr::select(data_references, reference_detail, mandatory)
      ),
      abiotic_values = data_matched |>
        dplyr::mutate(
          abiotic_variable_name = name_variable,
          abiotic_value = base::as.numeric(value)
        ) |>
        dplyr::select(sample_name, abiotic_variable_name, abiotic_value)
    )

  # Every element of the template, with its columns and types
  res <-
    build_source_table_template() |>
    purrr::imap(
      .f = ~ dplyr::bind_rows(.x, purrr::pluck(list_tables, .y))
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      "{name_variable}: {base::nrow(data_matched)} value{?s} of
      {base::nrow(data_values)} row{?s} attached to gridpoints."
    )
  }

  return(res)
}
