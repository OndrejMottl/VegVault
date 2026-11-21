# Build a small 2.0.0 database that passes the validation checks: the
#   tables of build_database_fixture(), the version rows of 1.0.0 and of the
#   build, one producer row, a pin manifest and a build manifest written
#   after the last change to the database.
# Returns a list with `path_database`, `list_build_manifest`,
#   `list_version` and `path_producer_manifest`.
build_validation_database <- function(
  dir,
  profile = "default",
  tag = NULL,
  commit_sha = NA_character_
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
        base::paste(
          "INSERT INTO version_control (id, version, update_date, changelog)",
          "VALUES (1, '1.0.0', '2025-01-20', 'First release of the database')"
        )
      )

      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO version_control (id, version, update_date, changelog,",
          "build_profile, git_commit, manifest_sha256)",
          "VALUES (2, '2.0.0', '2026-08-28', ?, ?, ?, ?)"
        ),
        params = base::list(
          list_version$changelog,
          profile,
          git_commit,
          compute_text_file_sha256(path_file = path_producer_manifest)
        )
      )

      DBI::dbExecute(
        .x,
        "INSERT INTO BuildProducers VALUES (2, 'splot_plots', ?, ?)",
        params = base::list(tag_stored, commit_sha)
      )
    }
  )

  list_producer_pins <-
    base::list(
      base::list(
        artefact_id = "splot_plots",
        contract_version = "1.0.0",
        mode = base::ifelse(profile == "release", "release", "dev"),
        tag = tag,
        files = base::list(
          base::list(
            file_name = "data_splot_2026-11-20__0123456789__.qs",
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
