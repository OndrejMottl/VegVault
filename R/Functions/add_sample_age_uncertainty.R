add_sample_age_uncertainty <- function(data_source, dataset_id, samples_id, con, ...) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_name",
        "age",
        "iteration"
      )
    ),
    msg = "data_source must have columns 'dataset_name', 'age' and 'iteration'"
  )

  assertthat::assert_that(
    assertthat::has_name(
      dataset_id,
      c(
        "dataset_name",
        "dataset_id"
      )
    ),
    msg = "dataset_id must have columns 'dataset_name' and 'dataset_id'"
  )

  assertthat::assert_that(
    assertthat::has_name(
      samples_id,
      c(
        "sample_id",
        "sample_name"
      )
    ),
    msg = "samples_id must have columns 'sample_id' and 'sample_name'"
  )

  data_uncertainty <-
    add_dataset_sample_name(
      data_source = data_source,
      dataset_id = dataset_id,
      con = con,
      sel_name = sel_name
    ) %>%
    dplyr::select(sample_name, iteration, age) %>%
    dplyr::left_join(
      samples_id,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::select(sample_id, iteration, age)

  data_uncertainty_unique <-
    data_uncertainty %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SampleUncertainty") %>%
        dplyr::select(sample_id, iteration) %>%
        dplyr::collect(),
      by = dplyr::join_by("sample_id", "iteration")
    )

  add_to_db(
    conn = con,
    data = data_uncertainty_unique,
    table_name = "SampleUncertainty",
    overwrite_test = TRUE
  )
}
