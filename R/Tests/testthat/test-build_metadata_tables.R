#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_metadata_tables() validates arguments", {
  list_versions <-
    base::list(
      base::list(
        version = "1.0.0",
        update_date = "2025-01-20",
        changelog = "First release"
      ),
      base::list(
        version = "2.0.0",
        update_date = "2026-11-21",
        changelog = "Second release"
      )
    )

  list_authors <-
    base::list(
      base::list(
        fullname = "A. Author",
        email = "a@example.org",
        orcid = "0000-0000-0000-0000"
      )
    )

  testthat::expect_error(
    build_metadata_tables(
      list_versions = base::list(),
      list_authors = list_authors,
      list_producer_pins = base::list(),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = base::strrep("b", 64L)
    ),
    regexp = "list_versions"
  )

  testthat::expect_error(
    build_metadata_tables(
      list_versions = c(list_versions, list_versions[2L]),
      list_authors = list_authors,
      list_producer_pins = base::list(),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = base::strrep("b", 64L)
    ),
    regexp = "repeat"
  )

  testthat::expect_error(
    build_metadata_tables(
      list_versions = list_versions,
      list_authors = list_authors,
      list_producer_pins = base::list(),
      build_profile = "default",
      git_commit = "not a commit",
      manifest_sha256 = base::strrep("b", 64L)
    ),
    regexp = "git_commit"
  )

  testthat::expect_error(
    build_metadata_tables(
      list_versions = list_versions,
      list_authors = list_authors,
      list_producer_pins = base::list(),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = "short"
    ),
    regexp = "manifest_sha256"
  )

  testthat::expect_error(
    build_metadata_tables(
      list_versions = list_versions,
      list_authors = base::list(base::list(fullname = "A. Author")),
      list_producer_pins = base::list(),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = base::strrep("b", 64L)
    ),
    regexp = "list_authors"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("build_metadata_tables() marks the version being built", {
  res <-
    build_metadata_tables(
      list_versions = base::list(
        base::list(
          version = "1.0.0",
          update_date = "2025-01-20",
          changelog = "First release"
        ),
        base::list(
          version = "2.0.0",
          update_date = "2026-11-21",
          changelog = "Second release"
        )
      ),
      list_authors = base::list(
        base::list(
          fullname = "A. Author",
          email = "a@example.org",
          orcid = "0000-0000-0000-0000"
        )
      ),
      # A commit in a pin is not stored: the pins hold none (the checksums
      #   of the files tie a build to its producer files)
      list_producer_pins = base::list(
        base::list(artefact_id = "splot_plots", tag = NULL),
        base::list(
          artefact_id = "bien_plots",
          tag = "v2.0.0",
          commit_sha = base::strrep("c", 40L)
        )
      ),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = base::strrep("b", 64L)
    )

  testthat::expect_named(
    res,
    c("version_control", "BuildProducers", "Authors")
  )

  data_versions <-
    purrr::chuck(res, "version_control")

  testthat::expect_named(
    data_versions,
    c(
      "id", "version", "update_date", "changelog", "build_profile",
      "git_commit", "manifest_sha256"
    )
  )
  testthat::expect_equal(dplyr::pull(data_versions, id), c(1L, 2L))
  testthat::expect_equal(
    dplyr::pull(data_versions, build_profile),
    c(NA_character_, "default")
  )
  testthat::expect_equal(
    dplyr::pull(data_versions, git_commit),
    c(NA_character_, base::strrep("a", 40L))
  )

  data_producers <-
    purrr::chuck(res, "BuildProducers")

  testthat::expect_named(
    data_producers,
    c("version_id", "producer", "tag")
  )
  testthat::expect_equal(
    dplyr::pull(data_producers, producer),
    c("bien_plots", "splot_plots")
  )
  testthat::expect_equal(dplyr::pull(data_producers, version_id), c(2L, 2L))
  testthat::expect_equal(
    dplyr::pull(data_producers, tag),
    c("v2.0.0", NA_character_)
  )

  testthat::expect_named(
    purrr::chuck(res, "Authors"),
    c("author_id", "author_fullname", "author_email", "author_orcid")
  )
  testthat::expect_equal(
    dplyr::pull(purrr::chuck(res, "Authors"), author_id),
    1L
  )
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("build_metadata_tables() refuses a repeated producer", {
  testthat::expect_error(
    build_metadata_tables(
      list_versions = base::list(
        base::list(
          version = "2.0.0",
          update_date = "2026-11-21",
          changelog = "Release"
        )
      ),
      list_authors = base::list(),
      list_producer_pins = base::list(
        base::list(artefact_id = "splot_plots", tag = NULL),
        base::list(artefact_id = "splot_plots", tag = NULL)
      ),
      build_profile = "default",
      git_commit = base::strrep("a", 40L),
      manifest_sha256 = base::strrep("b", 64L)
    ),
    regexp = "splot_plots"
  )
})
