add_sampling_method <- function(data_source, con) {
  data_sampling_method_db <-
    add_sampling_method_id(
      data_source = data_source,
      con = con
    )

  add_sampling_method_reference(
    data_source = data_source,
    sampling_method_id = data_sampling_method_db,
    con = con
  )

  return(data_sampling_method_db)
}
