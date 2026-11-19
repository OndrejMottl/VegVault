#' @title Build the sPlotOpen plots fixture
#' @description
#' Build a small synthetic artefact for the `splot_plots` contract, for
#' tests and for producers checking their export. All values are invented;
#' none comes from a real dataset.
#' @param contract
#' The `splot_plots` contract, as returned by `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file name.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' two plots share `plot_observation_id` (`key_duplicate`).
#' @return
#' A named list with one tibble, named by the file name it is saved under:
#' the contract's file-name template filled with `date_file` and
#' `rlang::hash()` of the tibble.
#' @details
#' Three plots: two in central Europe and one at 65.05 N next to the
#' antimeridian, so that gridpoint-linkage tests can use them. The result
#' is identical on every call. Aborts when `contract` is not the
#' `splot_plots` contract.
build_splot_plots_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "splot_plots.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(purrr::pluck(contract, "contract_id"), "splot_plots"),
    msg = "'contract' must be the splot_plots contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_plots <-
    tibble::tibble(
      plot_observation_id = c(101, 102, 103),
      givd_id = c("XX-SY-001", "XX-SY-001", "XX-SY-002"),
      dataset = c("Synthetic plots A", "Synthetic plots A", "Synthetic B"),
      longitude = c(10.12, 10.43, 179.95),
      latitude = c(50.08, 50.02, 65.05),
      releve_area = c(100, 25, 400),
      taxa = base::list(
        tibble::tibble(
          Species = c("Synthetica alpha", "Synthetica beta"),
          Original_abundance = c(40, 5),
          Abundance_scale = "percentage"
        ),
        tibble::tibble(
          Species = c("Synthetica alpha", "Synthetica delta"),
          Original_abundance = c(10, 2),
          Abundance_scale = "percentage"
        ),
        tibble::tibble(
          Species = "Synthetica gamma",
          Original_abundance = 1,
          Abundance_scale = "presence"
        )
      )
    )

  # The one defect, when asked for: two plots share an identifier
  data_plots_final <-
    if (
      flag_broken
    ) {
      dplyr::mutate(
        data_plots,
        plot_observation_id = c(101, 102, 102)
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
