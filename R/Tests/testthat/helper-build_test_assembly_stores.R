# Stand-in stores of the producer import and gridpoint stages, built from
#   the valid contract fixtures, for the tests of the database assembly
#   stage. The producer import store holds every public target that the
#   assembly imports: each artefact as a named list of tables, one per file
#   (the climate artefacts per variable), identity unit rules for the
#   trait values, two development pins and the profile. The gridpoint store
#   holds the positions, links and gridpoints that the gridpoint-stage
#   functions compute from the fixtures, and the profile. `list_replace`
#   replaces values of the producer import store by name, or removes one
#   with `purrr::zap()`. Each call writes the values into `dir_root` and
#   runs both stand-in pipelines, whose targets read them every run, so a
#   store built again changes only where a value changed. Returns a list
#   with `store_producer_import` and `store_gridpoints`.
build_test_assembly_stores <- function(
  dir_root,
  profile = "default",
  list_replace = base::list()
) {
  dir_fixtures <-
    here::here("Data", "Contracts", "fixtures", "valid")

  vec_artefacts <-
    c(
      "splot_plots", "bien_plots", "fossilpol_assembly",
      "fossilpol_age_uncertainty", "try_traits", "bien_traits", "hwsd_soil"
    )

  list_artefacts <-
    vec_artefacts |>
    purrr::map(
      .f = ~ base::list.files(
        path = base::file.path(dir_fixtures, .x),
        full.names = TRUE
      )
    ) |>
    purrr::map(
      .f = ~ purrr::map(.x = .x, .f = qs2::qs_read) |>
        rlang::set_names(base::basename(.x))
    ) |>
    rlang::set_names(stringr::str_c("data_", vec_artefacts))

  # Climate files by variable: `CHELSA_bio_01_...` and `bio01_batch_1_...`
  #   both give `bio1`
  data_climate_files <-
    tibble::tibble(
      artefact_id = c("chelsa_neoclimate", "chelsa_trace21k_palaeoclimate")
    ) |>
    dplyr::mutate(
      path_file = purrr::map(
        .x = artefact_id,
        .f = ~ base::list.files(
          path = base::file.path(dir_fixtures, .x),
          full.names = TRUE
        )
      )
    ) |>
    tidyr::unnest(cols = path_file) |>
    dplyr::mutate(
      file_token = stringr::str_match(
        string = base::basename(path_file),
        pattern = "bio_?([0-9]{2})_"
      )[, 2],
      name_target = stringr::str_c(
        "data_", artefact_id, "_bio", base::as.integer(file_token)
      )
    )

  vec_climate_targets <-
    data_climate_files |>
    dplyr::distinct(name_target) |>
    dplyr::pull(name_target)

  list_climate <-
    vec_climate_targets |>
    purrr::map(
      .f = ~ dplyr::filter(data_climate_files, name_target == .x) |>
        dplyr::pull(path_file)
    ) |>
    purrr::map(
      .f = ~ purrr::map(.x = .x, .f = qs2::qs_read) |>
        rlang::set_names(base::basename(.x))
    ) |>
    rlang::set_names(vec_climate_targets)

  # One identity rule per conversion key of the trait values
  data_unit_conversions <-
    c(
      purrr::chuck(list_artefacts, "data_try_traits"),
      purrr::chuck(list_artefacts, "data_bien_traits")
    ) |>
    dplyr::bind_rows() |>
    dplyr::filter(!base::is.na(conversion_rule_key)) |>
    dplyr::distinct(conversion_rule_key, trait_unit) |>
    dplyr::mutate(
      rule_version = "1",
      source_provider = "test",
      source_trait_id = "1",
      source_dataset_key = NA_character_,
      normalized_original_unit = trait_unit,
      standardized_unit = trait_unit,
      trait_dimension = "test",
      operation = "identity",
      multiplier = 1,
      evidence = "test rule"
    ) |>
    dplyr::select(-trait_unit)

  data_trait_derivations <-
    tibble::tibble(
      derivation_rule_key = base::character(0),
      rule_version = base::character(0),
      input_unit = base::character(0),
      output_unit = base::character(0),
      trait_dimension = base::character(0),
      operation = base::character(0),
      multiplier = base::double(0),
      evidence = base::character(0)
    )

  list_producer_pins <-
    c("splot_plots", "try_traits") |>
    purrr::map(
      .f = ~ base::list(
        artefact_id = .x,
        contract_version = "2.0.0",
        mode = "dev",
        tag = NULL,
        files = base::list(
          base::list(
            file_name = stringr::str_c(.x, ".qs"),
            size = 1,
            sha256 = stringr::str_dup(string = "a", times = 64L)
          )
        )
      )
    )

  list_values_producer_import <-
    c(
      base::list(
        profile_build = profile,
        check_fossilpol_relations = tibble::tibble(
          relation = "test relation",
          n_datasets = 2L
        ),
        list_producer_pins = list_producer_pins,
        data_trait_unit_rules = base::list(
          unit_conversions = data_unit_conversions,
          trait_derivations = data_trait_derivations
        )
      ),
      list_artefacts,
      list_climate
    ) |>
    purrr::list_assign(!!!list_replace)

  # The gridpoint stage on the fixtures, with the link rule of config.yml
  list_link <-
    load_config_value(value = "link")

  data_positions <-
    prepare_link_positions(
      list_positions = base::list(
        splot_plots = prepare_modern_positions(
          list_data = purrr::chuck(list_artefacts, "data_splot_plots")
        ),
        bien_plots = prepare_modern_positions(
          list_data = purrr::chuck(list_artefacts, "data_bien_plots")
        ),
        fossilpol_assembly = prepare_fossilpol_positions(
          list_data = purrr::chuck(list_artefacts, "data_fossilpol_assembly")
        ),
        try_traits = prepare_modern_positions(
          list_data = purrr::chuck(list_artefacts, "data_try_traits")
        ),
        bien_traits = prepare_modern_positions(
          list_data = purrr::chuck(list_artefacts, "data_bien_traits")
        )
      ),
      verbose = FALSE
    )

  data_cells <-
    prepare_gridpoint_cells(
      list_coordinates = base::list(
        prepare_climate_coordinates(
          list_data = purrr::chuck(
            list_climate,
            "data_chelsa_trace21k_palaeoclimate_bio1"
          )
        ),
        prepare_climate_coordinates(
          list_data = purrr::chuck(list_climate, "data_chelsa_neoclimate_bio1")
        )
      ),
      n_digits = purrr::chuck(list_link, "coordinate_digits")
    )

  vec_ages <-
    prepare_chelsa_trace21k_ages(
      list_data = purrr::chuck(
        list_climate,
        "data_chelsa_trace21k_palaeoclimate_bio1"
      )
    )

  data_position_links <-
    build_link_windows(
      data_positions = data_positions,
      distance_km = purrr::chuck(list_link, "distance_km"),
      radius_min_km = purrr::chuck(list_link, "radius_min_km"),
      margin_deg = purrr::chuck(list_link, "window_margin_deg"),
      n_chunk_size = purrr::chuck(list_link, "chunk_size")
    ) |>
    purrr::map(
      .f = ~ compute_position_links(
        data_windows = .x,
        data_cells = data_cells,
        vec_ages = vec_ages,
        distance_km = purrr::chuck(list_link, "distance_km"),
        distance_years = purrr::chuck(list_link, "distance_years"),
        age_margin_years = purrr::chuck(list_link, "age_margin_years")
      )
    ) |>
    purrr::list_rbind()

  list_values_gridpoints <-
    base::list(
      profile_build = profile,
      data_positions = data_positions,
      data_position_links = data_position_links,
      data_gridpoints = prepare_linked_gridpoints(
        data_position_links = data_position_links,
        data_cells = data_cells,
        vec_ages = vec_ages
      )
    )

  # One stand-in pipeline per stage: each target reads its value file
  list_stages <-
    base::list(
      producer_import = list_values_producer_import,
      gridpoints = list_values_gridpoints
    )

  vec_stores <-
    purrr::imap_chr(
      .x = list_stages,
      .f = ~ {
        dir_stage <- base::file.path(dir_root, .y)

        base::dir.create(
          path = base::file.path(dir_stage, "values"),
          recursive = TRUE,
          showWarnings = FALSE
        )

        vec_paths <-
          base::file.path(
            dir_stage,
            "values",
            stringr::str_c(base::names(.x), ".rds")
          )

        purrr::walk2(
          .x = .x,
          .y = vec_paths,
          .f = ~ base::saveRDS(object = .x, file = .y)
        )

        path_script <- base::file.path(dir_stage, "_targets.R")

        path_store <- base::file.path(dir_stage, "_targets")

        base::writeLines(
          text = c(
            "list(",
            stringr::str_c(
              "  targets::tar_target_raw(name = ",
              purrr::map_chr(.x = base::names(.x), .f = base::deparse),
              ", command = quote(base::readRDS(",
              purrr::map_chr(.x = vec_paths, .f = base::deparse),
              ")), cue = targets::tar_cue(mode = \"always\"))",
              collapse = ",\n"
            ),
            ")"
          ),
          con = path_script
        )

        targets::tar_make(
          script = path_script,
          store = path_store,
          callr_function = NULL,
          reporter = "silent"
        )

        path_store
      }
    )

  res <-
    base::list(
      store_producer_import = purrr::chuck(vec_stores, "producer_import"),
      store_gridpoints = purrr::chuck(vec_stores, "gridpoints")
    )

  return(res)
}
