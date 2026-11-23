#' @title Build the targets of the database assembly stage
#' @description
#' Declare the targets of `R/Analyses/03_Database_assembly/`: the settings
#' of the build, the imports from the producer import and gridpoint
#' stores, the source tables, the taxon classification in cached batches,
#' the tables of the database with their ids, the write of the database
#' and its build manifest.
#' @param store_producer_import
#' Character scalar. The store of the producer import stage.
#' @param runner_producer_import
#' Character scalar. The runner of that stage, relative to the project
#' root, named in the messages of a missing or failed upstream run.
#' @param store_gridpoints
#' Character scalar. The store of the gridpoint stage.
#' @param runner_gridpoints
#' Character scalar. The runner of that stage.
#' @return
#' A list of `{targets}` target objects.
#' @details
#' The pipeline declares five targets that depend on the machine and the
#' checkout, which these targets use: `profile_active` (the checked
#' profile), `list_subset`, `flag_git_clean`, `git_commit` and
#' `path_database`. Every other target is declared here:
#' \itemize{
#'   \item settings read from `config.yml` and the two climate contracts,
#'     one value per target and run every time, so a changed value reruns
#'     only the targets that use it;
#'   \item one fingerprint per upstream store and a check that both stores
#'     were built in the active profile (`validate_upstream_profile()`);
#'   \item one target per source of `build: sources` that imports its
#'     artefact and prepares its tables in one step, so this store never
#'     holds a copy of an artefact: `list_tables_<source>`, and for each
#'     climate variable of the contracts
#'     `list_tables_<artefact>_<variable>`;
#'   \item `list_positions`, the positions, links and gridpoints that the
#'     samples use (`prepare_position_tables()`);
#'   \item the taxon names, their batches (`prepare_taxon_batches()`, split
#'     into a list) and `data_classification`, one branch per batch; each
#'     branch depends only on the names of its batch, so a later build
#'     classifies again only the batches that gain names;
#'   \item `list_database_tables`, `list_position_tables` and
#'     `list_metadata_tables`, the rows of every table with their ids;
#'   \item `list_database_load`, which writes the database with
#'     `save_vegvault_database()` and returns the steps and row counts of
#'     the load, and `file_build_manifest`, the build manifest next to the
#'     database, which the later stages depend on.
#' }
#' The sources enter `build_database_tables()` in the order of
#' `build: sources`, each climate artefact by variable in the order of its
#' contract, so the ids follow that order. The database file is never a
#' target, so `{targets}` never hashes it. An existing database stops the
#' write, except in the `subset` profile, whose disposable database is
#' replaced. Aborts when `build: sources` does not hold exactly the sources
#' declared here.
#' @seealso [build_database_tables()], [save_vegvault_database()],
#'   [save_build_manifest()]
#' @examples
#' \dontrun{
#' build_database_assembly_targets(
#'   store_producer_import = resolve_pipeline_store_path(
#'     path_data_storage = path_data_storage,
#'     store_relative_path = "producer_import"
#'   ),
#'   runner_producer_import = "R/Analyses/01_Producer_import/00_run.R",
#'   store_gridpoints = resolve_pipeline_store_path(
#'     path_data_storage = path_data_storage,
#'     store_relative_path = "gridpoints"
#'   ),
#'   runner_gridpoints = "R/Analyses/02_Gridpoints/00_run.R"
#' )
#' }
build_database_assembly_targets <- function(
  store_producer_import,
  runner_producer_import,
  store_gridpoints,
  runner_gridpoints
) {
  purrr::iwalk(
    .x = base::list(
      store_producer_import = store_producer_import,
      runner_producer_import = runner_producer_import,
      store_gridpoints = store_gridpoints,
      runner_gridpoints = runner_gridpoints
    ),
    .f = ~ assertthat::assert_that(
      base::is.character(.x),
      base::length(.x) == 1L,
      !base::is.na(.x),
      base::nzchar(.x),
      msg = stringr::str_c("`", .y, "` must be a non-empty character scalar.")
    )
  )

  #--------------------------------------------------#
  ## Sources -----
  #--------------------------------------------------#

  vec_sources_sample <-
    c("splot", "bien_plots", "fossilpol", "try", "bien_traits")

  vec_sources_climate <-
    c("chelsa_neoclimate", "chelsa_trace21k_palaeoclimate")

  vec_sources <-
    c(
      vec_sources_sample, "gridpoints", vec_sources_climate, "hwsd_soil",
      "taxospace"
    )

  # The order of `build: sources` gives the order of the ids
  vec_sources_config <-
    load_config_value(value = c("build", "sources")) |>
    base::names()

  if (
    !base::setequal(vec_sources_config, vec_sources) ||
      base::anyDuplicated(vec_sources_config) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.field build: sources} of {.file config.yml} must hold exactly the
        sources of the database assembly.",
        "i" = "Expected: {.val {vec_sources}}.",
        "x" = "Found: {.val {vec_sources_config}}."
      )
    )
  }

  # The climate variables of each contract, in the order of the contract
  list_climate_variables <-
    vec_sources_climate |>
    purrr::map(
      .f = ~ load_abiotic_variables(
        path_contract = here::here(
          "Data",
          "Contracts",
          stringr::str_c(.x, ".yml")
        )
      ) |>
        base::names()
    ) |>
    rlang::set_names(vec_sources_climate)

  list_age_rules <-
    base::list(
      chelsa_neoclimate = "present",
      chelsa_trace21k_palaeoclimate = "time_id"
    )

  #--------------------------------------------------#
  ## Upstream calls -----
  #--------------------------------------------------#

  data_climate_targets <-
    tibble::tibble(source_id = vec_sources_climate) |>
    dplyr::mutate(
      variable = purrr::map(
        .x = source_id,
        .f = ~ purrr::chuck(list_climate_variables, .x)
      )
    ) |>
    tidyr::unnest(cols = variable) |>
    dplyr::mutate(
      name_import = stringr::str_c("data_", source_id, "_", variable),
      name_tables = stringr::str_c("list_tables_", source_id, "_", variable),
      name_source = stringr::str_c(source_id, "_", variable)
    )

  vec_targets_producer_import <-
    c(
      "profile_build", "check_fossilpol_relations", "list_producer_pins",
      "data_trait_unit_rules",
      stringr::str_c(
        "data_",
        c(
          "splot_plots", "bien_plots", "fossilpol_assembly",
          "fossilpol_age_uncertainty", "try_traits", "bien_traits",
          "hwsd_soil"
        )
      ),
      dplyr::pull(data_climate_targets, name_import)
    )

  vec_targets_gridpoints <-
    c(
      "profile_build", "data_positions", "data_position_links",
      "data_gridpoints"
    )

  # One call of load_target_store_value() per imported target
  list_load_producer_import <-
    vec_targets_producer_import |>
    purrr::map(
      .f = ~ rlang::call2(
        "load_target_store_value",
        store = store_producer_import,
        target_name = .x,
        runner = runner_producer_import
      )
    ) |>
    rlang::set_names(vec_targets_producer_import)

  list_load_gridpoints <-
    vec_targets_gridpoints |>
    purrr::map(
      .f = ~ rlang::call2(
        "load_target_store_value",
        store = store_gridpoints,
        target_name = .x,
        runner = runner_gridpoints
      )
    ) |>
    rlang::set_names(vec_targets_gridpoints)

  #--------------------------------------------------#
  ## Settings -----
  #--------------------------------------------------#

  cue_always <-
    targets::tar_cue(mode = "always")

  # One config value per target, so a changed value reruns only its users
  list_targets_source_settings <-
    vec_sources |>
    purrr::map(
      .f = ~ targets::tar_target_raw(
        name = stringr::str_c("list_source_", .x),
        command = rlang::expr(
          load_config_value(value = c("build", "sources", !!.x))
        ),
        cue = cue_always
      )
    )

  list_targets_settings <-
    base::list(
      targets::tar_target_raw(
        name = "list_general",
        command = quote(load_config_value(value = c("build", "general"))),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "list_versions",
        command = quote(load_config_value(value = c("database", "versions"))),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "list_authors",
        command = quote(load_config_value(value = c("build", "authors"))),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "n_link_coordinate_digits",
        command = quote(
          load_config_value(value = c("link", "coordinate_digits"))
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "n_taxon_batches",
        command = quote(
          load_config_value(value = c("build", "classification", "n_batches"))
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "name_check_taxon",
        command = quote(
          load_config_value(
            value = c("build", "classification", "check_taxon")
          )
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "sel_taxon_db_name",
        command = quote(
          load_config_value(value = c("build", "classification", "db_name"))
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "sel_taxon_db_class",
        command = quote(
          load_config_value(value = c("build", "classification", "db_class"))
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "flag_taxon_only_exact_match",
        command = quote(
          load_config_value(
            value = c("build", "classification", "only_exact_match")
          )
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "sel_taxon_kingdom",
        command = quote(
          load_config_value(value = c("build", "classification", "kingdom"))
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "n_build_chunk_size",
        command = quote(load_config_value(value = c("build", "chunk_size"))),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "list_pragmas_load",
        command = quote(load_config_value(value = c("build", "pragmas_load"))),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "list_pragmas_final",
        command = quote(
          load_config_value(value = c("build", "pragmas_final"))
        ),
        cue = cue_always
      ),
      # The pin manifest, whose checksum the version row records
      targets::tar_target_raw(
        name = "file_producer_manifest",
        command = quote(
          here::here(load_config_value(value = c("producers", "manifest")))
        ),
        format = "file",
        cue = cue_always
      )
    )

  # The climate contracts give the unit and details of each variable
  list_targets_contracts <-
    vec_sources_climate |>
    purrr::map(
      .f = ~ base::list(
        targets::tar_target_raw(
          name = stringr::str_c("file_contract_", .x),
          command = rlang::expr(
            here::here("Data", "Contracts", !!stringr::str_c(.x, ".yml"))
          ),
          format = "file",
          cue = cue_always
        ),
        targets::tar_target_raw(
          name = stringr::str_c("list_variables_", .x),
          command = rlang::expr(
            load_abiotic_variables(
              path_contract = !!rlang::sym(stringr::str_c("file_contract_", .x))
            )
          )
        )
      )
    ) |>
    purrr::list_flatten()

  list_targets_abiotic_references <-
    c(vec_sources_climate, "hwsd_soil") |>
    purrr::map(
      .f = ~ targets::tar_target_raw(
        name = stringr::str_c("data_references_", .x),
        command = rlang::expr(
          prepare_config_references(
            list_source = !!rlang::sym(stringr::str_c("list_source_", .x)),
            sel_role = "abiotic_variable"
          )
        )
      )
    )

  #--------------------------------------------------#
  ## Imports -----
  #--------------------------------------------------#

  # A fingerprint per upstream store invalidates its imports when an
  #   imported target changes; the profile checks stop a build on a store
  #   of another profile
  list_targets_upstream <-
    base::list(
      targets::tar_target_raw(
        name = "fingerprint_producer_import",
        command = rlang::expr(
          compute_target_store_fingerprint(
            store = !!store_producer_import,
            target_names = !!vec_targets_producer_import,
            runner = !!runner_producer_import
          )
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "fingerprint_gridpoints",
        command = rlang::expr(
          compute_target_store_fingerprint(
            store = !!store_gridpoints,
            target_names = !!vec_targets_gridpoints,
            runner = !!runner_gridpoints
          )
        ),
        cue = cue_always
      ),
      targets::tar_target_raw(
        name = "profile_producer_import",
        command = rlang::expr({
          fingerprint_producer_import

          validate_upstream_profile(
            profile_upstream = !!purrr::chuck(
              list_load_producer_import,
              "profile_build"
            ),
            profile = profile_active,
            runner = !!runner_producer_import
          )
        })
      ),
      targets::tar_target_raw(
        name = "profile_gridpoints",
        command = rlang::expr({
          fingerprint_gridpoints

          validate_upstream_profile(
            profile_upstream = !!purrr::chuck(
              list_load_gridpoints,
              "profile_build"
            ),
            profile = profile_active,
            runner = !!runner_gridpoints
          )
        })
      )
    )

  list_targets_imports <-
    c(
      "check_fossilpol_relations", "list_producer_pins",
      "data_trait_unit_rules"
    ) |>
    purrr::map(
      .f = ~ targets::tar_target_raw(
        name = .x,
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          !!purrr::chuck(list_load_producer_import, .x)
        })
      )
    )

  #--------------------------------------------------#
  ## Source tables -----
  #--------------------------------------------------#

  # Each import prepares its tables in the same step, so the store never
  #   holds a copy of an artefact
  list_targets_samples <-
    base::list(
      targets::tar_target_raw(
        name = "list_tables_splot",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_splot_tables(
            data_splot = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, "data_splot_plots")
            ),
            list_source = list_source_splot,
            verbose = FALSE
          )
        }),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "list_tables_bien_plots",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_bien_plot_tables(
            data_bien = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, "data_bien_plots")
            ),
            list_source = list_source_bien_plots,
            verbose = FALSE
          )
        }),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "list_tables_fossilpol",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import
          check_fossilpol_relations

          prepare_fossilpol_tables(
            data_assembly = dplyr::bind_rows(
              !!purrr::chuck(
                list_load_producer_import,
                "data_fossilpol_assembly"
              )
            ),
            data_age_uncertainty = dplyr::bind_rows(
              !!purrr::chuck(
                list_load_producer_import,
                "data_fossilpol_age_uncertainty"
              )
            ),
            list_source = list_source_fossilpol,
            verbose = FALSE
          )
        }),
        format = "qs"
      ),
      # The trait contracts name the column of each field
      targets::tar_target_raw(
        name = "list_tables_try",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_trait_tables(
            data_traits = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, "data_try_traits")
            ),
            list_columns = base::list(
              sample_id = "observation_id",
              data_source_desc = "dataset",
              data_source_reference = "reference_source",
              taxon_name = "acc_species_name",
              sample_references = c(
                "dataset_reference_citation",
                "record_reference"
              )
            ),
            name_prefix = "try",
            list_source = list_source_try,
            verbose = FALSE
          )
        }),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "list_tables_bien_traits",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_trait_tables(
            data_traits = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, "data_bien_traits")
            ),
            list_columns = base::list(
              sample_id = "id",
              data_source_desc = "project_pi",
              data_source_reference = "source_citation",
              taxon_name = "scrubbed_species_binomial",
              sample_references = base::character(0)
            ),
            name_prefix = "bien_traits",
            list_source = list_source_bien_traits,
            verbose = FALSE
          )
        }),
        format = "qs"
      )
    )

  list_sample_symbols <-
    rlang::syms(stringr::str_c("list_tables_", vec_sources_sample)) |>
    rlang::set_names(vec_sources_sample)

  call_sample_sources <-
    rlang::call2("list", !!!list_sample_symbols, .ns = "base")

  # The positions, links and gridpoints that the samples use
  list_targets_positions <-
    base::list(
      targets::tar_target_raw(
        name = "list_positions",
        command = rlang::expr({
          fingerprint_gridpoints
          profile_gridpoints

          prepare_position_tables(
            list_source_tables = !!call_sample_sources,
            data_positions = !!purrr::chuck(
              list_load_gridpoints,
              "data_positions"
            ),
            data_position_links = !!purrr::chuck(
              list_load_gridpoints,
              "data_position_links"
            ),
            data_gridpoints = !!purrr::chuck(
              list_load_gridpoints,
              "data_gridpoints"
            ),
            verbose = FALSE
          )
        }),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "data_gridpoint_samples",
        command = quote(purrr::chuck(list_positions, "gridpoints")),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "list_tables_gridpoints",
        command = quote(
          prepare_gridpoint_tables(
            data_gridpoints = data_gridpoint_samples,
            list_source = list_source_gridpoints,
            verbose = FALSE
          )
        ),
        format = "qs"
      )
    )

  # One target per climate variable, so the palaeoclimate values are never
  #   in memory at once and a changed variable rebuilds only its tables.
  #   Built outside dplyr verbs, which would take the `!!` themselves, and
  #   over row positions, because `..1` in a lambda makes the dependency
  #   scan of {targets} warn
  vec_climate_sources <-
    dplyr::pull(data_climate_targets, source_id)

  vec_climate_variables <-
    dplyr::pull(data_climate_targets, variable)

  vec_climate_imports <-
    dplyr::pull(data_climate_targets, name_import)

  vec_climate_tables <-
    dplyr::pull(data_climate_targets, name_tables)

  list_targets_climate <-
    purrr::map(
      .x = base::seq_along(vec_climate_tables),
      .f = ~ targets::tar_target_raw(
        name = vec_climate_tables[.x],
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_abiotic_tables(
            data_values = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, vec_climate_imports[.x])
            ),
            data_gridpoints = data_gridpoint_samples,
            list_variable = purrr::chuck(
              !!rlang::sym(
                stringr::str_c("list_variables_", vec_climate_sources[.x])
              ),
              !!vec_climate_variables[.x]
            ),
            data_references = !!rlang::sym(
              stringr::str_c("data_references_", vec_climate_sources[.x])
            ),
            sel_age_rule = !!purrr::chuck(
              list_age_rules,
              vec_climate_sources[.x]
            ),
            n_coordinate_digits = n_link_coordinate_digits,
            verbose = FALSE
          )
        }),
        format = "qs"
      )
    )

  # Soil values are present-day values, as in v1.0.0
  list_targets_soil <-
    base::list(
      targets::tar_target_raw(
        name = "list_tables_hwsd_soil",
        command = rlang::expr({
          fingerprint_producer_import
          profile_producer_import

          prepare_abiotic_tables(
            data_values = dplyr::bind_rows(
              !!purrr::chuck(list_load_producer_import, "data_hwsd_soil")
            ),
            data_gridpoints = data_gridpoint_samples,
            list_variable = purrr::chuck(list_source_hwsd_soil, "variable"),
            data_references = data_references_hwsd_soil,
            sel_age_rule = "present",
            n_coordinate_digits = n_link_coordinate_digits,
            verbose = FALSE
          )
        }),
        format = "qs"
      )
    )

  #--------------------------------------------------#
  ## Taxon classification -----
  #--------------------------------------------------#

  # The batches are a list, so each branch depends only on its own names:
  #   a new batch or a new name reruns only the branches it changes
  list_targets_classification <-
    base::list(
      targets::tar_target_raw(
        name = "vec_taxon_names",
        command = rlang::expr(
          prepare_taxon_names(
            list_source_tables = !!call_sample_sources
          )
        )
      ),
      targets::tar_target_raw(
        name = "data_taxon_batches",
        command = quote(
          prepare_taxon_batches(
            vec_taxon_names = vec_taxon_names,
            n_batches = n_taxon_batches
          ) |>
            dplyr::group_split(batch_id)
        ),
        iteration = "list"
      ),
      targets::tar_target_raw(
        name = "data_classification",
        command = quote(
          classify_taxa(
            vec_taxon_names = dplyr::pull(data_taxon_batches, taxon_name),
            name_check_taxon = name_check_taxon,
            sel_db_name = sel_taxon_db_name,
            sel_db_class = sel_taxon_db_class,
            flag_only_exact_match = flag_taxon_only_exact_match,
            sel_kingdom = sel_taxon_kingdom,
            verbose = FALSE
          )
        ),
        pattern = quote(map(data_taxon_batches))
      ),
      targets::tar_target_raw(
        name = "list_tables_taxospace",
        command = quote(
          prepare_classification_tables(
            data_classification = data_classification,
            list_source = list_source_taxospace,
            verbose = FALSE
          )
        ),
        format = "qs"
      )
    )

  #--------------------------------------------------#
  ## Tables, write and manifest -----
  #--------------------------------------------------#

  # Every source in the order of `build: sources`, each climate artefact
  #   by variable in the order of its contract
  list_source_symbols <-
    vec_sources_config |>
    purrr::map(
      .f = ~ if (
        .x %in% vec_sources_climate
      ) {
        dplyr::filter(data_climate_targets, source_id == .x) |>
          dplyr::pull(name_tables) |>
          rlang::syms() |>
          rlang::set_names(
            dplyr::filter(data_climate_targets, source_id == .x) |>
              dplyr::pull(name_source)
          )
      } else {
        base::list(rlang::sym(stringr::str_c("list_tables_", .x))) |>
          rlang::set_names(.x)
      }
    ) |>
    purrr::list_flatten(name_spec = "{inner}")

  call_all_sources <-
    rlang::call2("list", !!!list_source_symbols, .ns = "base")

  list_targets_build <-
    base::list(
      targets::tar_target_raw(
        name = "list_database_tables",
        command = rlang::expr(
          build_database_tables(
            list_source_tables = !!call_all_sources,
            data_unit_conversions = purrr::chuck(
              data_trait_unit_rules,
              "unit_conversions"
            ),
            data_trait_derivations = purrr::chuck(
              data_trait_unit_rules,
              "trait_derivations"
            ),
            data_general_references = prepare_config_references(
              list_source = list_general,
              sel_role = "general"
            )
          )
        ),
        format = "qs"
      ),
      targets::tar_target_raw(
        name = "list_position_tables",
        command = quote(
          build_position_tables(
            list_tables = list_database_tables,
            list_positions = list_positions
          )
        ),
        format = "qs"
      ),
      # The version row records the profile, the commit and the checksum
      #   of the pin manifest
      targets::tar_target_raw(
        name = "list_metadata_tables",
        command = quote(
          build_metadata_tables(
            list_versions = list_versions,
            list_authors = list_authors,
            list_producer_pins = list_producer_pins,
            build_profile = profile_active,
            git_commit = git_commit,
            manifest_sha256 = compute_text_file_sha256(
              path_file = file_producer_manifest
            )
          )
        )
      ),
      # The write: an existing database stops it, except the disposable
      #   database of the subset profile
      targets::tar_target_raw(
        name = "list_database_load",
        command = quote(
          save_vegvault_database(
            path_database = path_database,
            list_tables = c(
              list_database_tables,
              list_position_tables,
              list_metadata_tables
            ),
            list_pragmas_load = list_pragmas_load,
            list_pragmas_final = list_pragmas_final,
            n_chunk_size = n_build_chunk_size,
            flag_replace_existing = profile_active == "subset",
            verbose = TRUE
          )
        )
      ),
      # The manifest the later stages depend on, written after the database
      targets::tar_target_raw(
        name = "file_build_manifest",
        command = quote({
          list_database_load

          save_build_manifest(
            path_database = path_database,
            profile = profile_active,
            list_subset = list_subset,
            list_version = purrr::pluck(list_versions, -1L),
            list_producer_pins = list_producer_pins,
            git_commit = git_commit,
            flag_git_clean = flag_git_clean
          )
        }),
        format = "file"
      )
    )

  res <-
    c(
      list_targets_source_settings,
      list_targets_settings,
      list_targets_contracts,
      list_targets_abiotic_references,
      list_targets_upstream,
      list_targets_imports,
      list_targets_samples,
      list_targets_positions,
      list_targets_climate,
      list_targets_soil,
      list_targets_classification,
      list_targets_build
    )

  return(res)
}
