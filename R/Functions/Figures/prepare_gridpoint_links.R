#' @title Prepare the links between vegetation plots and gridpoints
#' @description
#' Turn the extraction of `load_gridpoint_links()` into one row per
#' vegetation plot sample with the location of its linked gridpoint.
#' @param data_gridpoint_links_raw
#' A data frame as returned by `load_gridpoint_links()`, with at least
#' `dataset_type`, `sample_id`, `sample_id_link`, `coord_long` and
#' `coord_lat`.
#' @return
#' A tibble with one row per vegetation plot sample: `sample_id`,
#' `coord_long_plot`, `coord_lat_plot`, and `coord_long_gridpoint` and
#' `coord_lat_gridpoint` of its linked gridpoint (`NA` when the plot has no
#' link), sorted by `sample_id`.
#' @details
#' Gridpoint rows are those of type `gridpoints`; all other rows are plots.
#' Aborts when a required column is missing.
#' @examples
#' \dontrun{
#' data_gridpoint_links <-
#'   prepare_gridpoint_links(
#'     data_gridpoint_links_raw = data_gridpoint_links_raw
#'   )
#' }
prepare_gridpoint_links <- function(data_gridpoint_links_raw) {
  validate_data_columns(
    data_source = data_gridpoint_links_raw,
    vec_columns_required = c(
      "dataset_type", "sample_id", "sample_id_link", "coord_long",
      "coord_lat"
    ),
    name_argument = "data_gridpoint_links_raw"
  )

  data_plots <-
    data_gridpoint_links_raw |>
    dplyr::filter(dataset_type != "gridpoints") |>
    dplyr::distinct(
      sample_id,
      coord_long_plot = coord_long,
      coord_lat_plot = coord_lat
    )

  data_gridpoints <-
    data_gridpoint_links_raw |>
    dplyr::filter(dataset_type == "gridpoints") |>
    dplyr::distinct(
      sample_id_link,
      coord_long_gridpoint = coord_long,
      coord_lat_gridpoint = coord_lat
    )

  # vaultkeepr links each plot to one gridpoint at most
  res <-
    data_plots |>
    dplyr::left_join(
      data_gridpoints,
      by = dplyr::join_by(sample_id == sample_id_link),
      relationship = "many-to-one"
    ) |>
    dplyr::arrange(sample_id)

  return(res)
}
