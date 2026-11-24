#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_assembly_targets() validates arguments", {
  testthat::expect_error(
    build_database_assembly_targets(
      store_producer_import = NA_character_,
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
    ),
    regexp = "store_producer_import"
  )

  testthat::expect_error(
    build_database_assembly_targets(
      store_producer_import = "store_a",
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = c("a.R", "b.R")
    ),
    regexp = "runner_gridpoints"
  )
})

testthat::test_that("build_database_assembly_targets() scans quietly", {
  # targets reads every function a pipeline loads; a ..1 in a purrr
  #   lambda made it warn '..1 may be used in an incorrect context'
  testthat::expect_no_warning(
    targets::tar_deps_raw(build_database_assembly_targets)
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_assembly_targets() declares the stage", {
  res <-
    build_database_assembly_targets(
      store_producer_import = "store_a",
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
    )

  vec_names <-
    purrr::map_chr(
      .x = res,
      .f = ~ purrr::pluck(.x, "settings", "name")
    )

  vec_sources <-
    c(
      "splot", "bien_plots", "fossilpol", "try", "bien_traits",
      "gridpoints", "chelsa_neoclimate", "chelsa_trace21k_palaeoclimate",
      "hwsd_soil", "taxospace"
    )

  vec_variables <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  vec_expected <-
    c(
      stringr::str_c("list_source_", vec_sources),
      "list_general", "list_versions", "list_authors",
      "n_link_coordinate_digits", "n_taxon_batches", "name_check_taxon",
      "sel_taxon_db_name", "sel_taxon_db_class",
      "flag_taxon_only_exact_match", "sel_taxon_kingdom", "n_build_chunk_size",
      "list_taxon_corrections", "list_pragmas_load", "list_pragmas_final",
      "file_producer_manifest",
      "file_contract_chelsa_neoclimate",
      "file_contract_chelsa_trace21k_palaeoclimate",
      "list_variables_chelsa_neoclimate",
      "list_variables_chelsa_trace21k_palaeoclimate",
      "data_references_chelsa_neoclimate",
      "data_references_chelsa_trace21k_palaeoclimate",
      "data_references_hwsd_soil",
      "fingerprint_producer_import", "fingerprint_gridpoints",
      "profile_producer_import", "profile_gridpoints",
      "check_fossilpol_relations", "list_producer_pins",
      "data_trait_unit_rules",
      stringr::str_c(
        "list_tables_",
        c(
          "splot", "bien_plots", "fossilpol", "try", "bien_traits",
          "gridpoints", "hwsd_soil", "taxospace"
        )
      ),
      stringr::str_c("list_tables_chelsa_neoclimate_", vec_variables),
      stringr::str_c(
        "list_tables_chelsa_trace21k_palaeoclimate_",
        vec_variables
      ),
      "list_positions", "data_gridpoint_samples", "vec_taxon_names",
      "data_taxon_batches", "data_classification",
      "data_classification_corrected", "list_database_tables",
      "list_position_tables", "list_metadata_tables", "list_database_load",
      "file_build_manifest"
    )

  testthat::expect_true(
    base::all(
      purrr::map_lgl(.x = res, .f = ~ base::inherits(.x, "tar_target"))
    )
  )

  testthat::expect_setequal(vec_names, vec_expected)

  testthat::expect_equal(base::anyDuplicated(vec_names), 0L)
})

testthat::test_that("build_database_assembly_targets() sets formats", {
  res <-
    build_database_assembly_targets(
      store_producer_import = "store_a",
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
    )

  list_targets <-
    rlang::set_names(
      res,
      purrr::map_chr(.x = res, .f = ~ purrr::pluck(.x, "settings", "name"))
    )

  vec_always <-
    c(
      "list_source_splot", "list_versions", "n_taxon_batches",
      "path_database", "file_producer_manifest",
      "file_contract_chelsa_neoclimate", "fingerprint_producer_import",
      "fingerprint_gridpoints"
    ) |>
    base::intersect(base::names(list_targets))

  testthat::expect_true(
    base::all(
      purrr::map_chr(
        .x = vec_always,
        .f = ~ purrr::pluck(list_targets, .x, "cue", "mode")
      ) == "always"
    )
  )

  vec_files <-
    c(
      "file_producer_manifest", "file_contract_chelsa_neoclimate",
      "file_contract_chelsa_trace21k_palaeoclimate", "file_build_manifest"
    )

  testthat::expect_true(
    base::all(
      purrr::map_chr(
        .x = vec_files,
        .f = ~ purrr::pluck(list_targets, .x, "settings", "format")
      ) == "file"
    )
  )

  vec_qs <-
    c(
      "list_tables_splot", "list_tables_chelsa_trace21k_palaeoclimate_bio1",
      "list_positions", "list_database_tables", "list_position_tables"
    )

  testthat::expect_true(
    base::all(
      purrr::map_chr(
        .x = vec_qs,
        .f = ~ purrr::pluck(list_targets, .x, "settings", "format")
      ) == "qs"
    )
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "data_taxon_batches", "settings", "iteration"),
    "list"
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "data_classification", "settings", "pattern") |>
      base::as.list() |>
      purrr::pluck(1L) |>
      base::deparse(),
    "map(data_taxon_batches)"
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "list_tables_splot", "cue", "mode"),
    "thorough"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_database_assembly_targets() wires the inputs", {
  res <-
    build_database_assembly_targets(
      store_producer_import = "store_a",
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
    )

  list_deps <-
    rlang::set_names(
      purrr::map(.x = res, .f = ~ purrr::pluck(.x, "deps")),
      purrr::map_chr(.x = res, .f = ~ purrr::pluck(.x, "settings", "name"))
    )

  list_expected <-
    base::list(
      profile_producer_import = c(
        "fingerprint_producer_import", "profile_active"
      ),
      list_tables_fossilpol = c(
        "fingerprint_producer_import", "profile_producer_import",
        "check_fossilpol_relations", "list_source_fossilpol"
      ),
      list_tables_chelsa_trace21k_palaeoclimate_bio1 = c(
        "fingerprint_producer_import", "profile_producer_import",
        "data_gridpoint_samples",
        "list_variables_chelsa_trace21k_palaeoclimate",
        "data_references_chelsa_trace21k_palaeoclimate",
        "n_link_coordinate_digits"
      ),
      list_positions = c(
        "fingerprint_gridpoints", "profile_gridpoints", "list_tables_splot",
        "list_tables_bien_plots", "list_tables_fossilpol", "list_tables_try",
        "list_tables_bien_traits"
      ),
      vec_taxon_names = c(
        "list_tables_splot", "list_tables_bien_plots", "list_tables_fossilpol",
        "list_tables_try", "list_tables_bien_traits"
      ),
      data_classification = c(
        "data_taxon_batches", "name_check_taxon", "sel_taxon_db_name",
        "sel_taxon_db_class", "flag_taxon_only_exact_match",
        "sel_taxon_kingdom"
      ),
      data_classification_corrected = c(
        "data_classification", "list_taxon_corrections"
      ),
      list_tables_taxospace = c(
        "data_classification_corrected", "list_source_taxospace"
      ),
      list_database_tables = c(
        "list_tables_splot", "list_tables_gridpoints",
        "list_tables_chelsa_neoclimate_bio19", "list_tables_hwsd_soil",
        "list_tables_taxospace", "data_trait_unit_rules", "list_general"
      ),
      list_metadata_tables = c(
        "list_versions", "list_authors", "list_producer_pins",
        "profile_active", "git_commit", "file_producer_manifest"
      ),
      list_database_load = c(
        "path_database", "list_database_tables", "list_position_tables",
        "list_metadata_tables", "list_pragmas_load", "list_pragmas_final",
        "n_build_chunk_size", "profile_active"
      ),
      file_build_manifest = c(
        "list_database_load", "path_database", "profile_active",
        "list_subset", "list_versions", "list_producer_pins", "git_commit",
        "flag_git_clean"
      )
    )

  purrr::iwalk(
    .x = list_expected,
    .f = ~ testthat::expect_true(
      base::all(.x %in% purrr::chuck(list_deps, .y)),
      label = .y
    )
  )

  # A changed correction must not classify any batch again
  testthat::expect_false(
    "list_taxon_corrections" %in% purrr::chuck(list_deps, "data_classification")
  )
})

testthat::test_that("build_database_assembly_targets() keeps the order", {
  res <-
    build_database_assembly_targets(
      store_producer_import = "store_a",
      runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
      store_gridpoints = "store_b",
      runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
    )

  target_tables <-
    purrr::keep(
      .x = res,
      .p = ~ purrr::pluck(.x, "settings", "name") == "list_database_tables"
    ) |>
    purrr::pluck(1L)

  vec_sources <-
    purrr::pluck(target_tables, "command", "expr") |>
    base::as.list() |>
    purrr::pluck(1L) |>
    rlang::call_args() |>
    purrr::chuck("list_source_tables") |>
    rlang::call_args() |>
    base::names()

  vec_variables <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  testthat::expect_equal(
    vec_sources,
    c(
      "splot", "bien_plots", "fossilpol", "try", "bien_traits", "gridpoints",
      stringr::str_c("chelsa_neoclimate_", vec_variables),
      stringr::str_c("chelsa_trace21k_palaeoclimate_", vec_variables),
      "hwsd_soil", "taxospace"
    )
  )
})

testthat::test_that("build_database_assembly_targets() runs on fixtures", {
  dir_root <-
    withr::local_tempdir()

  list_stores <-
    build_test_assembly_stores(dir_root = base::file.path(dir_root, "up"))

  base::dir.create(base::file.path(dir_root, "database"))

  path_test_database <-
    base::file.path(dir_root, "database", "VegVault_test.sqlite")

  path_script <-
    base::file.path(dir_root, "_targets.R")

  path_store <-
    base::file.path(dir_root, "_targets")

  # Every name is classified as Quercus robur, so the classification adds
  #   the species, genus and family names; each call is recorded
  env_calls <-
    rlang::env(list_names = base::list())

  testthat::local_mocked_bindings(
    get_classification = function(taxa_vec, ...) {
      env_calls[["list_names"]] <-
        c(env_calls[["list_names"]], base::list(taxa_vec))

      build_test_taxospace_result(vec_names = "Quercus robur") |>
        dplyr::slice(base::rep(1L, base::length(taxa_vec))) |>
        dplyr::mutate(sel_name = taxa_vec)
    },
    .package = "taxospace"
  )

  # The pipeline-level targets, set to the test
  targets::tar_helper(
    path = path_script,
    code = {
      targets::tar_option_set(memory = "transient")

      list(
        targets::tar_target(name = "profile_active", command = "default"),
        targets::tar_target(
          name = "list_subset",
          command = list(enabled = FALSE)
        ),
        targets::tar_target(name = "flag_git_clean", command = TRUE),
        targets::tar_target(
          name = "git_commit",
          command = !!stringr::str_dup(string = "a", times = 40L)
        ),
        targets::tar_target(
          name = "path_database",
          command = !!path_test_database
        ),
        build_database_assembly_targets(
          store_producer_import = !!purrr::chuck(
            list_stores,
            "store_producer_import"
          ),
          runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
          store_gridpoints = !!purrr::chuck(list_stores, "store_gridpoints"),
          runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
        )
      )
    }
  )

  withr::defer(targets::tar_option_reset())

  suppressMessages(
    targets::tar_make(
      script = path_script,
      store = path_store,
      callr_function = NULL,
      reporter = "silent"
    )
  )

  testthat::expect_false(
    "errored" %in%
      dplyr::pull(targets::tar_progress(store = path_store), progress)
  )

  testthat::expect_true(base::file.exists(path_test_database))

  # The manifest describes the database
  path_manifest <-
    targets::tar_read(file_build_manifest, store = path_store)

  list_manifest <-
    load_build_manifest(
      path_manifest = path_manifest,
      path_database = path_test_database
    )

  testthat::expect_equal(purrr::chuck(list_manifest, "profile"), "default")

  # One call per batch, each with the check name first
  vec_names_classified <-
    targets::tar_read(vec_taxon_names, store = path_store)

  n_batches <-
    prepare_taxon_batches(
      vec_taxon_names = vec_names_classified,
      n_batches = load_config_value(
        value = c("build", "classification", "n_batches")
      )
    ) |>
    dplyr::distinct(batch_id) |>
    base::nrow()

  list_calls <-
    env_calls[["list_names"]]

  testthat::expect_length(list_calls, n_batches)

  testthat::expect_true(
    base::all(
      purrr::map_chr(.x = list_calls, .f = ~ purrr::pluck(.x, 1L)) ==
        "Quercus robur"
    )
  )

  # The database holds every kind of row and passes the checks
  list_checks <-
    run_with_database(
      path_database = path_test_database,
      fn = ~ base::list(
        fk = DBI::dbGetQuery(conn = .x, statement = "PRAGMA foreign_key_check"),
        integrity = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA integrity_check"
        ),
        counts = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT
            (SELECT COUNT(*) FROM SampleTaxa) AS n_sample_taxa,
            (SELECT COUNT(*) FROM TraitsValue) AS n_trait_values,
            (SELECT COUNT(*) FROM SampleUncertainty) AS n_uncertainty,
            (SELECT COUNT(*) FROM AbioticData) AS n_abiotic,
            (SELECT COUNT(DISTINCT abiotic_variable_id)
              FROM AbioticData) AS n_abiotic_variables,
            (SELECT COUNT(*) FROM PositionLink) AS n_links,
            (SELECT COUNT(*) FROM TaxonClassification) AS n_classification,
            (SELECT COUNT(*) FROM TraitUnitConversion) AS n_rules,
            (SELECT COUNT(*) FROM BuildProducers) AS n_producers,
            (SELECT COUNT(*) FROM version_control) AS n_versions"
        ),
        taxa = DBI::dbGetQuery(
          conn = .x,
          statement = "SELECT taxon_name FROM Taxa
            WHERE taxon_name IN ('Quercus robur', 'Quercus', 'Fagaceae')"
        )
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(base::nrow(purrr::chuck(list_checks, "fk")), 0L)

  testthat::expect_equal(
    dplyr::pull(purrr::chuck(list_checks, "integrity")),
    "ok"
  )

  data_counts <-
    purrr::chuck(list_checks, "counts")

  testthat::expect_true(
    base::all(
      dplyr::select(data_counts, -n_abiotic_variables, -n_producers) > 0L
    )
  )

  testthat::expect_equal(dplyr::pull(data_counts, n_abiotic_variables), 8L)

  testthat::expect_equal(dplyr::pull(data_counts, n_producers), 2L)

  testthat::expect_equal(
    dplyr::pull(data_counts, n_classification),
    base::length(vec_names_classified) + 3L
  )

  testthat::expect_setequal(
    dplyr::pull(purrr::chuck(list_checks, "taxa"), taxon_name),
    c("Quercus robur", "Quercus", "Fagaceae")
  )

  # A second run builds only the targets that run every time
  suppressMessages(
    targets::tar_make(
      script = path_script,
      store = path_store,
      callr_function = NULL,
      reporter = "silent"
    )
  )

  vec_built_again <-
    targets::tar_progress(store = path_store) |>
    dplyr::filter(progress == "completed") |>
    dplyr::pull(name)

  testthat::expect_false(
    base::any(
      c(
        "list_tables_splot", "data_classification", "list_database_tables",
        "list_database_load", "file_build_manifest"
      ) %in%
        vec_built_again
    )
  )

  testthat::expect_length(env_calls[["list_names"]], n_batches)

  # A new taxon in one sPlot plot classifies only its batch again; the
  #   existing database then stops the write
  data_splot <-
    load_valid_fixture(id_artefact = "splot_plots")

  data_splot_new <-
    dplyr::mutate(
      data_splot,
      taxa = purrr::map2(
        .x = taxa,
        .y = dplyr::row_number() == 1L,
        .f = ~ if (
          .y
        ) {
          dplyr::bind_rows(
            .x,
            dplyr::mutate(utils::head(.x, 1L), Species = "Synthetica novum")
          )
        } else {
          .x
        }
      )
    )

  build_test_assembly_stores(
    dir_root = base::file.path(dir_root, "up"),
    list_replace = base::list(
      data_splot_plots = base::list(data_splot_new.qs = data_splot_new)
    )
  )

  testthat::expect_error(
    suppressMessages(
      targets::tar_make(
        script = path_script,
        store = path_store,
        callr_function = NULL,
        reporter = "silent"
      )
    )
  )

  testthat::expect_match(
    targets::tar_meta(names = "list_database_load", store = path_store) |>
      dplyr::pull(error),
    regexp = "already exists"
  )

  list_calls_new <-
    env_calls[["list_names"]]

  testthat::expect_length(list_calls_new, n_batches + 1L)

  testthat::expect_true(
    "Synthetica novum" %in% purrr::pluck(list_calls_new, n_batches + 1L)
  )

  # After the old database is moved away by hand, the write completes
  base::file.remove(path_test_database)

  suppressMessages(
    targets::tar_make(
      script = path_script,
      store = path_store,
      callr_function = NULL,
      reporter = "silent"
    )
  )

  testthat::expect_length(env_calls[["list_names"]], n_batches + 1L)

  vec_taxa_new <-
    run_with_database(
      path_database = path_test_database,
      fn = ~ DBI::dbGetQuery(
        conn = .x,
        statement = "SELECT taxon_name FROM Taxa
          WHERE taxon_name = 'Synthetica novum'"
      ),
      flag_read_only = TRUE
    ) |>
    dplyr::pull(taxon_name)

  testthat::expect_equal(vec_taxa_new, "Synthetica novum")
})

testthat::test_that("build_database_assembly_targets() checks the stores", {
  dir_root <-
    withr::local_tempdir()

  path_script <-
    base::file.path(dir_root, "_targets.R")

  path_store <-
    base::file.path(dir_root, "_targets")

  # An upstream store built in the subset profile
  list_stores <-
    build_test_assembly_stores(
      dir_root = base::file.path(dir_root, "up"),
      list_replace = base::list(profile_build = "subset")
    )

  targets::tar_helper(
    path = path_script,
    code = {
      list(
        targets::tar_target(name = "profile_active", command = "default"),
        targets::tar_target(
          name = "list_subset",
          command = list(enabled = FALSE)
        ),
        targets::tar_target(name = "flag_git_clean", command = TRUE),
        targets::tar_target(
          name = "git_commit",
          command = !!stringr::str_dup(string = "a", times = 40L)
        ),
        targets::tar_target(
          name = "path_database",
          command = !!base::file.path(dir_root, "VegVault_test.sqlite")
        ),
        build_database_assembly_targets(
          store_producer_import = !!purrr::chuck(
            list_stores,
            "store_producer_import"
          ),
          runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
          store_gridpoints = !!purrr::chuck(list_stores, "store_gridpoints"),
          runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
        )
      )
    }
  )

  withr::defer(targets::tar_option_reset())

  testthat::expect_error(
    suppressMessages(
      targets::tar_make(
        script = path_script,
        store = path_store,
        callr_function = NULL,
        reporter = "silent"
      )
    )
  )

  testthat::expect_match(
    targets::tar_meta(names = "profile_producer_import", store = path_store) |>
      dplyr::pull(error),
    regexp = "01_Producer_import.*subset.*default"
  )

  # A store without the trait unit rules stops at the fingerprint
  build_test_assembly_stores(
    dir_root = base::file.path(dir_root, "up"),
    list_replace = base::list(data_trait_unit_rules = purrr::zap())
  )

  testthat::expect_error(
    suppressMessages(
      targets::tar_make(
        script = path_script,
        store = path_store,
        callr_function = NULL,
        reporter = "silent"
      )
    )
  )

  testthat::expect_match(
    targets::tar_meta(
      names = "fingerprint_producer_import",
      store = path_store
    ) |>
      dplyr::pull(error),
    regexp = "data_trait_unit_rules"
  )

  testthat::expect_false(
    base::file.exists(base::file.path(dir_root, "VegVault_test.sqlite"))
  )
})
