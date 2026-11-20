#' @title Build the targets of the producer import stage
#' @description
#' Declare every target of the stage `01_Producer_import` except its
#' settings: per producer artefact its contract file, its resolved files
#' and its validated data (one data target per variable for artefacts with
#' variables), then the FOSSILPOL relation check, the grid inputs of the
#' gridpoint stage and the producer pins of the build manifest.
#' @param list_subset_filters
#' Named list, by artefact id: how each artefact is cut to the subset box,
#' as in `producers: subset_filter` of `config.yml` (see
#' `filter_producer_artefact()`).
#' @return
#' A list of `{targets}` target objects.
#' @details
#' The artefacts are the contracts in `Data/Contracts` whose status is not
#' `retired`. Each needs an entry in `list_subset_filters`, and no other
#' entry is allowed. A filter by key must name a reference artefact without
#' variables. The FOSSILPOL artefacts and the CHELSA variable `bio1` must
#' exist. The targets read six settings targets that the pipeline
#' declares: `data_producer_manifest`, `mode_producers`,
#' `dir_producer_dev_root`, `dir_producer_cache`, `url_template_release`
#' and `list_subset_box` (the box of the `subset` section).
#' Per artefact `<id>`: `file_contract_<id>` (`format = "file"`, so a
#' changed contract validates the artefact again); `data_files_<id>`
#' (`resolve_producer_artefact()`, run every time, so every checksum is
#' computed again and a changed file is never used under an old pin); and
#' `data_<id>` (`format = "qs"`, `memory = "transient"`,
#' `load_producer_import()`). An artefact with variables has instead, per
#' variable, `data_files_<id>_<variable>` (`filter_producer_files()`) and
#' `data_<id>_<variable>`, so a changed file rebuilds only its variable.
#' A filter by key reads `vec_keys_<reference>_<key column>`
#' (`prepare_producer_keys()`), not the reference artefact itself. The
#' subset filter of an artefact is written into its data target's command,
#' so a changed filter rebuilds that target only. Then
#' `check_fossilpol_relations`, `data_chelsa_trace21k_coordinates`,
#' `vec_chelsa_trace21k_ages`, `data_chelsa_neoclimate_coordinates` and
#' `list_producer_pins`.
#' @examples
#' \dontrun{
#' build_producer_import_targets(
#'   list_subset_filters = load_config_value(
#'     value = c("producers", "subset_filter")
#'   )
#' )
#' }
build_producer_import_targets <- function(list_subset_filters) {
  assertthat::assert_that(
    base::is.list(list_subset_filters),
    !base::is.null(base::names(list_subset_filters)),
    msg = "`list_subset_filters` must be a named list by artefact id."
  )

  vec_paths_contract <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$",
      full.names = TRUE
    )

  list_contracts <-
    purrr::map(
      .x = vec_paths_contract,
      .f = ~ load_producer_contract(path_contract = .x)
    ) |>
    rlang::set_names(
      stringr::str_remove(base::basename(vec_paths_contract), "[.]yml$")
    ) |>
    purrr::discard(.p = ~ purrr::chuck(.x, "status") == "retired")

  vec_artefact_ids <-
    base::names(list_contracts)

  #--------------------------------------------------#
  ## Filters, references and required artefacts -----
  #--------------------------------------------------#

  vec_ids_without_filter <-
    base::setdiff(vec_artefact_ids, base::names(list_subset_filters))

  vec_ids_unknown <-
    base::setdiff(base::names(list_subset_filters), vec_artefact_ids)

  if (
    base::length(vec_ids_without_filter) > 0L ||
      base::length(vec_ids_unknown) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.arg list_subset_filters} must have one entry per artefact.",
        "x" = "Missing: {.val {vec_ids_without_filter}}.",
        "x" = "Not an artefact: {.val {vec_ids_unknown}}."
      )
    )
  }

  list_variables <-
    purrr::map(
      .x = list_contracts,
      .f = ~ purrr::pluck(.x, "variables", "table", .default = list()) |>
        purrr::map_chr(.f = ~ purrr::chuck(.x, "variable"))
    )

  vec_ids_single <-
    vec_artefact_ids[purrr::map_int(list_variables, base::length) == 0L]

  vec_references <-
    purrr::map(
      .x = list_subset_filters,
      .f = ~ purrr::pluck(.x, "reference")
    ) |>
    base::unlist(use.names = FALSE)

  vec_references_bad <-
    base::setdiff(vec_references, vec_ids_single)

  if (
    base::length(vec_references_bad) > 0L
  ) {
    cli::cli_abort(
      "{.val {vec_references_bad}} cannot be the reference of a filter by
        key: only an artefact without variables has one data target."
    )
  }

  flag_required <-
    base::all(
      c("fossilpol_assembly", "fossilpol_age_uncertainty") %in%
        vec_ids_single
    ) &&
    "bio1" %in% purrr::pluck(list_variables, "chelsa_neoclimate") &&
    "bio1" %in% purrr::pluck(list_variables, "chelsa_trace21k_palaeoclimate")

  if (
    !flag_required
  ) {
    cli::cli_abort(
      "The stage needs the contracts {.val fossilpol_assembly},
        {.val fossilpol_age_uncertainty}, and {.val chelsa_neoclimate} and
        {.val chelsa_trace21k_palaeoclimate} with the variable
        {.val bio1}."
    )
  }

  #--------------------------------------------------#
  ## Targets per artefact -----
  #--------------------------------------------------#

  list_targets_artefacts <-
    purrr::map(
      .x = vec_artefact_ids,
      .f = ~ {
        artefact_id <- .x

        name_contract <-
          stringr::str_c("file_contract_", artefact_id)

        name_files <-
          stringr::str_c("data_files_", artefact_id)

        list_subset_filter <-
          purrr::chuck(list_subset_filters, artefact_id)

        # The keys a filter by key reads, if any
        name_keys <-
          if (
            !base::is.null(purrr::pluck(list_subset_filter, "reference"))
          ) {
            stringr::str_c(
              "vec_keys_",
              purrr::chuck(list_subset_filter, "reference"),
              "_",
              purrr::chuck(list_subset_filter, "col_key")
            )
          }

        # One data target per variable, or one for the whole artefact
        list_variables_target <-
          if (
            base::length(purrr::chuck(list_variables, artefact_id)) == 0L
          ) {
            list(NULL)
          } else {
            base::as.list(purrr::chuck(list_variables, artefact_id))
          }

        list_targets_data <-
          purrr::map(
            .x = list_variables_target,
            .f = ~ {
              variable <- .x

              # A variable reads only its own files
              name_files_variable <-
                stringr::str_c(c(name_files, variable), collapse = "_")

              list_arguments <-
                list(
                  data_files = rlang::sym(name_files_variable),
                  path_contract = rlang::sym(name_contract),
                  variable = variable,
                  list_subset = rlang::sym("list_subset_box"),
                  list_subset_filter = rlang::call2(
                    "list",
                    !!!list_subset_filter
                  ),
                  vec_keys_kept = if (
                    !base::is.null(name_keys)
                  ) {
                    rlang::sym(name_keys)
                  }
                ) |>
                purrr::compact()

              target_data <-
                targets::tar_target_raw(
                  name = stringr::str_c(
                    c("data", artefact_id, variable),
                    collapse = "_"
                  ),
                  command = rlang::call2(
                    "load_producer_import",
                    !!!list_arguments
                  ),
                  format = "qs",
                  memory = "transient"
                )

              target_files_variable <-
                if (
                  !base::is.null(variable)
                ) {
                  targets::tar_target_raw(
                    name = name_files_variable,
                    command = rlang::call2(
                      "filter_producer_files",
                      data_files = rlang::sym(name_files),
                      path_contract = rlang::sym(name_contract),
                      variable = variable
                    )
                  )
                }

              purrr::compact(list(target_files_variable, target_data))
            }
          ) |>
          purrr::list_flatten()

        c(
          list(
            targets::tar_target_raw(
              name = name_contract,
              command = rlang::call2(
                "here",
                "Data",
                "Contracts",
                stringr::str_c(artefact_id, ".yml"),
                .ns = "here"
              ),
              format = "file"
            ),
            targets::tar_target_raw(
              name = name_files,
              command = rlang::call2(
                "resolve_producer_artefact",
                data_manifest = rlang::sym("data_producer_manifest"),
                artefact_id = artefact_id,
                mode = rlang::sym("mode_producers"),
                dir_dev_root = rlang::sym("dir_producer_dev_root"),
                dir_cache = rlang::sym("dir_producer_cache"),
                url_template = rlang::sym("url_template_release")
              ),
              cue = targets::tar_cue(mode = "always")
            )
          ),
          list_targets_data
        )
      }
    ) |>
    purrr::list_flatten()

  #--------------------------------------------------#
  ## Targets across artefacts -----
  #--------------------------------------------------#

  # One key target per reference artefact and key column
  data_key_filters <-
    purrr::keep(
      .x = list_subset_filters,
      .p = ~ !base::is.null(purrr::pluck(.x, "reference"))
    ) |>
    purrr::map(
      .f = ~ tibble::tibble(
        reference = purrr::chuck(.x, "reference"),
        col_key = purrr::chuck(.x, "col_key")
      )
    ) |>
    purrr::list_rbind(
      ptype = tibble::tibble(
        reference = base::character(0),
        col_key = base::character(0)
      )
    ) |>
    dplyr::distinct()

  list_targets_keys <-
    purrr::map2(
      .x = dplyr::pull(data_key_filters, reference),
      .y = dplyr::pull(data_key_filters, col_key),
      .f = ~ targets::tar_target_raw(
        name = stringr::str_c("vec_keys_", .x, "_", .y),
        command = rlang::call2(
          "prepare_producer_keys",
          list_data = rlang::sym(stringr::str_c("data_", .x)),
          col_key = .y
        )
      )
    )

  list_targets_stage <-
    list(
      targets::tar_target(
        name = "check_fossilpol_relations",
        command = validate_fossilpol_relations(
          list_assembly = data_fossilpol_assembly,
          list_age_uncertainty = data_fossilpol_age_uncertainty
        )
      ),
      targets::tar_target(
        name = "data_chelsa_trace21k_coordinates",
        command = prepare_climate_coordinates(
          list_data = data_chelsa_trace21k_palaeoclimate_bio1
        )
      ),
      targets::tar_target(
        name = "vec_chelsa_trace21k_ages",
        command = prepare_chelsa_trace21k_ages(
          list_data = data_chelsa_trace21k_palaeoclimate_bio1
        )
      ),
      targets::tar_target(
        name = "data_chelsa_neoclimate_coordinates",
        command = prepare_climate_coordinates(
          list_data = data_chelsa_neoclimate_bio1
        )
      ),
      targets::tar_target_raw(
        name = "list_producer_pins",
        command = rlang::call2(
          "build_producer_pins",
          list_data_files = rlang::call2(
            "list",
            !!!rlang::syms(stringr::str_c("data_files_", vec_artefact_ids))
          ),
          data_manifest = rlang::sym("data_producer_manifest")
        )
      )
    )

  res <-
    c(list_targets_artefacts, list_targets_keys, list_targets_stage)

  return(res)
}
