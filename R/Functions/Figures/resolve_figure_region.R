#' @title Resolve the region of a figure example
#' @description
#' Return the region that a figure example draws its data from: the
#' configured region, or the subset box when the `subset` profile is
#' active, so that a rehearsal database still yields data.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees), for example `figures: taxon_example: region` of
#' `config.yml`.
#' @param list_subset
#' Named list. The `subset` section of `config.yml`; when its `enabled`
#' element is `TRUE`, its box replaces `list_region`.
#' @return
#' A named list with the numeric scalars `lon_min`, `lon_max`, `lat_min`
#' and `lat_max`.
#' @details
#' `list_region` is always checked with `validate_bounding_box()`, and the
#' subset box when it is used. Other elements of the lists (such as the box
#' name or margins of the subset) are dropped.
#' @examples
#' \dontrun{
#' list_region <-
#'   resolve_figure_region(
#'     list_region = list(
#'       lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
#'     ),
#'     list_subset = load_config_value(value = "subset")
#'   )
#' }
resolve_figure_region <- function(
  list_region,
  list_subset
) {
  assertthat::assert_that(
    base::is.list(list_subset),
    msg = "`list_subset` must be the `subset` section of config.yml (a list)."
  )

  validate_bounding_box(list_bounding_box = list_region)

  flag_subset <-
    base::isTRUE(purrr::pluck(list_subset, "enabled"))

  list_box <-
    if (
      flag_subset
    ) {
      validate_bounding_box(list_bounding_box = list_subset)
    } else {
      list_region
    }

  res <-
    list_box[c("lon_min", "lon_max", "lat_min", "lat_max")]

  return(res)
}
