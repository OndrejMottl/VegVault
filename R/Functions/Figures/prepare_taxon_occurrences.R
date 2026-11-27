#' @title Prepare the occurrences of one genus for mapping
#' @description
#' Reduce the extraction of `load_taxon_occurrences()` to the distinct
#' places and ages where the genus is present, and put the fossil records
#' into age bins.
#' @param data_taxon_occurrences_raw
#' A data frame as returned by `load_taxon_occurrences()`, with at least
#' `dataset_id`, `dataset_type`, `coord_long`, `coord_lat`, `age`,
#' `taxon_name` and `value`.
#' @param taxon_name
#' Character scalar. The genus to keep.
#' @param age_bin_width
#' Positive numeric scalar. Width of the age bins, in years.
#' @param age_min,age_max
#' Numeric scalars. The age range of the extraction, in years; they set the
#' bins listed as factor levels.
#' @return
#' A tibble with the distinct `dataset_id`, `dataset_type` (with spaces
#' instead of underscores), `coord_long`, `coord_lat` and `age` of the
#' records of `taxon_name` with a value above zero, and `age_bin_class`: a
#' factor that is `contemporary` for vegetation plots and
#' `paleo: <bin start> ka cal yr BP` for fossil records, with the levels
#' `contemporary` and every bin from `age_min` to `age_max`.
#' @details
#' Rows of other dataset types than vegetation plots and fossil pollen
#' records are dropped. Aborts when a required column is missing.
#' @examples
#' \dontrun{
#' data_taxon_occurrences <-
#'   prepare_taxon_occurrences(
#'     data_taxon_occurrences_raw = data_taxon_occurrences_raw,
#'     taxon_name = "Picea",
#'     age_bin_width = 2500,
#'     age_min = 0,
#'     age_max = 12000
#'   )
#' }
prepare_taxon_occurrences <- function(
  data_taxon_occurrences_raw,
  taxon_name,
  age_bin_width,
  age_min,
  age_max
) {
  validate_data_columns(
    data_source = data_taxon_occurrences_raw,
    vec_columns_required = c(
      "dataset_id", "dataset_type", "coord_long", "coord_lat", "age",
      "taxon_name", "value"
    ),
    name_argument = "data_taxon_occurrences_raw"
  )

  assertthat::assert_that(
    base::is.character(taxon_name),
    base::length(taxon_name) == 1L,
    !base::is.na(taxon_name),
    msg = "`taxon_name` must be a character scalar."
  )

  assertthat::assert_that(
    is_positive_number(age_bin_width),
    msg = "`age_bin_width` must be a positive number."
  )

  assertthat::assert_that(
    base::is.numeric(age_min),
    base::is.numeric(age_max),
    base::length(age_min) == 1L,
    base::length(age_max) == 1L,
    base::is.finite(age_min),
    base::is.finite(age_max),
    age_min <= age_max,
    msg = "`age_min` and `age_max` must be numbers with `age_min` <= `age_max`."
  )

  sel_taxon_name <- taxon_name

  # Bin starts in thousands of years, from the bin of `age_min` to the bin
  #   of `age_max`
  vec_bin_starts <-
    base::seq(
      from = base::floor(age_min / age_bin_width) * age_bin_width,
      to = base::floor(age_max / age_bin_width) * age_bin_width,
      by = age_bin_width
    ) / 1e3

  vec_levels <-
    c(
      "contemporary",
      stringr::str_c("paleo: ", vec_bin_starts, " ka cal yr BP")
    )

  res <-
    data_taxon_occurrences_raw |>
    dplyr::filter(
      dataset_type %in% c("vegetation_plot", "fossil_pollen_archive"),
      taxon_name == sel_taxon_name,
      value > 0
    ) |>
    dplyr::distinct(dataset_id, dataset_type, coord_long, coord_lat, age) |>
    dplyr::mutate(
      age_bin_class = base::factor(
        dplyr::if_else(
          dataset_type == "vegetation_plot",
          "contemporary",
          stringr::str_c(
            "paleo: ",
            base::floor(age / age_bin_width) * age_bin_width / 1e3,
            " ka cal yr BP"
          )
        ),
        levels = vec_levels
      ),
      dataset_type = stringr::str_replace_all(dataset_type, "_", " ")
    ) |>
    dplyr::arrange(dataset_id, age)

  return(res)
}
