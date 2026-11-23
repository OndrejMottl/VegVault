#' @title Prepare the classification batches of the taxon names
#' @description
#' Give every taxon name the number of the classification batch it belongs
#' to, from a hash of the name, so that a name stays in its batch whatever
#' other names are added or removed.
#' @param vec_taxon_names
#' Character vector of taxon names, without missing or empty values.
#' Repeated names are one row.
#' @param n_batches
#' Integer scalar of at least 1. The number of batches
#' (`build: classification: n_batches` of `config.yml`).
#' @return
#' A tibble with `taxon_name` and the integer `batch_id` (1 to
#' `n_batches`), one row per name, sorted by `batch_id` and then by name
#' (C locale).
#' @details
#' The batch of a name is the number in the first seven hexadecimal digits
#' of `rlang::hash()` of the name (in UTF-8), modulo `n_batches`, plus 1.
#' It depends only on the name and on `n_batches`, so a later build that
#' adds names changes only the batches that receive them, and `{targets}`
#' classifies only those batches again. A new `n_batches` moves every name.
#' Aborts when a name is missing or empty.
#' @seealso [classify_taxa()], [prepare_classification_tables()]
#' @examples
#' \dontrun{
#' data_taxon_batches <-
#'   prepare_taxon_batches(
#'     vec_taxon_names = c("Quercus robur", "Fagus sylvatica"),
#'     n_batches = 1024L
#'   )
#' }
prepare_taxon_batches <- function(
  vec_taxon_names,
  n_batches
) {
  assertthat::assert_that(
    base::is.character(vec_taxon_names),
    !base::anyNA(vec_taxon_names),
    base::all(base::nzchar(vec_taxon_names)),
    msg = stringr::str_c(
      "`vec_taxon_names` must be a character vector without missing or ",
      "empty names."
    )
  )

  assertthat::assert_that(
    base::is.numeric(n_batches),
    base::length(n_batches) == 1L,
    !base::is.na(n_batches),
    n_batches >= 1,
    n_batches == base::round(n_batches),
    msg = "`n_batches` must be one whole number of at least 1."
  )

  vec_names <-
    base::unique(vec_taxon_names)

  # The hash of the name in UTF-8, so the encoding of the text does not
  #   change the batch
  vec_hashes <-
    purrr::map_chr(
      .x = base::enc2utf8(vec_names),
      .f = ~ rlang::hash(.x)
    )

  vec_numbers <-
    base::strtoi(
      stringr::str_sub(
        string = vec_hashes,
        start = 1L,
        end = 7L
      ),
      base = 16L
    )

  res <-
    tibble::tibble(
      taxon_name = vec_names,
      batch_id = base::as.integer(vec_numbers %% n_batches + 1L)
    ) |>
    dplyr::arrange(batch_id, taxon_name, .locale = "C")

  return(res)
}
