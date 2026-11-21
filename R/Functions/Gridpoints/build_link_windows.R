#' @title Build the search windows of the gridpoint links
#' @description
#' Give every position a latitude and longitude window that contains every
#' point within the link distance, and split the positions into chunks for
#' `compute_position_links()`.
#' @param data_positions
#' A data frame with the integer column `position_id` (unique) and the
#' numeric columns `coord_long`, `coord_lat` and `age`, as returned by
#' `prepare_link_positions()`.
#' @param distance_km
#' A positive number: the link distance in km.
#' @param radius_min_km
#' A positive number: a radius, in km, no larger than the smallest radius
#' of curvature of the WGS84 ellipsoid (6335.44 km, the meridional radius
#' at the equator).
#' @param margin_deg
#' A number, at least 0: degrees added to both half-widths of every window.
#' @param n_chunk_size
#' A whole number, at least 1: the number of positions per chunk.
#' @return
#' A list of tibbles, one per chunk of `n_chunk_size` consecutive positions
#' in `position_id` order, named `chunk_1`, `chunk_2` and so on. Each tibble
#' has the columns of `data_positions` listed above and the double columns
#' `lat_lo`, `lat_hi`, `lon_lo` and `lon_hi`, the bounds of a window. A
#' position has one row, or two when its window crosses the dateline.
#' @details
#' With the angular radius `delta = distance_km / radius_min_km` (radians),
#' the latitude window is `coord_lat` plus and minus `delta` (in degrees)
#' plus `margin_deg`. The longitude half-width is
#' `asin(sin(delta) / cos(lat_edge))` plus `margin_deg`, where `lat_edge`
#' is the absolute latitude at the poleward edge of the latitude window;
#' when that edge reaches a pole or the ratio is at least 1, the window
#' spans every longitude. Along any path of length `distance_km` the
#' latitude changes by at most `delta` and the longitude by at most
#' `delta / cos(lat_edge)`, which the half-width exceeds, so every point
#' within `distance_km` lies inside the windows. The bounds are clipped to
#' -180 and 180; the part of a window beyond the dateline becomes a second
#' row, shifted by 360 degrees.
#' Ages are not used: the age test is applied by
#' `compute_position_links()`.
#' @seealso [prepare_link_positions()], [compute_position_links()]
#' @examples
#' \dontrun{
#' build_link_windows(
#'   data_positions = data_positions,
#'   distance_km = 50,
#'   radius_min_km = 6335.4,
#'   margin_deg = 0.01,
#'   n_chunk_size = 5000L
#' )
#' }
build_link_windows <- function(
  data_positions,
  distance_km,
  radius_min_km,
  margin_deg,
  n_chunk_size
) {
  vec_columns <-
    c("position_id", "coord_long", "coord_lat", "age")

  assertthat::assert_that(
    base::is.data.frame(data_positions),
    base::all(vec_columns %in% base::names(data_positions)),
    msg = stringr::str_c(
      "`data_positions` must be a data frame with the columns ",
      "`position_id`, `coord_long`, `coord_lat` and `age`."
    )
  )

  vec_position_ids <-
    dplyr::pull(data_positions, position_id)

  assertthat::assert_that(
    base::is.integer(vec_position_ids),
    !base::anyNA(vec_position_ids),
    base::anyDuplicated(vec_position_ids) == 0L,
    base::is.numeric(dplyr::pull(data_positions, coord_long)),
    base::is.numeric(dplyr::pull(data_positions, coord_lat)),
    base::is.numeric(dplyr::pull(data_positions, age)),
    !base::anyNA(dplyr::pull(data_positions, coord_long)),
    !base::anyNA(dplyr::pull(data_positions, coord_lat)),
    msg = stringr::str_c(
      "`data_positions` must have distinct integer `position_id` values ",
      "and numeric coordinates without missing values."
    )
  )

  assertthat::assert_that(
    base::is.numeric(distance_km),
    base::length(distance_km) == 1L,
    base::is.finite(distance_km),
    distance_km > 0,
    msg = "`distance_km` must be a positive number."
  )

  assertthat::assert_that(
    base::is.numeric(radius_min_km),
    base::length(radius_min_km) == 1L,
    base::is.finite(radius_min_km),
    radius_min_km > 0,
    msg = "`radius_min_km` must be a positive number."
  )

  assertthat::assert_that(
    distance_km < radius_min_km * pi / 2,
    msg = "`distance_km` must be below a quarter of the circumference."
  )

  assertthat::assert_that(
    base::is.numeric(margin_deg),
    base::length(margin_deg) == 1L,
    base::is.finite(margin_deg),
    margin_deg >= 0,
    msg = "`margin_deg` must be a number, at least 0."
  )

  assertthat::assert_that(
    base::is.numeric(n_chunk_size),
    base::length(n_chunk_size) == 1L,
    base::is.finite(n_chunk_size),
    n_chunk_size >= 1,
    n_chunk_size == base::round(n_chunk_size),
    msg = "`n_chunk_size` must be a whole number, at least 1."
  )

  n_chunk_size_integer <-
    base::as.integer(n_chunk_size)

  # Angular radius of the link distance, in radians, and the latitude
  #   half-width in degrees
  value_delta_rad <-
    distance_km / radius_min_km

  value_half_lat_deg <-
    value_delta_rad * 180 / pi + margin_deg

  data_windows_base <-
    data_positions |>
    dplyr::select(dplyr::all_of(vec_columns)) |>
    dplyr::arrange(position_id) |>
    dplyr::mutate(
      chunk_id = (dplyr::row_number() - 1L) %/% n_chunk_size_integer + 1L,
      lat_lo = coord_lat - value_half_lat_deg,
      lat_hi = coord_lat + value_half_lat_deg,
      lat_edge_deg = base::pmin(
        base::abs(coord_lat) + value_half_lat_deg,
        90
      ),
      ratio_lon = base::sin(value_delta_rad) /
        base::cos(lat_edge_deg * pi / 180),
      half_lon_deg = dplyr::if_else(
        condition = lat_edge_deg >= 90 | ratio_lon >= 1,
        true = 180,
        false = base::asin(base::pmin(ratio_lon, 1)) * 180 / pi +
          margin_deg
      ),
      flag_all_longitudes = half_lon_deg >= 180
    )

  # Main window, clipped at the dateline; a window that spans every
  #   longitude needs no second row
  data_windows_main <-
    data_windows_base |>
    dplyr::mutate(
      lon_lo = dplyr::if_else(
        condition = flag_all_longitudes,
        true = -180,
        false = base::pmax(coord_long - half_lon_deg, -180)
      ),
      lon_hi = dplyr::if_else(
        condition = flag_all_longitudes,
        true = 180,
        false = base::pmin(coord_long + half_lon_deg, 180)
      )
    )

  # The parts beyond -180 and 180, shifted to the other side
  data_windows_west <-
    data_windows_base |>
    dplyr::filter(
      !flag_all_longitudes,
      coord_long - half_lon_deg < -180
    ) |>
    dplyr::mutate(
      lon_lo = coord_long - half_lon_deg + 360,
      lon_hi = 180
    )

  data_windows_east <-
    data_windows_base |>
    dplyr::filter(
      !flag_all_longitudes,
      coord_long + half_lon_deg > 180
    ) |>
    dplyr::mutate(
      lon_lo = -180,
      lon_hi = coord_long + half_lon_deg - 360
    )

  data_windows <-
    dplyr::bind_rows(
      data_windows_main,
      data_windows_west,
      data_windows_east
    ) |>
    dplyr::arrange(position_id, lon_lo)

  list_windows <-
    base::split(
      x = dplyr::select(
        data_windows,
        dplyr::all_of(vec_columns),
        lat_lo, lat_hi, lon_lo, lon_hi
      ),
      f = dplyr::pull(data_windows, chunk_id)
    )

  res <-
    rlang::set_names(
      x = base::unname(list_windows),
      nm = stringr::str_c("chunk_", base::names(list_windows))
    )

  return(res)
}
