#' @title Build a small VegVault database for tests
#' @description
#' Write a new SQLite file with the full VegVault schema and a few
#' hand-made rows, so that functions that read the database (including the
#' `vaultkeepr` queries of the figures) can be tested without the real
#' database.
#' @param path_database
#' Character scalar. Path of the new database file. The file must not
#' exist yet; its folder must exist.
#' @param path_schema
#' Character scalar. The SQL file with the schema. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @return
#' Character scalar: `path_database`.
#' @details
#' The rows are fixed, so tests can compute the expected results by hand:
#' \itemize{
#'   \item One version row, `version_control` id 1 with version `2.0.0`,
#'     as every 2.0.0 database has: `vaultkeepr` reads a database without
#'     version rows as 1.0.0 and warns that its trait units may be
#'     unreliable.
#'   \item Dataset types 1 `vegetation_plot`, 2 `fossil_pollen_archive`,
#'     3 `traits` and 4 `gridpoints` (`vaultkeepr` expects 4 for
#'     gridpoints); source types 1 `sPlotOpen`, 2 `BIEN`, 3 `FOSSILPOL`,
#'     4 `TRY` and 5 `gridpoints`.
#'   \item Czechia: vegetation plots 1 (14, 50) and 2 (16, 49.5), and
#'     gridpoints 3 (14.1, 50.1), 4 (16.1, 49.6) and 5 (18, 49). Plots 1
#'     and 2 link to gridpoints 3 and 4 (10 and 12 km); gridpoint 5 has no
#'     link. All their samples are of age 0. The links are stored per
#'     position: positions 1 (14, 50, 0) and 2 (16, 49.5, 0) hold samples
#'     1 and 2, and the view `AbioticDataReference` returns one row per
#'     sample.
#'   \item North America: vegetation plot 6 `bien_na_1` (-100, 45) and
#'     fossil pollen dataset 7 `fossilpol_1001` (-90, 50) with samples of
#'     ages 1000 and 6000.
#'   \item Latin America: fossil pollen dataset 8 `fossilpol_1002`
#'     (-70, -20) with samples of ages 7000 and 11000, and trait dataset 9
#'     `try_la_1` (-65, -15) with one sample without age.
#'   \item Samples 1 to 11 in dataset order (one per dataset, two in
#'     datasets 7 and 8). Vegetation plot samples have sizes 100, 400 and
#'     100 square meters. Fossil samples have 2 or 3 age iterations.
#'   \item Taxa 1 `Picea abies`, 2 `Picea`, 3 `Pinaceae`, 4
#'     `Quercus robur`, 5 `Quercus`, 6 `Fagaceae` and 7 `Indet.`; all but
#'     taxon 7 are classified.
#'   \item Abiotic variables 1 `bio1` and 2 `bio12` on gridpoints; trait
#'     domains 1 `Plant heigh` (unit `m`) and 2 `Leaf Area` (unit `mm2`),
#'     with values for taxa 1 and 4 in sample 11. Each value uses the
#'     identity conversion rule of its unit, 1 `fixture_identity` (`m`) or
#'     2 `fixture_identity_mm2` (`mm2`), so every value is in the unit its
#'     rule produces.
#' }
#' Reference tables are left empty. The schema, its indexes included, is
#' created with `build_database_schema()` before the rows are written.
#' Aborts when `path_database` exists, so that no database is ever
#' overwritten.
#' @examples
#' \dontrun{
#' path_database <-
#'   build_database_fixture(
#'     path_database = base::file.path(base::tempdir(), "fixture.sqlite")
#'   )
#' }
build_database_fixture <- function(
  path_database,
  path_schema = here::here("Data", "SQL", "make_tables.sql")
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(path_schema),
    base::length(path_schema) == 1L,
    !base::is.na(path_schema),
    base::file.exists(path_schema),
    msg = "`path_schema` must be the path of an existing SQL file."
  )

  if (
    base::file.exists(path_database)
  ) {
    cli::cli_abort(
      "{.arg path_database} already exists; the fixture never overwrites a
      file."
    )
  }

  # Table rows, in an order that respects the foreign keys
  list_tables <-
    list(
      version_control = tibble::tribble(
        ~id, ~version, ~update_date, ~changelog,
        1L, "2.0.0", "2026-11-25", "Test fixture"
      ),
      DatasetTypeID = tibble::tribble(
        ~dataset_type_id, ~dataset_type,
        1L, "vegetation_plot",
        2L, "fossil_pollen_archive",
        3L, "traits",
        4L, "gridpoints"
      ),
      DatasetSourceTypeID = tibble::tribble(
        ~data_source_type_id, ~dataset_source_type,
        1L, "sPlotOpen",
        2L, "BIEN",
        3L, "FOSSILPOL",
        4L, "TRY",
        5L, "gridpoints"
      ),
      Datasets = tibble::tribble(
        ~dataset_id, ~dataset_name, ~dataset_type_id, ~data_source_type_id,
        ~coord_long, ~coord_lat,
        1L, "splot_cz_1", 1L, 1L, 14, 50,
        2L, "splot_cz_2", 1L, 1L, 16, 49.5,
        3L, "gridpoint_cz_1", 4L, 5L, 14.1, 50.1,
        4L, "gridpoint_cz_2", 4L, 5L, 16.1, 49.6,
        5L, "gridpoint_cz_3", 4L, 5L, 18, 49,
        6L, "bien_na_1", 1L, 2L, -100, 45,
        7L, "fossilpol_1001", 2L, 3L, -90, 50,
        8L, "fossilpol_1002", 2L, 3L, -70, -20,
        9L, "try_la_1", 3L, 4L, -65, -15
      ),
      SampleSizeID = tibble::tribble(
        ~sample_size_id, ~sample_size, ~description,
        1L, 100, "square meters",
        2L, 400, "square meters"
      ),
      Samples = tibble::tribble(
        ~sample_id, ~sample_name, ~age, ~sample_size_id,
        1L, "plot_cz_1", 0, 1L,
        2L, "plot_cz_2", 0, 2L,
        3L, "grid_cz_1", 0, NA_integer_,
        4L, "grid_cz_2", 0, NA_integer_,
        5L, "grid_cz_3", 0, NA_integer_,
        6L, "plot_na_1", 0, 1L,
        7L, "fossil_na_1", 1000, NA_integer_,
        8L, "fossil_na_2", 6000, NA_integer_,
        9L, "fossil_la_1", 7000, NA_integer_,
        10L, "fossil_la_2", 11000, NA_integer_,
        11L, "trait_la_1", NA_real_, NA_integer_
      ),
      DatasetSample = tibble::tribble(
        ~dataset_id, ~sample_id,
        1L, 1L,
        2L, 2L,
        3L, 3L,
        4L, 4L,
        5L, 5L,
        6L, 6L,
        7L, 7L,
        7L, 8L,
        8L, 9L,
        8L, 10L,
        9L, 11L
      ),
      SampleUncertainty = tibble::tribble(
        ~sample_id, ~iteration, ~age,
        7L, 1L, 900L,
        7L, 2L, 1000L,
        7L, 3L, 1200L,
        8L, 1L, 5800L,
        8L, 2L, 6000L,
        8L, 3L, 6500L,
        9L, 1L, 6900L,
        9L, 2L, 7100L,
        10L, 1L, 10500L,
        10L, 2L, 11500L
      ),
      Taxa = tibble::tribble(
        ~taxon_id, ~taxon_name,
        1L, "Picea abies",
        2L, "Picea",
        3L, "Pinaceae",
        4L, "Quercus robur",
        5L, "Quercus",
        6L, "Fagaceae",
        7L, "Indet."
      ),
      TaxonClassification = tibble::tribble(
        ~taxon_id, ~taxon_species, ~taxon_genus, ~taxon_family,
        1L, 1L, 2L, 3L,
        2L, NA_integer_, 2L, 3L,
        3L, NA_integer_, NA_integer_, 3L,
        4L, 4L, 5L, 6L,
        5L, NA_integer_, 5L, 6L,
        6L, NA_integer_, NA_integer_, 6L
      ),
      SampleTaxa = tibble::tribble(
        ~sample_id, ~taxon_id, ~value,
        1L, 1L, 5,
        1L, 4L, 3,
        2L, 4L, 2,
        6L, 1L, 4,
        7L, 2L, 10,
        7L, 5L, 0,
        8L, 5L, 3,
        9L, 1L, 6,
        9L, 4L, 2,
        10L, 5L, 1
      ),
      AbioticVariable = tibble::tribble(
        ~abiotic_variable_id, ~abiotic_variable_name,
        ~abiotic_variable_unit,
        1L, "bio1", "\u00b0C",
        2L, "bio12", "kg m-2 year-1"
      ),
      AbioticData = tibble::tribble(
        ~sample_id, ~abiotic_variable_id, ~abiotic_value,
        3L, 1L, 8.5,
        3L, 2L, 600,
        4L, 1L, 9,
        4L, 2L, 550,
        5L, 1L, 7
      ),
      # The links of plots 1 and 2, read back per sample through the view
      #   AbioticDataReference
      Positions = tibble::tribble(
        ~position_id, ~coord_long, ~coord_lat, ~age,
        1L, 14, 50, 0,
        2L, 16, 49.5, 0
      ),
      SamplePosition = tibble::tribble(
        ~sample_id, ~position_id,
        1L, 1L,
        2L, 2L
      ),
      PositionLink = tibble::tribble(
        ~position_id, ~sample_ref_id, ~distance_in_km, ~distance_in_years,
        1L, 3L, 10L, 0L,
        2L, 4L, 12L, 0L
      ),
      TraitsDomain = tibble::tribble(
        ~trait_domain_id, ~trait_domain_name, ~trait_unit,
        1L, "Plant heigh", "m",
        2L, "Leaf Area", "mm2"
      ),
      Traits = tibble::tribble(
        ~trait_id, ~trait_domain_id, ~trait_name,
        1L, 1L, "Plant height vegetative",
        2L, 2L, "Leaf area"
      ),
      TraitUnitConversion = tibble::tribble(
        ~trait_unit_conversion_id, ~conversion_rule_key, ~rule_version,
        ~source_provider, ~source_trait_id, ~normalized_original_unit,
        ~standardized_unit, ~trait_dimension, ~operation, ~multiplier,
        ~evidence,
        1L, "fixture_identity", "1", "fixture", "fixture", "m", "m",
        "length", "identity", 1, "Test fixture",
        2L, "fixture_identity_mm2", "1", "fixture", "fixture", "mm2", "mm2",
        "area", "identity", 1, "Test fixture"
      ),
      TraitsValue = tibble::tribble(
        ~trait_id, ~dataset_id, ~sample_id, ~taxon_id, ~trait_value,
        ~trait_unit_conversion_id,
        1L, 9L, 11L, 1L, 30, 1L,
        1L, 9L, 11L, 4L, 20, 1L,
        2L, 9L, 11L, 4L, 5000, 2L
      )
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      build_database_schema(con = con, path_schema = path_schema)

      purrr::iwalk(
        .x = list_tables,
        .f = ~ DBI::dbAppendTable(conn = con, name = .y, value = .x)
      )
    },
    flag_read_only = FALSE
  )

  res <- path_database

  return(res)
}
