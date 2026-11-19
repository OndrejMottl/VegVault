#' @title Build the CHELSA-TraCE21k palaeoclimate fixture
#' @description
#' Build a small synthetic artefact for the
#' `chelsa_trace21k_palaeoclimate` contract, for tests and for producers
#' checking their export. All values are invented; none comes from a real
#' dataset.
#' @param contract
#' The `chelsa_trace21k_palaeoclimate` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file names.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one bio1 value is 99 degrees (`value_out_of_range`).
#' @return
#' A named list with one tibble per variable and batch, named by the file
#' name it is saved under: the contract's file-name template filled with
#' the variable's file token, the batch number, `date_file` and
#' `rlang::hash()` of the tibble.
#' @details
#' For every variable of the contract: the six grid cells of
#' `build_chelsa_neoclimate_fixture()` at four time slices, time_id 20, 15,
#' -40 and -160 (ages 0, 500, 6000 and 18000), ordered by time slice and
#' split by row order into three batches of eight rows, so that one time
#' slice spans two batches as in the producer. Values shift with age by a
#' fixed amount per variable. The result is identical on every call.
#' Aborts when `contract` is not the `chelsa_trace21k_palaeoclimate`
#' contract or lists a variable this fixture has no values for.
build_chelsa_trace21k_palaeoclimate_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "chelsa_trace21k_palaeoclimate"
    ),
    msg = "'contract' must be the chelsa_trace21k_palaeoclimate contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  vec_time_ids <- c("20", "15", "-40", "-160")

  # Grid cells of the present-day fixture, repeated for every time slice
  data_grid <-
    tidyr::expand_grid(
      time_id = vec_time_ids,
      tibble::tibble(
        long = c(-179.95, 179.95, 10.05, 10.45, -60.05, 25.05),
        lat = c(65.05, 65.05, 50.05, 50.05, -10.05, 70.05)
      )
    )

  # Present-day values per cell and the shift per time slice
  list_base <-
    base::list(
      bio1 = c(-8.2, -8.4, 8.9, 8.7, 26.1, -1.9),
      bio4 = c(1650.3, 1662, 720.4, 715.9, 85.2, 980.6),
      bio6 = c(-28.4, -28.9, -3.1, -3.4, 21.7, -14.2),
      bio12 = c(420.5, 415, 640.2, 702.8, 2210.4, 480.1),
      bio15 = c(35.2, 36, 18.4, 17.9, 55.6, 24.3),
      bio18 = c(160.4, 158.2, 210.6, 230.1, 380.2, 170.9),
      bio19 = c(90.3, 91, 140.2, 150.8, 420.7, 120.4)
    )

  list_shift <-
    base::list(
      bio1 = c(0, -0.4, -1.8, -6),
      bio4 = c(0, 10, 40, 120),
      bio6 = c(0, -0.6, -2.2, -8),
      bio12 = c(0, -10, -60, -150),
      bio15 = c(0, 0.5, 2, 5),
      bio18 = c(0, -5, -20, -60),
      bio19 = c(0, -4, -15, -40)
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
    base::setdiff(vec_variables, base::names(list_base))

  if (
    base::length(vec_unknown) > 0L
  ) {
    cli::cli_abort(
      "The fixture has no values for variable{?s} {.val {vec_unknown}}."
    )
  }

  list_variables_valid <-
    purrr::map(
      .x = vec_variables,
      .f = ~ dplyr::mutate(
        data_grid,
        value = base::round(
          base::rep(purrr::chuck(list_base, .x), times = 4L) +
            base::rep(purrr::chuck(list_shift, .x), each = 6L),
          digits = 4
        )
      ) |>
        dplyr::select("long", "lat", "value", "time_id")
    ) |>
    rlang::set_names(vec_variables)

  # The one defect, when asked for: an impossible annual mean temperature
  list_variables <-
    if (
      flag_broken
    ) {
      purrr::assign_in(
        list_variables_valid,
        where = base::list("bio1", "value", 1),
        value = 99
      )
    } else {
      list_variables_valid
    }

  # Batches of eight rows: the second time slice spans batches 1 and 2
  data_batches <-
    tidyr::expand_grid(
      index_variable = base::seq_along(vec_variables),
      batch = 1:3
    )

  list_files <-
    purrr::map2(
      .x = dplyr::pull(data_batches, "index_variable"),
      .y = dplyr::pull(data_batches, "batch"),
      .f = ~ dplyr::slice(
        list_variables[[.x]],
        ((.y - 1L) * 8L + 1L):(.y * 8L)
      )
    )

  name_template <-
    purrr::chuck(contract, "file", "name_templates")[1]

  vec_names <-
    purrr::pmap_chr(
      .l = base::list(
        list_files,
        dplyr::pull(data_batches, "batch"),
        vec_tokens[dplyr::pull(data_batches, "index_variable")]
      ),
      .f = ~ build_producer_file_name(
        name_template = name_template,
        date = date_file,
        hash = rlang::hash(..1),
        partition = ..2,
        variable_token = ..3
      )
    )

  res <-
    list_files |>
    rlang::set_names(vec_names)

  return(res)
}
