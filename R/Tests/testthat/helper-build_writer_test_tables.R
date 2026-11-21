# Rows for the tables of build_writer_test_schema(), with ids assigned and
#   in no particular order: 3 references, 4 usages and 3 loose rows.
#   Returns a named list of tibbles named by table.
build_writer_test_tables <- function() {
  data_references <-
    tibble::tibble(
      reference_id = c(3L, 1L, 2L),
      reference_detail = c("ref_c", "ref_a", "ref_b"),
      mandatory = c(0L, 1L, 0L)
    )

  data_usage <-
    tibble::tibble(
      reference_id = c(2L, 1L, 1L, 3L),
      user_name = c("user_b", "user_b", "user_a", "user_a"),
      value = c(20, 10, 15, 30)
    )

  data_loose <-
    tibble::tibble(
      x = c(2L, 1L, 3L),
      y = c("two", "one", "three")
    )

  res <-
    base::list(
      References = data_references,
      Usage = data_usage,
      Loose = data_loose
    )

  return(res)
}
