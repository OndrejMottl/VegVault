# Build a small 2.0.0 database that passes the validation checks: the
#   tables of build_database_fixture(), the version rows of 1.0.0 and of the
#   build, three producer rows, a pin manifest and a build manifest written
#   after the last change to the database. As the link step would, it
#   stores the truncated geodesic distances of the two fixture links
#   (13 and 13 km, not the fixture's 10 and 12) and gives positions 101 to
#   105, without links, to the plot and fossil samples that have
#   coordinates and an age. The fixture's leaf-area value (domain unit mm2)
#   uses the only conversion rule, which gives m; a second rule, giving
#   mm2, is added for it, so that the trait units agree.
# Returns a list with `path_database`, `list_build_manifest`,
#   `list_version` and `path_producer_manifest`.
build_validation_database <- function(
  dir,
  profile = "default",
  tag = NULL
) {
  path_database <-
    base::file.path(dir, "VegVault.sqlite")

  build_database_fixture(path_database = path_database)

  path_producer_manifest <-
    base::file.path(dir, "producer_manifest.yml")

  base::writeLines(
    text = c("manifest_version: 1", "artefacts: []"),
    con = path_producer_manifest
  )

  list_version <-
    base::list(
      version = "2.0.0",
      update_date = "2026-08-28",
      changelog = "Development build for the tests"
    )

  git_commit <-
    base::strrep("1a2b3c4d", 5L)

  tag_stored <-
    if (
      base::is.null(tag)
    ) {
      NA_character_
    } else {
      tag
    }

  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO version_control (id, version, update_date, changelog)",
          "VALUES (1, '1.0.0', '2025-01-20', 'First release of the database')",
          sep = " "
        )
      )

      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO version_control (id, version, update_date, changelog,",
          "build_profile, git_commit, manifest_sha256)",
          "VALUES (2, '2.0.0', '2026-08-28', ?, ?, ?, ?)",
          sep = " "
        ),
        params = base::list(
          purrr::chuck(list_version, "changelog"),
          profile,
          git_commit,
          compute_text_file_sha256(path_file = path_producer_manifest)
        )
      )

      DBI::dbExecute(
        .x,
        "INSERT INTO BuildProducers VALUES (2, 'splot_plots', ?)",
        params = base::list(tag_stored)
      )

      # A rule in the unit of the leaf-area domain, for its value
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO TraitUnitConversion (trait_unit_conversion_id,",
          "conversion_rule_key, rule_version, source_provider,",
          "source_trait_id, normalized_original_unit, standardized_unit,",
          "trait_dimension, operation, multiplier, evidence)",
          "VALUES (2, 'fixture_identity_mm2', '1', 'fixture', 'fixture',",
          "'mm2', 'mm2', 'area', 'identity', 1, 'Test fixture')",
          sep = " "
        )
      )

      DBI::dbExecute(
        .x,
        stringr::str_c(
          "UPDATE TraitsValue SET trait_unit_conversion_id = 2",
          "WHERE trait_id = 2",
          sep = " "
        )
      )

      # The distances the link step stores for the fixture links
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "UPDATE PositionLink SET distance_in_km = ?",
          "WHERE position_id = ? AND sample_ref_id = ?",
          sep = " "
        ),
        params = base::list(
          base::as.integer(
            geosphere::distGeo(
              p1 = base::rbind(c(14, 50), c(16, 49.5)),
              p2 = base::rbind(c(14.1, 50.1), c(16.1, 49.6))
            ) / 1e3
          ),
          c(1L, 2L),
          c(3L, 4L)
        )
      )

      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO Positions VALUES (101, -100, 45, 0),",
          "(102, -90, 50, 1000), (103, -90, 50, 6000),",
          "(104, -70, -20, 7000), (105, -70, -20, 11000)",
          sep = " "
        )
      )

      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO SamplePosition VALUES (6, 101), (7, 102), (8, 103),",
          "(9, 104), (10, 105)",
          sep = " "
        )
      )

      # The producer rows of the two trait pins
      DBI::dbExecute(
        .x,
        stringr::str_c(
          "INSERT INTO BuildProducers VALUES (2, 'try_traits', ?),",
          "(2, 'bien_traits', ?)",
          sep = " "
        ),
        params = base::list(tag_stored, tag_stored)
      )
    }
  )

  # One pin per producer row, with the rows stage 01 would record: the 2
  #   sPlot plots, the 3 TRY trait values and no BIEN trait value of the
  #   fixture
  data_pins <-
    tibble::tribble(
      ~artefact_id, ~n_rows, ~file_name,
      "splot_plots", 2, "data_splot_2026-11-20__0123456789__.qs",
      "try_traits", 3, "data_trait_try_2026-11-20__0123456789__.qs",
      "bien_traits", 0, "data_traits_bien_0_2026-11-20__0123456789__.qs"
    )

  list_producer_pins <-
    purrr::map(
      .x = base::seq_len(base::nrow(data_pins)),
      .f = ~ base::list(
        artefact_id = dplyr::pull(data_pins, artefact_id)[.x],
        contract_version = "1.0.0",
        mode = base::ifelse(profile == "release", "release", "dev"),
        tag = tag,
        n_rows = dplyr::pull(data_pins, n_rows)[.x],
        files = base::list(
          base::list(
            file_name = dplyr::pull(data_pins, file_name)[.x],
            size = 10L,
            sha256 = base::strrep("ab", 32L)
          )
        )
      )
    )

  path_manifest <-
    save_build_manifest(
      path_database = path_database,
      profile = profile,
      list_subset = base::list(enabled = FALSE),
      list_version = list_version,
      list_producer_pins = list_producer_pins,
      git_commit = git_commit,
      flag_git_clean = TRUE,
      time_build = base::as.POSIXct("2026-11-21 10:15:00", tz = "UTC"),
      path_manifest = base::file.path(dir, "VegVault_build_manifest.yml")
    )

  res <-
    base::list(
      path_database = path_database,
      list_build_manifest = load_build_manifest(
        path_manifest = path_manifest,
        path_database = path_database
      ),
      list_version = list_version,
      path_producer_manifest = path_producer_manifest
    )

  return(res)
}
