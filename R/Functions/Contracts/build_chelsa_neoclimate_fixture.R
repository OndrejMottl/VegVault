#' @title Build the CHELSA present-day climate fixture
#' @description
#' Build a small synthetic artefact for the `chelsa_neoclimate` contract,
#' for tests and for producers checking their export. All values are
#' invented; none comes from a real dataset.
#' @param contract
#' The `chelsa_neoclimate` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file names.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one bio12 value equals the storage limit 6553.5 (`value_forbidden`).
#' @return
#' A named list with one tibble per variable of the contract, named by the
#' file name it is saved under: the contract's file-name template filled
#' with the variable's file token, `date_file` and `rlang::hash()` of the
#' tibble.
#' @details
#' Every file holds the same six grid cells: one on each side of the
#' antimeridian at 65.05 N, two in central Europe, one in South America and
#' one at 70.05 N, so that gridpoint-linkage tests can use them. Values are
#' plausible for each variable. The result is identical on every call.
#' Aborts when `contract` is not the `chelsa_neoclimate` contract or lists
#' a variable this fixture has no values for.
build_chelsa_neoclimate_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "chelsa_neoclimate.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "chelsa_neoclimate"
    ),
    msg = "'contract' must be the chelsa_neoclimate contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_grid <-
    tibble::tibble(
      long = c(-179.95, 179.95, 10.05, 10.45, -60.05, 25.05),
      lat = c(65.05, 65.05, 50.05, 50.05, -10.05, 70.05)
    )

  # One plausible value per grid cell, in the order of data_grid
  list_values <-
    base::list(
      bio1 = c(-8.2, -8.4, 8.9, 8.7, 26.1, -1.9),
      bio4 = c(1650.3, 1662, 720.4, 715.9, 85.2, 980.6),
      bio6 = c(-28.4, -28.9, -3.1, -3.4, 21.7, -14.2),
      bio12 = c(420.5, 415, 640.2, 702.8, 2210.4, 480.1),
      bio15 = c(35.2, 36, 18.4, 17.9, 55.6, 24.3),
      bio18 = c(160.4, 158.2, 210.6, 230.1, 380.2, 170.9),
      bio19 = c(90.3, 91, 140.2, 150.8, 420.7, 120.4)
    )

  list_table <-
    purrr::chuck(contract, "variables", "table")

  vec_variables <-
    purrr::map_chr(
      .x = list_table,
      .f = ~ purrr::chuck(.x, "variable")
    )

  vec_tokens <-
    purrr::map_chr(
      .x = list_table,
      .f = ~ purrr::chuck(.x, "file_token")
    )

  vec_unknown <-
    base::setdiff(vec_variables, base::names(list_values))

  if (
    base::length(vec_unknown) > 0L
  ) {
    cli::cli_abort(
      "The fixture has no values for variable{?s} {.val {vec_unknown}}."
    )
  }

  list_files_valid <-
    purrr::map2(
      .x = vec_variables,
      .y = vec_tokens,
      .f = ~ dplyr::mutate(
        data_grid,
        value = purrr::chuck(list_values, .x),
        var_name = stringr::str_c("bio_", .y)
      )
    ) |>
    rlang::set_names(vec_variables)

  # The one defect, when asked for: a cell at the storage limit of the
  #   source raster
  list_files <-
    if (
      flag_broken
    ) {
      purrr::assign_in(
        list_files_valid,
        where = base::list("bio12", "value"),
        value = c(420.5, 415, 6553.5, 702.8, 2210.4, 480.1)
      )
    } else {
      list_files_valid
    }

  name_template <-
    purrr::chuck(contract, "file", "name_templates")[1]

  vec_names <-
    purrr::map2_chr(
      .x = base::unname(list_files),
      .y = vec_tokens,
      .f = ~ build_producer_file_name(
        name_template = name_template,
        date = date_file,
        hash = rlang::hash(.x),
        variable_token = .y
      )
    )

  res <-
    base::unname(list_files) |>
    rlang::set_names(vec_names)

  return(res)
}
