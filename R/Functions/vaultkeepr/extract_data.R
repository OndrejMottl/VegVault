extract_data <- function(con) {
  # test various things
  sel_data <- con$data

  sel_data %>%
    dplyr::collect() %>%
    return()
}