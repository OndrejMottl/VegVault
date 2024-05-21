open_vault <- function(path) {
  # test various things

  db_con <-
    DBI::dbConnect(
      RSQLite::SQLite(),
      path
    )

  dummy <-
    structure(
      list(
        data = tibble::tibble(),
        db_con = db_con
      ),
      class = c("list", "vault_pipe")
    )

  return(dummy)
}