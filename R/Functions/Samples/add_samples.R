add_samples <- function(data_source, con) {
  data_sample_size_id_db <-
    add_sample_size_id(
      data_source = data_source,
      con = con
    )

  data_sample_reference_id_db <-
    add_sample_reference_id(
      data_source = data_source,
      con = con
    )

  data_samples_id_db <-
    add_samples_id(
      data_source = data_source,
      samples_size_id = data_sample_size_id_db,
      con = con
    )

  add_samples_reference(
    data_source = data_source,
    samples_reference_id = data_sample_reference_id_db,
    con = con
  )

  return(data_samples_id_db)
}
