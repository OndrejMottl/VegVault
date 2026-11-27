#' @title Build the position tables with their ids
#' @description
#' Turn the positions, sample positions and links of
#' `prepare_position_tables()` into the rows of `Positions`,
#' `SamplePosition` and `PositionLink`, with the sample ids of the built
#' tables.
#' @param list_tables
#' Named list of tables as returned by `build_database_tables()`, with at
#' least `Samples` (`sample_id` and `sample_name`) for every sample and
#' gridpoint sample.
#' @param list_positions
#' Named list as returned by `prepare_position_tables()`:
#' `sample_positions`, `positions`, `position_links` and `gridpoints`.
#' @return
#' A named list of three tibbles with the columns of the schema:
#' \itemize{
#'   \item `Positions`: `position_id`, `coord_long`, `coord_lat`, `age`;
#'   \item `SamplePosition`: `sample_id`, `position_id`;
#'   \item `PositionLink`: `position_id`, `sample_ref_id` (the gridpoint
#'     sample), `distance_in_km`, `distance_in_years`.
#' }
#' @details
#' Positions are numbered again from 1 by sorting their longitude,
#' latitude and age, because the positions without samples are gone. Each
#' link's gridpoint becomes the id of its gridpoint sample. Every name is
#' resolved with `prepare_table_foreign_key()`, so a sample or gridpoint
#' sample missing from `Samples` aborts and names the table.
#' @seealso [prepare_position_tables()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_position_tables <-
#'   build_position_tables(
#'     list_tables = list_tables,
#'     list_positions = list_positions
#'   )
#' }
build_position_tables <- function(
  list_tables,
  list_positions
) {
  assertthat::assert_that(
    base::is.list(list_tables),
    "Samples" %in% base::names(list_tables),
    base::all(
      c("sample_id", "sample_name") %in%
        base::names(purrr::pluck(list_tables, "Samples"))
    ),
    msg = stringr::str_c(
      "`list_tables` must hold `Samples` with `sample_id` and ",
      "`sample_name`."
    )
  )

  assertthat::assert_that(
    base::is.list(list_positions),
    base::all(
      c("sample_positions", "positions", "position_links", "gridpoints") %in%
        base::names(list_positions)
    ),
    msg = stringr::str_c(
      "`list_positions` must hold `sample_positions`, `positions`, ",
      "`position_links` and `gridpoints` (see prepare_position_tables())."
    )
  )

  data_sample_ids <-
    purrr::chuck(list_tables, "Samples") |>
    dplyr::select(sample_id, sample_name)

  # Positions are numbered again, because unused positions are gone
  data_positions <-
    purrr::chuck(list_positions, "positions") |>
    dplyr::rename(position_id_stage = position_id) |>
    prepare_table_ids(
      vec_sort_columns = c("coord_long", "coord_lat", "age"),
      name_id = "position_id",
      name_table = "Positions"
    )

  data_position_map <-
    dplyr::select(data_positions, position_id, position_id_stage)

  data_sample_position <-
    purrr::chuck(list_positions, "sample_positions") |>
    dplyr::rename(position_id_stage = position_id) |>
    prepare_table_foreign_key(
      data_parent = data_sample_ids,
      vec_key_columns = "sample_name",
      name_id = "sample_id",
      name_table = "SamplePosition"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_position_map,
      vec_key_columns = "position_id_stage",
      name_id = "position_id",
      name_table = "SamplePosition"
    ) |>
    dplyr::select(sample_id, position_id) |>
    dplyr::arrange(sample_id)

  data_links_named <-
    purrr::chuck(list_positions, "position_links") |>
    dplyr::rename(position_id_stage = position_id) |>
    dplyr::left_join(
      purrr::chuck(list_positions, "gridpoints") |>
        dplyr::select(gridpoint_id, sample_ref_name = sample_name),
      by = dplyr::join_by(gridpoint_id),
      relationship = "many-to-one"
    )

  n_links_without_gridpoint <-
    base::sum(base::is.na(dplyr::pull(data_links_named, sample_ref_name)))

  if (
    n_links_without_gridpoint > 0L
  ) {
    cli::cli_abort(
      "PositionLink: {n_links_without_gridpoint} link{?s} to a gridpoint
      that {.arg list_positions} does not list."
    )
  }

  data_position_link <-
    data_links_named |>
    prepare_table_foreign_key(
      data_parent = data_position_map,
      vec_key_columns = "position_id_stage",
      name_id = "position_id",
      name_table = "PositionLink"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_sample_ids,
        sample_ref_id = sample_id,
        sample_ref_name = sample_name
      ),
      vec_key_columns = "sample_ref_name",
      name_id = "sample_ref_id",
      name_table = "PositionLink"
    ) |>
    dplyr::select(
      position_id, sample_ref_id, distance_in_km, distance_in_years
    ) |>
    dplyr::arrange(position_id, sample_ref_id)

  res <-
    base::list(
      Positions = dplyr::select(
        data_positions,
        position_id, coord_long, coord_lat, age
      ),
      SamplePosition = data_sample_position,
      PositionLink = data_position_link
    )

  return(res)
}
