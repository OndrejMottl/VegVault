# Read the valid contract fixture of one producer artefact as one table:
#   every file of Data/Contracts/fixtures/valid/<artefact id>/, in file
#   order, bound by rows (the form the assembly stage gets from stage 01).
load_valid_fixture <- function(id_artefact) {
  vec_files <-
    base::list.files(
      path = here::here("Data", "Contracts", "fixtures", "valid", id_artefact),
      full.names = TRUE
    )

  res <-
    vec_files |>
    purrr::map(.f = qs2::qs_read) |>
    dplyr::bind_rows()

  return(res)
}
