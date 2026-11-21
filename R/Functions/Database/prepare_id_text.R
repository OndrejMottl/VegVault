#' @title Prepare producer ids as text for dataset and sample names
#' @description
#' Turn the ids of a producer column into the text used in dataset and
#' sample names: text stays as it is, and whole numbers are written in
#' full, never in scientific notation.
#' @param vec_ids
#' A character or numeric vector of ids.
#' @param name_column
#' Character scalar. Name of the producer column, used in error messages.
#' @return
#' A character vector of the same length as `vec_ids`.
#' @details
#' v1.0.0 pasted numbers with `as.character()`, which writes 300000 as
#' `"3e+05"` (one sPlotOpen dataset and 12 BIEN trait samples have such
#' names in v1.0.0). Here every number is written with all its digits.
#' Aborts when an id is missing or empty, when a number is not a finite
#' whole number, or when `vec_ids` is neither text nor numbers.
#' @seealso [prepare_splot_tables()], [prepare_trait_tables()]
#' @examples
#' \dontrun{
#' prepare_id_text(vec_ids = c(300000, 18000000), name_column = "id")
#' }
prepare_id_text <- function(
  vec_ids,
  name_column
) {
  assertthat::assert_that(
    base::is.character(vec_ids) || base::is.numeric(vec_ids),
    msg = "`vec_ids` must be a character or numeric vector."
  )

  assertthat::assert_that(
    base::is.character(name_column),
    base::length(name_column) == 1L,
    !base::is.na(name_column),
    base::nzchar(name_column),
    msg = "`name_column` must be a non-empty character scalar."
  )

  vec_missing <-
    base::is.na(vec_ids) |
    (base::is.character(vec_ids) & !base::nzchar(vec_ids))

  if (
    base::any(vec_missing)
  ) {
    cli::cli_abort(
      "Column {.field {name_column}} has {base::sum(vec_missing)} missing or
      empty id{?s}."
    )
  }

  vec_whole <-
    if (
      base::is.character(vec_ids)
    ) {
      base::rep(TRUE, base::length(vec_ids))
    } else {
      base::is.finite(vec_ids) & vec_ids == base::round(vec_ids)
    }

  if (
    !base::all(vec_whole)
  ) {
    cli::cli_abort(
      "Column {.field {name_column}} has {base::sum(!vec_whole)} id{?s} that
      {?is/are} not a finite whole number."
    )
  }

  # formatC() never switches to scientific notation with format "f"
  res <-
    if (
      base::is.character(vec_ids)
    ) {
      vec_ids
    } else {
      base::formatC(
        base::as.double(vec_ids),
        format = "f",
        digits = 0L
      )
    }

  return(res)
}
