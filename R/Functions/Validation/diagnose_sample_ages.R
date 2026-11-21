#' @title Diagnose implausible sample ages
#' @description
#' Count, in a built VegVault database and read-only, the sample ages that
#' cannot be right, per dataset type and source type: missing ages, ages
#' in the future of the build, and gridpoint ages that are not a time step
#' of the climate data.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`); `build_time_utc` gives the build year.
#' @param vec_gridpoint_ages
#' Numeric vector. The ages at which gridpoints exist, as returned by
#' `build_gridpoint_ages()`.
#' @return
#' A tibble in the format of `build_check_result()`, check `sample_ages`,
#' with one row per dataset type and source type, scope
#' `<dataset type> / <source type>`, sorted by scope. A row passes when no
#' age is missing, in the future or, for gridpoints, off the time steps;
#' otherwise it is a `flag` with the number of such samples as the
#' observed value. The message gives the number of samples, their youngest
#' and oldest age and each count above zero.
#' @details
#' Ages are in years before 1950, so an age below `1950 - <build year>`
#' lies after the build. No document fixes a plausible range of fossil
#' ages, so there is no upper limit; the youngest and oldest ages are
#' reported for review. A sample without a dataset is counted under
#' `(none) / (none)`. Results are flagged, never failed
#' (`Documentation/Database_design_2.0.0.md`, section 7). Opens the
#' database read-only. Aborts when the database is not the one of the
#' manifest or `build_time_utc` does not start with a year.
#' @examples
#' \dontrun{
#' diagnose_sample_ages(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   vec_gridpoint_ages = build_gridpoint_ages()
#' )
#' }
diagnose_sample_ages <- function(
  path_database,
  list_build_manifest,
  vec_gridpoint_ages
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  assertthat::assert_that(
    base::is.numeric(vec_gridpoint_ages),
    base::length(vec_gridpoint_ages) > 0L,
    base::all(base::is.finite(vec_gridpoint_ages)),
    msg = "'vec_gridpoint_ages' must be a non-empty vector of numbers."
  )

  time_build <-
    purrr::pluck(
      list_build_manifest, "build_time_utc",
      .default = NA_character_
    )

  if (
    !base::isTRUE(stringr::str_detect(time_build, "^[0-9]{4}-"))
  ) {
    cli::cli_abort(
      "{.field build_time_utc} of the build manifest must start with a
      year."
    )
  }

  # Ages are years before 1950, so younger ages lie after the build
  age_future <-
    1950L - base::as.integer(stringr::str_sub(time_build, 1L, 4L))

  data_ages <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT COALESCE(t.dataset_type, '(none)') || ' / ' ||",
        "COALESCE(st.dataset_source_type, '(none)') AS scope,",
        "MAX(COALESCE(t.dataset_type = 'gridpoints', 0)) AS is_gridpoint,",
        "COUNT(*) AS n_samples,",
        "COALESCE(SUM(s.age IS NULL), 0) AS n_missing,",
        "COALESCE(SUM(s.age < ?), 0) AS n_future,",
        "COALESCE(SUM(s.age NOT IN (",
        stringr::str_c(
          base::sprintf("%.17g", vec_gridpoint_ages),
          collapse = ", "
        ),
        ")), 0) AS n_off_grid,",
        "MIN(s.age) AS age_min, MAX(s.age) AS age_max",
        "FROM Samples AS s",
        "LEFT JOIN DatasetSample AS ds ON ds.sample_id = s.sample_id",
        "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
        "LEFT JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
        "LEFT JOIN DatasetSourceTypeID AS st",
        "ON st.data_source_type_id = d.data_source_type_id",
        "GROUP BY 1"
      ),
      params = base::list(age_future),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = c(is_gridpoint, dplyr::starts_with("n_")),
        .fns = base::as.integer
      ),
      # Only gridpoints are bound to the time steps of the climate data
      n_off_grid = dplyr::if_else(is_gridpoint == 1L, n_off_grid, 0L),
      n_flagged = n_missing + n_future + n_off_grid,
      text_ages = dplyr::if_else(
        base::is.na(age_min),
        "no age",
        stringr::str_c(
          "ages ", base::sprintf("%.7g", age_min), " to ",
          base::sprintf("%.7g", age_max)
        )
      ),
      part_missing = dplyr::if_else(
        n_missing > 0L,
        stringr::str_c("missing: ", n_missing),
        NA_character_
      ),
      part_future = dplyr::if_else(
        n_future > 0L,
        stringr::str_c(
          "after the build (below ", age_future, "): ", n_future
        ),
        NA_character_
      ),
      part_off_grid = dplyr::if_else(
        n_off_grid > 0L,
        stringr::str_c("off the climate time steps: ", n_off_grid),
        NA_character_
      ),
      text_parts = purrr::map_chr(
        .x = base::seq_along(part_missing),
        .f = ~ stringr::str_c(
          stats::na.omit(
            c(part_missing[.x], part_future[.x], part_off_grid[.x])
          ),
          collapse = "; "
        )
      ),
      message = stringr::str_c(
        n_samples,
        dplyr::if_else(n_samples == 1L, " sample, ", " samples, "),
        text_ages,
        dplyr::if_else(
          base::nzchar(text_parts),
          stringr::str_c("; ", text_parts),
          ""
        ),
        "."
      )
    ) |>
    dplyr::arrange(scope)

  res <-
    build_check_result(
      check_id = "sample_ages",
      scope = dplyr::pull(data_ages, scope),
      status = dplyr::if_else(
        dplyr::pull(data_ages, n_flagged) == 0L,
        "pass",
        "flag"
      ),
      observed = dplyr::pull(data_ages, n_flagged),
      threshold = 0L,
      message = dplyr::pull(data_ages, message)
    )

  return(res)
}
