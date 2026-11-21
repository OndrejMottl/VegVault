#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_import_targets() declares the stage", {
  res <-
    build_producer_import_targets(
      list_subset_filters = load_config_value(
        value = c("producers", "subset_filter")
      )
    )

  vec_names <-
    purrr::map_chr(
      .x = res,
      .f = ~ purrr::pluck(.x, "settings", "name")
    )

  vec_contract_ids <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$"
    ) |>
    stringr::str_remove("[.]yml$")

  vec_variables <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  vec_names_data <-
    c(
      "data_splot_plots", "data_bien_plots", "data_fossilpol_assembly",
      "data_fossilpol_age_uncertainty", "data_try_traits",
      "data_bien_traits", "data_hwsd_soil",
      stringr::str_c("data_chelsa_neoclimate_", vec_variables),
      stringr::str_c("data_chelsa_trace21k_palaeoclimate_", vec_variables)
    )

  vec_names_stage <-
    c(
      "check_fossilpol_relations", "data_chelsa_trace21k_coordinates",
      "vec_chelsa_trace21k_ages", "data_chelsa_neoclimate_coordinates",
      "list_producer_pins", "vec_keys_fossilpol_assembly_dataset_id"
    )

  testthat::expect_true(
    base::all(purrr::map_lgl(.x = res, .f = ~ base::inherits(.x, "tar_target")))
  )

  testthat::expect_setequal(
    vec_names,
    c(
      stringr::str_c("file_contract_", vec_contract_ids),
      stringr::str_c("data_files_", vec_contract_ids),
      stringr::str_c("data_files_chelsa_neoclimate_", vec_variables),
      stringr::str_c(
        "data_files_chelsa_trace21k_palaeoclimate_",
        vec_variables
      ),
      vec_names_data,
      vec_names_stage
    )
  )

  testthat::expect_equal(base::anyDuplicated(vec_names), 0L)
})

testthat::test_that("build_producer_import_targets() sets formats", {
  res <-
    build_producer_import_targets(
      list_subset_filters = load_config_value(
        value = c("producers", "subset_filter")
      )
    )

  list_targets <-
    rlang::set_names(
      res,
      purrr::map_chr(.x = res, .f = ~ purrr::pluck(.x, "settings", "name"))
    )

  testthat::expect_equal(
    purrr::pluck(
      list_targets, "file_contract_splot_plots", "settings", "format"
    ),
    "file"
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "data_files_splot_plots", "cue", "mode"),
    "always"
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "data_splot_plots", "settings", "format"),
    "qs"
  )

  testthat::expect_equal(
    purrr::pluck(
      list_targets, "data_chelsa_neoclimate_bio12", "settings", "format"
    ),
    "qs"
  )

  testthat::expect_equal(
    purrr::pluck(list_targets, "data_splot_plots", "cue", "mode"),
    "thorough"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_producer_import_targets() wires the inputs", {
  res <-
    build_producer_import_targets(
      list_subset_filters = load_config_value(
        value = c("producers", "subset_filter")
      )
    )

  list_targets <-
    rlang::set_names(
      res,
      purrr::map_chr(.x = res, .f = ~ purrr::pluck(.x, "settings", "name"))
    )

  testthat::expect_true(
    base::all(
      c(
        "data_files_splot_plots", "file_contract_splot_plots",
        "list_subset_box"
      ) %in%
        purrr::pluck(list_targets, "data_splot_plots", "deps")
    )
  )

  testthat::expect_true(
    base::all(
      c(
        "data_producer_manifest", "mode_producers", "dir_producer_dev_root",
        "dir_producer_cache", "url_template_release"
      ) %in%
        purrr::pluck(list_targets, "data_files_splot_plots", "deps")
    )
  )

  # Age uncertainty is cut by the datasets the assembly kept, without
  #   loading the assembly
  vec_deps_age <-
    purrr::pluck(list_targets, "data_fossilpol_age_uncertainty", "deps")

  testthat::expect_true(
    "vec_keys_fossilpol_assembly_dataset_id" %in% vec_deps_age
  )

  testthat::expect_false("data_fossilpol_assembly" %in% vec_deps_age)

  # A variable reads only its own files
  vec_deps_bio12 <-
    purrr::pluck(list_targets, "data_chelsa_neoclimate_bio12", "deps")

  testthat::expect_true(
    "data_files_chelsa_neoclimate_bio12" %in% vec_deps_bio12
  )

  testthat::expect_false("data_files_chelsa_neoclimate" %in% vec_deps_bio12)

  vec_command_bio12 <-
    purrr::pluck(
      list_targets, "data_chelsa_neoclimate_bio12", "command", "expr"
    ) |>
    base::deparse() |>
    stringr::str_flatten()

  testthat::expect_match(vec_command_bio12, "variable = \"bio12\"")

  testthat::expect_match(vec_command_bio12, "flag_margin = TRUE")

  testthat::expect_true(
    base::all(
      stringr::str_c("data_files_", c("splot_plots", "hwsd_soil")) %in%
        purrr::pluck(list_targets, "list_producer_pins", "deps")
    )
  )
})

testthat::test_that("build_producer_import_targets() runs on fixtures", {
  dir_root <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_root, "fixture"))

  vec_contract_ids <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$"
    ) |>
    stringr::str_remove("[.]yml$")

  list_fixture <-
    build_producer_manifest_fixture(
      dir_root = base::file.path(dir_root, "fixture"),
      vec_contract_ids = vec_contract_ids
    )

  path_manifest <-
    purrr::chuck(list_fixture, "path_manifest")

  dir_dev_root <-
    purrr::chuck(list_fixture, "dir_dev_root")

  url_template <-
    purrr::chuck(list_fixture, "url_template")

  dir_cache <-
    base::file.path(dir_root, "cache")

  list_subset_filters <-
    load_config_value(value = c("producers", "subset_filter"))

  # The script reads the subset rules from a file, so a test can edit them
  path_filters <-
    base::file.path(dir_root, "subset_filters.rds")

  base::saveRDS(object = list_subset_filters, file = path_filters)

  path_script <-
    base::file.path(dir_root, "_targets.R")

  path_store <-
    base::file.path(dir_root, "_targets")

  # The settings targets of the pipeline, set to the fixture
  targets::tar_helper(
    path = path_script,
    code = {
      targets::tar_option_set(memory = "transient")

      list(
        targets::tar_target(
          name = "list_subset_box",
          command = list(enabled = FALSE)
        ),
        targets::tar_target(name = "mode_producers", command = "dev"),
        targets::tar_target(
          name = "dir_producer_dev_root",
          command = !!dir_dev_root
        ),
        targets::tar_target(name = "dir_producer_cache", command = !!dir_cache),
        targets::tar_target(
          name = "url_template_release",
          command = !!url_template
        ),
        targets::tar_target(
          name = "file_producer_manifest",
          command = !!path_manifest,
          format = "file"
        ),
        targets::tar_target(
          name = "data_producer_manifest",
          command = load_producer_manifest(
            path_manifest = file_producer_manifest
          )
        ),
        build_producer_import_targets(
          list_subset_filters = base::readRDS(!!path_filters)
        )
      )
    }
  )

  withr::defer(targets::tar_option_reset())

  targets::tar_make(
    script = path_script,
    store = path_store,
    callr_function = NULL,
    reporter = "silent"
  )

  testthat::expect_false(
    "errored" %in%
      dplyr::pull(targets::tar_progress(store = path_store), progress)
  )

  testthat::expect_length(
    targets::tar_read(list_producer_pins, store = path_store),
    base::length(vec_contract_ids)
  )

  testthat::expect_equal(
    targets::tar_read(vec_chelsa_trace21k_ages, store = path_store),
    c(0, 500, 6000, 18000)
  )

  testthat::expect_equal(
    dplyr::pull(
      targets::tar_read(check_fossilpol_relations, store = path_store),
      n_datasets
    ),
    c(2L, 2L, 2L)
  )

  # A second run builds only the targets that run every time
  targets::tar_make(
    script = path_script,
    store = path_store,
    callr_function = NULL,
    reporter = "silent"
  )

  vec_built_again <-
    targets::tar_progress(store = path_store) |>
    dplyr::filter(progress == "completed") |>
    dplyr::pull(name)

  testthat::expect_setequal(
    vec_built_again,
    stringr::str_c("data_files_", vec_contract_ids)
  )

  # A new sPlot file and a new file of one CHELSA variable, pinned in the
  #   manifest, rebuild only these two and the pins
  path_splot <-
    base::list.files(
      path = dir_dev_root,
      pattern = "^data_splot_",
      recursive = TRUE,
      full.names = TRUE
    )

  path_bio12 <-
    base::list.files(
      path = dir_dev_root,
      pattern = "^CHELSA_bio_12_",
      recursive = TRUE,
      full.names = TRUE
    )

  data_splot <-
    qs2::qs_read(path_splot)

  path_splot_new <-
    base::file.path(
      base::dirname(path_splot),
      "data_splot_2000-01-02__0123456789abcdef0123456789abcdef__.qs"
    )

  path_bio12_new <-
    base::file.path(
      base::dirname(path_bio12),
      "CHELSA_bio_12_2000-01-02__0123456789abcdef0123456789abcdef__.qs"
    )

  qs2::qs_save(object = dplyr::slice(data_splot, -1L), file = path_splot_new)

  qs2::qs_save(
    object = dplyr::slice(qs2::qs_read(path_bio12), -1L),
    file = path_bio12_new
  )

  list_manifest <-
    yaml::read_yaml(file = path_manifest)

  vec_manifest_ids <-
    purrr::map_chr(
      .x = purrr::chuck(list_manifest, "artefacts"),
      .f = ~ purrr::chuck(.x, "artefact_id")
    )

  index_splot <-
    base::which(vec_manifest_ids == "splot_plots")

  index_chelsa <-
    base::which(vec_manifest_ids == "chelsa_neoclimate")

  list_pin_splot <-
    list(
      file_name = base::basename(path_splot_new),
      size = base::file.size(path_splot_new),
      sha256 = compute_file_sha256(path_file = path_splot_new)
    )

  list_pin_bio12 <-
    list(
      file_name = base::basename(path_bio12_new),
      size = base::file.size(path_bio12_new),
      sha256 = compute_file_sha256(path_file = path_bio12_new)
    )

  # The dev file names read back as a character vector
  list_manifest_new <-
    purrr::modify_in(
      .x = list_manifest,
      .where = list("artefacts", index_splot, "dev", "files"),
      .f = ~ base::basename(path_splot_new)
    ) |>
    purrr::modify_in(
      .where = list("artefacts", index_splot, "release", "files"),
      .f = ~ list(list_pin_splot)
    ) |>
    purrr::modify_in(
      .where = list("artefacts", index_chelsa, "dev", "files"),
      .f = ~ dplyr::if_else(
        .x == base::basename(path_bio12),
        base::basename(path_bio12_new),
        .x
      )
    ) |>
    purrr::modify_in(
      .where = list("artefacts", index_chelsa, "release", "files"),
      .f = ~ purrr::map(
        .x = .x,
        .f = function(list_file) {
          if (
            purrr::chuck(list_file, "file_name") == base::basename(path_bio12)
          ) {
            list_pin_bio12
          } else {
            list_file
          }
        }
      )
    )

  yaml::write_yaml(x = list_manifest_new, file = path_manifest)

  targets::tar_make(
    script = path_script,
    store = path_store,
    callr_function = NULL,
    reporter = "silent"
  )

  vec_built_changed <-
    targets::tar_progress(store = path_store) |>
    dplyr::filter(progress == "completed") |>
    dplyr::pull(name)

  vec_variables <-
    c("bio1", "bio4", "bio6", "bio12", "bio15", "bio18", "bio19")

  # The file selections of every neoclimate variable run again, but only
  #   bio12 has new files
  testthat::expect_setequal(
    base::setdiff(
      vec_built_changed,
      stringr::str_c("data_files_", vec_contract_ids)
    ),
    c(
      "file_producer_manifest", "data_producer_manifest", "data_splot_plots",
      stringr::str_c("data_files_chelsa_neoclimate_", vec_variables),
      "data_chelsa_neoclimate_bio12", "list_producer_pins"
    )
  )

  testthat::expect_equal(
    base::nrow(
      dplyr::bind_rows(targets::tar_read(data_splot_plots, store = path_store))
    ),
    base::nrow(data_splot) - 1L
  )

  # An edited subset rule rebuilds only the data of that artefact
  base::saveRDS(
    object = purrr::modify_in(
      .x = list_subset_filters,
      .where = list("hwsd_soil", "flag_margin"),
      .f = ~ !.x
    ),
    file = path_filters
  )

  targets::tar_make(
    script = path_script,
    store = path_store,
    callr_function = NULL,
    reporter = "silent"
  )

  vec_built_rule <-
    targets::tar_progress(store = path_store) |>
    dplyr::filter(progress == "completed") |>
    dplyr::pull(name)

  testthat::expect_setequal(
    base::setdiff(
      vec_built_rule,
      stringr::str_c("data_files_", vec_contract_ids)
    ),
    "data_hwsd_soil"
  )
})

testthat::test_that("build_producer_import_targets() cuts the subset", {
  dir_root <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_root, "fixture"))

  vec_contract_ids <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$"
    ) |>
    stringr::str_remove("[.]yml$")

  list_fixture <-
    build_producer_manifest_fixture(
      dir_root = base::file.path(dir_root, "fixture"),
      vec_contract_ids = vec_contract_ids
    )

  path_manifest <-
    purrr::chuck(list_fixture, "path_manifest")

  dir_dev_root <-
    purrr::chuck(list_fixture, "dir_dev_root")

  url_template <-
    purrr::chuck(list_fixture, "url_template")

  dir_cache <-
    base::file.path(dir_root, "cache")

  path_filters <-
    base::file.path(dir_root, "subset_filters.rds")

  base::saveRDS(
    object = load_config_value(value = c("producers", "subset_filter")),
    file = path_filters
  )

  # Holds the first fixture dataset of FOSSILPOL (25.12, 70.08), not the
  #   second (179.95, 65.05). Not named like the target `list_subset_box`:
  #   in this session tar_make() runs the script in the test's environment
  list_box_fixture <-
    list(
      enabled = TRUE,
      lon_min = 0,
      lon_max = 30,
      lat_min = 45,
      lat_max = 75,
      margin_lon = 1,
      margin_lat = 1
    )

  path_script <-
    base::file.path(dir_root, "_targets.R")

  path_store <-
    base::file.path(dir_root, "_targets")

  targets::tar_helper(
    path = path_script,
    code = {
      targets::tar_option_set(memory = "transient")

      list(
        targets::tar_target(
          name = "list_subset_box",
          command = !!list_box_fixture
        ),
        targets::tar_target(name = "mode_producers", command = "dev"),
        targets::tar_target(
          name = "dir_producer_dev_root",
          command = !!dir_dev_root
        ),
        targets::tar_target(name = "dir_producer_cache", command = !!dir_cache),
        targets::tar_target(
          name = "url_template_release",
          command = !!url_template
        ),
        targets::tar_target(
          name = "file_producer_manifest",
          command = !!path_manifest,
          format = "file"
        ),
        targets::tar_target(
          name = "data_producer_manifest",
          command = load_producer_manifest(
            path_manifest = file_producer_manifest
          )
        ),
        build_producer_import_targets(
          list_subset_filters = base::readRDS(!!path_filters)
        )
      )
    }
  )

  withr::defer(targets::tar_option_reset())

  targets::tar_make(
    script = path_script,
    store = path_store,
    callr_function = NULL,
    reporter = "silent"
  )

  testthat::expect_false(
    "errored" %in%
      dplyr::pull(targets::tar_progress(store = path_store), progress)
  )

  data_age <-
    targets::tar_read(data_fossilpol_age_uncertainty, store = path_store) |>
    dplyr::bind_rows()

  testthat::expect_equal(dplyr::pull(data_age, dataset_id), "90001")

  data_coordinates <-
    targets::tar_read(data_chelsa_neoclimate_coordinates, store = path_store)

  testthat::expect_true(
    base::all(dplyr::between(dplyr::pull(data_coordinates, long), -1, 31))
  )

  testthat::expect_equal(
    dplyr::pull(
      targets::tar_read(check_fossilpol_relations, store = path_store),
      n_datasets
    ),
    c(1L, 1L, 1L)
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_import_targets() checks the filters", {
  list_subset_filters <-
    load_config_value(value = c("producers", "subset_filter"))

  testthat::expect_error(
    build_producer_import_targets(
      list_subset_filters = purrr::list_modify(
        list_subset_filters,
        splot_plots = rlang::zap()
      )
    ),
    regexp = "splot_plots"
  )

  testthat::expect_error(
    build_producer_import_targets(
      list_subset_filters = purrr::list_modify(
        list_subset_filters,
        unknown_artefact = list(
          col_lon = "long",
          col_lat = "lat",
          flag_margin = FALSE
        )
      )
    ),
    regexp = "unknown_artefact"
  )

  # A reference artefact must have one data target
  testthat::expect_error(
    build_producer_import_targets(
      list_subset_filters = purrr::list_modify(
        list_subset_filters,
        fossilpol_age_uncertainty = list(
          col_key = "dataset_id",
          reference = "chelsa_neoclimate"
        )
      )
    ),
    regexp = "chelsa_neoclimate"
  )
})
