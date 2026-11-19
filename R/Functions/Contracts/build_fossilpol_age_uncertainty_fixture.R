#' @title Build the FOSSILPOL age-uncertainty fixture
#' @description
#' Build a small synthetic artefact for the `fossilpol_age_uncertainty`
#' contract, for tests and for producers checking their export. All values
#' are invented; none comes from a real dataset.
#' @param contract
#' The `fossilpol_age_uncertainty` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file names.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' the second part is lettered C instead of B (`partition_gap`).
#' @return
#' A named list with one tibble per part, named by the file name it is
#' saved under: the contract's file-name template filled with the part
#' letter, `date_file` and `rlang::hash()` of the tibble.
#' @details
#' Parts A and B with one dataset each, matching the datasets and levels of
#' `build_fossilpol_assembly_fixture()`. Each matrix has five iterations of
#' whole-number ages around the level ages of the assembly. The result is
#' identical on every call. Aborts when `contract` is not the
#' `fossilpol_age_uncertainty` contract.
build_fossilpol_age_uncertainty_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "fossilpol_age_uncertainty.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "fossilpol_age_uncertainty"
    ),
    msg = "'contract' must be the fossilpol_age_uncertainty contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  # Iterations in rows, levels in columns, as the producer's age models
  mat_first <-
    base::matrix(
      data = c(
        -60L, -55L, -50L, -57L, -52L,
        1150L, 1210L, 1260L, 1190L, 1230L,
        9700L, 9830L, 9950L, 9800L, 9870L
      ),
      nrow = 5,
      dimnames = base::list(NULL, c("90001_1", "90001_2", "90001_3"))
    )

  mat_second <-
    base::matrix(
      data = c(
        120L, 150L, 175L, 140L, 160L,
        3900L, 4020L, 4110L, 3980L, 4060L,
        17700L, 17950L, 18200L, 17850L, 18050L
      ),
      nrow = 5,
      dimnames = base::list(NULL, c("90002_1", "90002_2", "90002_3"))
    )

  list_parts <-
    base::list(
      tibble::tibble(
        dataset_id = "90001",
        age_uncertainty = base::list(mat_first)
      ),
      tibble::tibble(
        dataset_id = "90002",
        age_uncertainty = base::list(mat_second)
      )
    )

  # The one defect, when asked for: a letter is skipped
  vec_letters <-
    if (
      flag_broken
    ) {
      c("A", "C")
    } else {
      c("A", "B")
    }

  name_template <-
    purrr::chuck(contract, "file", "name_templates")[1]

  vec_names <-
    purrr::map2_chr(
      .x = list_parts,
      .y = vec_letters,
      .f = ~ build_producer_file_name(
        name_template = name_template,
        date = date_file,
        hash = rlang::hash(.x),
        partition = .y
      )
    )

  res <-
    list_parts |>
    rlang::set_names(vec_names)

  return(res)
}
