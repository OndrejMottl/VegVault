#' @title Build the FOSSILPOL assembly fixture
#' @description
#' Build a small synthetic artefact for the `fossilpol_assembly` contract,
#' for tests and for producers checking their export. All values are
#' invented; none comes from a real dataset.
#' @param contract
#' The `fossilpol_assembly` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file name.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one level has a missing `age` (`value_missing` on `levels[].age`).
#' @return
#' A named list with one tibble, named by the file name it is saved under:
#' the contract's first file-name template (the `.qs` one) filled with
#' `date_file` and `rlang::hash()` of the tibble.
#' @details
#' Two datasets with three levels each, one at 70.08 N and one at 65.05 N
#' next to the antimeridian, with harmonised counts of invented taxa. One
#' level is younger than 1950 (negative age) and one dataset has no DOI.
#' The levels match `build_fossilpol_age_uncertainty_fixture()`. The result
#' is identical on every call. Aborts when `contract` is not the
#' `fossilpol_assembly` contract.
build_fossilpol_assembly_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "fossilpol_assembly.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "fossilpol_assembly"
    ),
    msg = "'contract' must be the fossilpol_assembly contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  vec_samples_first <- c("90001_1", "90001_2", "90001_3")

  vec_samples_second <- c("90002_1", "90002_2", "90002_3")

  data_assembly <-
    tibble::tibble(
      dataset_id = c("90001", "90002"),
      sitename = c("Synthetic lake", "Synthetic mire"),
      long = c(25.12, 179.95),
      lat = c(70.08, 65.05),
      depositionalenvironment = c("Lake", "Peat"),
      levels = base::list(
        tibble::tibble(
          sample_id = vec_samples_first,
          depth = c(5, 50, 150),
          age = c(-55, 1210, 9830)
        ),
        tibble::tibble(
          sample_id = vec_samples_second,
          depth = c(10, 80, 200),
          age = c(150, 4020, 17950)
        )
      ),
      source_of_data = "Neotoma",
      doi = c("10.0000/synthetic.90001", NA),
      counts_harmonised = base::list(
        tibble::tibble(
          sample_id = vec_samples_first,
          `Synthetica alpha` = c(120, 85, 40),
          `Synthetica beta` = c(0, 12, 66)
        ),
        tibble::tibble(
          sample_id = vec_samples_second,
          `Synthetica alpha` = c(30, 0, 5),
          `Synthetica gamma` = c(200, 150, 90)
        )
      )
    )

  # The one defect, when asked for: a level without an age, which the v1
  #   import would have turned into age 0
  data_assembly_final <-
    if (
      flag_broken
    ) {
      purrr::assign_in(
        data_assembly,
        where = base::list("levels", 1, "age"),
        value = c(-55, NA, 9830)
      )
    } else {
      data_assembly
    }

  name_file <-
    build_producer_file_name(
      name_template = purrr::chuck(contract, "file", "name_templates")[1],
      date = date_file,
      hash = rlang::hash(data_assembly_final)
    )

  res <-
    base::list(data_assembly_final) |>
    rlang::set_names(name_file)

  return(res)
}
