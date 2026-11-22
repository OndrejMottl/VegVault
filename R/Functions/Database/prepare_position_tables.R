#' @title Prepare the positions, links and gridpoints that samples use
#' @description
#' Match every sample with coordinates to its position from the gridpoint
#' stage, and keep only the positions that samples use, their links and
#' the gridpoints those links reach.
#' @param list_source_tables
#' Named list of the source tables of the sample sources (see
#' `build_source_table_template()`); gridpoints are not among them.
#' @param data_positions
#' A data frame of the gridpoint stage: `position_id`, `coord_long`,
#' `coord_lat` and `age`, one row per position.
#' @param data_position_links
#' A data frame of the gridpoint stage: `position_id`, `gridpoint_id`,
#' `distance_in_km` and `distance_in_years`.
#' @param data_gridpoints
#' A data frame of the gridpoint stage: `gridpoint_id`, `coord_long`,
#' `coord_lat`, `age`, `dataset_name` and `sample_name`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of four tibbles:
#' \itemize{
#'   \item `sample_positions`: `sample_name` and `position_id`, one row per
#'     sample with coordinates;
#'   \item `positions`: the rows of `data_positions` that a sample uses;
#'   \item `position_links`: the rows of `data_position_links` of those
#'     positions;
#'   \item `gridpoints`: the rows of `data_gridpoints` those links reach.
#' }
#' @details
#' A sample's coordinates are those of its dataset and its age is its own.
#' They are matched exactly to a position, because the gridpoint stage
#' read them from the same producer columns. A sample without a
#' longitude or a latitude has no position and is counted when `verbose`.
#' A sample with coordinates but no position aborts, with the first names
#' (the positions and the samples would otherwise disagree). Positions that
#' no sample uses, such as fossil-pollen levels without counts, are left
#' out with their links; a gridpoint that only they reach is left out too,
#' so no gridpoint is stored without a link. Position ids stay those of the
#' gridpoint stage; `build_position_tables()` numbers them again.
#' @seealso [build_position_tables()], [prepare_gridpoint_tables()]
#' @examples
#' \dontrun{
#' list_positions <-
#'   prepare_position_tables(
#'     list_source_tables = list_source_tables,
#'     data_positions = data_positions,
#'     data_position_links = data_position_links,
#'     data_gridpoints = data_gridpoints
#'   )
#' }
prepare_position_tables <- function(
  list_source_tables,
  data_positions,
  data_position_links,
  data_gridpoints,
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.list(list_source_tables),
    base::all(
      purrr::map_lgl(
        .x = list_source_tables,
        .f = ~ base::is.list(.x) &&
          base::all(
            c("datasets", "dataset_samples", "samples") %in% base::names(.x)
          )
      )
    ),
    msg = stringr::str_c(
      "`list_source_tables` must be a list of source tables with ",
      "`datasets`, `dataset_samples` and `samples`."
    )
  )

  list_required <-
    base::list(
      data_positions = c("position_id", "coord_long", "coord_lat", "age"),
      data_position_links = c(
        "position_id", "gridpoint_id", "distance_in_km", "distance_in_years"
      ),
      data_gridpoints = c(
        "gridpoint_id", "coord_long", "coord_lat", "age", "dataset_name",
        "sample_name"
      )
    )

  list_inputs <-
    base::list(
      data_positions = data_positions,
      data_position_links = data_position_links,
      data_gridpoints = data_gridpoints
    )

  purrr::iwalk(
    .x = list_required,
    .f = ~ assertthat::assert_that(
      base::is.data.frame(purrr::chuck(list_inputs, .y)),
      base::all(.x %in% base::names(purrr::chuck(list_inputs, .y))),
      msg = stringr::str_c(
        "`", .y, "` must be a data frame with the columns ",
        stringr::str_c(.x, collapse = ", "), "."
      )
    )
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # The place of a sample: the coordinates of its dataset, its own age
  data_sample_places <-
    list_source_tables |>
    purrr::map(
      .f = ~ purrr::chuck(.x, "datasets") |>
        dplyr::select(dataset_name, coord_long, coord_lat) |>
        dplyr::inner_join(
          purrr::chuck(.x, "dataset_samples"),
          by = dplyr::join_by(dataset_name),
          relationship = "one-to-many"
        ) |>
        dplyr::inner_join(
          dplyr::select(purrr::chuck(.x, "samples"), sample_name, age),
          by = dplyr::join_by(sample_name),
          relationship = "one-to-one"
        )
    ) |>
    purrr::list_rbind(
      ptype = tibble::tibble(
        dataset_name = base::character(0),
        coord_long = base::double(0),
        coord_lat = base::double(0),
        sample_name = base::character(0),
        age = base::double(0)
      )
    )

  vec_placed <-
    !base::is.na(dplyr::pull(data_sample_places, coord_long)) &
    !base::is.na(dplyr::pull(data_sample_places, coord_lat))

  if (
    base::isTRUE(verbose) &&
      !base::all(vec_placed)
  ) {
    cli::cli_inform(
      "{base::sum(!vec_placed)} sample{?s} without coordinates {?has/have}
      no position."
    )
  }

  data_sample_positions_all <-
    data_sample_places |>
    dplyr::filter(vec_placed) |>
    dplyr::left_join(
      dplyr::select(data_positions, position_id, coord_long, coord_lat, age),
      by = dplyr::join_by(coord_long, coord_lat, age),
      relationship = "many-to-one"
    )

  vec_unmatched <-
    base::is.na(dplyr::pull(data_sample_positions_all, position_id))

  if (
    base::any(vec_unmatched)
  ) {
    vec_examples <-
      data_sample_positions_all |>
      dplyr::filter(vec_unmatched) |>
      dplyr::pull(sample_name) |>
      utils::head(5L)

    cli::cli_abort(
      c(
        "{base::sum(vec_unmatched)} sample{?s} with coordinates {?has/have}
        no position in the gridpoint stage.",
        "x" = "First: {.val {vec_examples}}.",
        "i" = "The positions and the samples must come from the same
        producer artefacts."
      )
    )
  }

  data_sample_positions <-
    dplyr::select(data_sample_positions_all, sample_name, position_id)

  vec_used_positions <-
    base::unique(dplyr::pull(data_sample_positions, position_id))

  data_positions_used <-
    data_positions |>
    dplyr::filter(position_id %in% vec_used_positions) |>
    dplyr::select(position_id, coord_long, coord_lat, age)

  data_links_used <-
    data_position_links |>
    dplyr::filter(position_id %in% vec_used_positions) |>
    dplyr::select(
      position_id, gridpoint_id, distance_in_km, distance_in_years
    )

  data_gridpoints_used <-
    data_gridpoints |>
    dplyr::filter(
      gridpoint_id %in% base::unique(dplyr::pull(data_links_used, gridpoint_id))
    ) |>
    dplyr::select(
      gridpoint_id, coord_long, coord_lat, age, dataset_name, sample_name
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      "Positions: {base::nrow(data_positions_used)} of
      {base::nrow(data_positions)} used by samples, with
      {base::nrow(data_links_used)} link{?s} to
      {base::nrow(data_gridpoints_used)} gridpoint{?s}."
    )
  }

  res <-
    base::list(
      sample_positions = data_sample_positions,
      positions = data_positions_used,
      position_links = data_links_used,
      gridpoints = data_gridpoints_used
    )

  return(res)
}
