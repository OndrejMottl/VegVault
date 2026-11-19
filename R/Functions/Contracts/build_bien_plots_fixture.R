#' @title Build the BIEN plots fixture
#' @description
#' Build a small synthetic artefact for the `bien_plots` contract, for
#' tests and for producers checking their export. All values are invented;
#' none comes from a real dataset.
#' @param contract
#' The `bien_plots` contract, as returned by `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file name.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one element of `plot_data` lacks `individual_count` (`column_missing` on
#' `plot_data[].individual_count`).
#' @return
#' A named list with one tibble, named by the file name it is saved under:
#' the contract's file-name template filled with `date_file` and
#' `rlang::hash()` of the tibble.
#' @details
#' Three plots: two in South America and one in central Europe. Two plots
#' share a plot name in different data sources, and one taxon record is
#' presence-only (missing `individual_count`), as in the producer's export.
#' The result is identical on every call. Aborts when `contract` is not the
#' `bien_plots` contract.
build_bien_plots_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "bien_plots.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(purrr::pluck(contract, "contract_id"), "bien_plots"),
    msg = "'contract' must be the bien_plots contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_plots <-
    tibble::tibble(
      datasource_id = c(1, 1, 2),
      datasource = c("SYNTH-A", "SYNTH-A", "SYNTH-B"),
      plot_name = c("P1", "P2", "P1"),
      methodology_reference = c("Synthetic protocol reference", NA, NA),
      methodology_description = c("0.1 ha transect, synthetic", NA, NA),
      longitude = c(-60.12, -60.43, 10.22),
      latitude = c(-10.08, -10.02, 50.12),
      plot_area_ha = c(0.1, 1, 0.05),
      plot_data = base::list(
        tibble::tibble(
          name_matched = c("Synthetica alpha", "Synthetica delta"),
          individual_count = c(12L, 3L)
        ),
        tibble::tibble(
          name_matched = "Synthetica delta",
          individual_count = NA_integer_
        ),
        tibble::tibble(
          name_matched = c("Synthetica beta", "Synthetica alpha"),
          individual_count = c(1L, 7L)
        )
      )
    )

  # The one defect, when asked for: a nested data frame lacks a listed
  #   column
  data_plots_final <-
    if (
      flag_broken
    ) {
      purrr::assign_in(
        data_plots,
        where = base::list("plot_data", 2),
        value = tibble::tibble(name_matched = "Synthetica delta")
      )
    } else {
      data_plots
    }

  name_file <-
    build_producer_file_name(
      name_template = purrr::chuck(contract, "file", "name_templates")[1],
      date = date_file,
      hash = rlang::hash(data_plots_final)
    )

  res <-
    base::list(data_plots_final) |>
    rlang::set_names(name_file)

  return(res)
}
