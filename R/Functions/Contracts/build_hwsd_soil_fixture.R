#' @title Build the HWSD soil groups fixture
#' @description
#' Build a small synthetic artefact for the `hwsd_soil` contract, for
#' tests and for producers checking their export. All values are invented;
#' none comes from a real dataset.
#' @param contract
#' The `hwsd_soil` contract, as returned by `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file name.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' `value` is stored as text (`class_mismatch`).
#' @return
#' A named list with one tibble, named by the file name it is saved under:
#' the contract's file-name template filled with `date_file` and
#' `rlang::hash()` of the tibble.
#' @details
#' The six grid cells of `build_chelsa_neoclimate_fixture()` with invented
#' soil-group codes between 1 and 32 and the variable name `HWSD2`. The
#' result is identical on every call. Aborts when `contract` is not the
#' `hwsd_soil` contract.
build_hwsd_soil_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "hwsd_soil.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(purrr::pluck(contract, "contract_id"), "hwsd_soil"),
    msg = "'contract' must be the hwsd_soil contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_soil <-
    tibble::tibble(
      long = c(-179.95, 179.95, 10.05, 10.45, -60.05, 25.05),
      lat = c(65.05, 65.05, 50.05, 50.05, -10.05, 70.05),
      value = c(14, 14, 21, 21, 6, 30),
      var_name = "HWSD2"
    )

  # The one defect, when asked for: class codes exported as text
  data_soil_final <-
    if (
      flag_broken
    ) {
      dplyr::mutate(
        data_soil,
        value = base::as.character(.data[["value"]])
      )
    } else {
      data_soil
    }

  name_file <-
    build_producer_file_name(
      name_template = purrr::chuck(contract, "file", "name_templates")[1],
      date = date_file,
      hash = rlang::hash(data_soil_final)
    )

  res <-
    base::list(data_soil_final) |>
    rlang::set_names(name_file)

  return(res)
}
