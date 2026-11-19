#' @title Test whether a value has a producer-contract class
#' @description
#' Test whether a vector or column has one of the classes that producer
#' contracts use in their `class` fields.
#' @param x
#' The value to test, usually a data-frame column.
#' @param class_name
#' Character scalar. One of `"character"`, `"numeric"`, `"double"`,
#' `"integer"`, `"logical"`, `"Date"`, `"factor"`, `"list"`,
#' `"data.frame"` or `"matrix"`.
#' @return
#' Logical scalar. `TRUE` when `x` has the class `class_name`.
#' @details
#' `"numeric"` accepts double and integer vectors but not factors or
#' dates. `"double"` accepts double vectors that are not dates.
#' `"list"` accepts lists that are not data frames, which is how
#' list-columns are stored. Aborts when `class_name` is not one of the
#' classes above.
is_producer_class <- function(
  x,
  class_name
) {
  vec_classes <-
    c(
      "character", "numeric", "double", "integer", "logical", "Date",
      "factor", "list", "data.frame", "matrix"
    )

  assertthat::assert_that(
    base::is.character(class_name),
    base::length(class_name) == 1L,
    msg = "'class_name' must be a single character value."
  )

  assertthat::assert_that(
    class_name %in% vec_classes,
    msg = stringr::str_glue(
      "'class_name' must be a producer-contract class, not '{class_name}'."
    )
  )

  # base::is.numeric() is FALSE for factors and dates, which keeps
  #   identifiers stored as factors or dates out of "numeric" and "double"
  res <-
    base::switch(
      class_name,
      "character" = base::is.character(x),
      "numeric" = base::is.numeric(x),
      "double" = base::is.numeric(x) && base::is.double(x),
      "integer" = base::is.integer(x),
      "logical" = base::is.logical(x),
      "Date" = base::inherits(x, "Date"),
      "factor" = base::is.factor(x),
      "list" = base::is.list(x) && !base::is.data.frame(x),
      "data.frame" = base::is.data.frame(x),
      "matrix" = base::is.matrix(x)
    )

  return(res)
}
