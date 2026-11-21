#' @title Prepare the positions to link to gridpoints
#' @description
#' Combine the positions of all sample sources into one table of distinct
#' positions (longitude, latitude and age) with deterministic ids.
#' @param list_positions
#' A non-empty, named list of data frames with the numeric columns
#' `coord_long`, `coord_lat` and `age`, such as the results of
#' `prepare_modern_positions()` and `prepare_fossilpol_positions()`. The
#' names identify the sources in messages and errors.
#' @param verbose
#' Logical. If `TRUE` (default), the number of rows dropped for a missing
#' value is reported per source via `cli`.
#' @return
#' A tibble with one row per distinct position, sorted by `coord_long`,
#' `coord_lat` and `age`:
#' \itemize{
#'   \item `position_id`: integer, the row number;
#'   \item `coord_long`, `coord_lat`: double, decimal degrees (WGS84);
#'   \item `age`: double, calibrated years before 1950.
#' }
#' @details
#' Rows with a missing value in any of the three columns get no position,
#' as samples without coordinates or age get no link in v1.0.0. The
#' function aborts, naming the source and up to five rows, when a
#' coordinate is not finite or lies outside -180 to 180 (longitude) or -90
#' to 90 (latitude), or when an age is not finite, and when no position
#' remains.
#' The ids depend only on the set of positions, not on the order of the
#' sources or rows, so the database assembly can join its samples to the
#' positions by (`coord_long`, `coord_lat`, `age`).
#' @seealso [prepare_modern_positions()], [prepare_fossilpol_positions()],
#' [build_link_windows()]
#' @examples
#' \dontrun{
#' prepare_link_positions(
#'   list_positions = list(
#'     splot_plots = prepare_modern_positions(list_data = data_splot_plots),
#'     fossilpol_assembly = prepare_fossilpol_positions(
#'       list_data = data_fossilpol_assembly
#'     )
#'   )
#' )
#' }
prepare_link_positions <- function(
  list_positions,
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.list(list_positions),
    !base::is.data.frame(list_positions),
    base::length(list_positions) > 0L,
    base::all(
      purrr::map_lgl(.x = list_positions, .f = base::is.data.frame)
    ),
    msg = "`list_positions` must be a non-empty list of data frames."
  )

  vec_sources <-
    base::names(list_positions)

  assertthat::assert_that(
    !base::is.null(vec_sources),
    !base::anyNA(vec_sources),
    base::all(vec_sources != ""),
    base::anyDuplicated(vec_sources) == 0L,
    msg = "`list_positions` must be named, with distinct, non-empty names."
  )

  assertthat::assert_that(
    base::all(
      purrr::map_lgl(
        .x = list_positions,
        .f = ~ base::all(
          c("coord_long", "coord_lat", "age") %in% base::names(.x)
        ) &&
          base::is.numeric(dplyr::pull(.x, coord_long)) &&
          base::is.numeric(dplyr::pull(.x, coord_lat)) &&
          base::is.numeric(dplyr::pull(.x, age))
      )
    ),
    msg = stringr::str_c(
      "Every table of `list_positions` must have the numeric columns ",
      "`coord_long`, `coord_lat` and `age`."
    )
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # Rows are numbered within their source, so errors can name them
  data_positions_flagged <-
    purrr::imap(
      .x = list_positions,
      .f = ~ tibble::tibble(
        source = .y,
        row_id = base::seq_len(base::nrow(.x)),
        coord_long = base::as.double(dplyr::pull(.x, coord_long)),
        coord_lat = base::as.double(dplyr::pull(.x, coord_lat)),
        age = base::as.double(dplyr::pull(.x, age))
      )
    ) |>
    purrr::list_rbind() |>
    dplyr::mutate(
      flag_missing = base::is.na(coord_long) |
        base::is.na(coord_lat) |
        base::is.na(age),
      flag_impossible = !flag_missing &
        !(base::is.finite(age) &
          coord_long >= -180 & coord_long <= 180 &
          coord_lat >= -90 & coord_lat <= 90)
    )

  data_impossible <-
    data_positions_flagged |>
    dplyr::filter(flag_impossible) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      vec_rows = stringr::str_c(
        utils::head(row_id, n = 5L),
        collapse = ", "
      ),
      .by = source
    )

  if (
    base::nrow(data_impossible) > 0L
  ) {
    vec_impossible <-
      data_impossible |>
      dplyr::mutate(
        line = stringr::str_glue(
          "{source}: {n_rows} row(s), for example row(s) {vec_rows}"
        )
      ) |>
      dplyr::pull(line) |>
      rlang::set_names("x")

    cli::cli_abort(
      c(
        "Positions with a coordinate outside -180 to 180 (longitude) or \\
        -90 to 90 (latitude), or a coordinate or age that is not finite.",
        vec_impossible
      )
    )
  }

  data_dropped <-
    data_positions_flagged |>
    dplyr::summarise(
      n_dropped = base::sum(flag_missing),
      n_rows = dplyr::n(),
      .by = source
    ) |>
    dplyr::filter(n_dropped > 0L)

  if (
    base::isTRUE(verbose) &&
      base::nrow(data_dropped) > 0L
  ) {
    vec_dropped <-
      data_dropped |>
      dplyr::mutate(
        line = stringr::str_glue("{source}: {n_dropped} of {n_rows} rows")
      ) |>
      dplyr::pull(line) |>
      rlang::set_names("*")

    cli::cli_inform(
      c(
        "i" = "Rows without coordinates or age get no position:",
        vec_dropped
      )
    )
  }

  res <-
    data_positions_flagged |>
    dplyr::filter(!flag_missing) |>
    dplyr::distinct(coord_long, coord_lat, age) |>
    dplyr::arrange(coord_long, coord_lat, age) |>
    dplyr::mutate(
      position_id = dplyr::row_number(),
      .before = 1L
    )

  if (
    base::nrow(res) == 0L
  ) {
    cli::cli_abort("No position remains after dropping missing values.")
  }

  return(res)
}
