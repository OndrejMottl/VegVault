#----------------------------------------------------------#
#
#
#                         VegVault
#
#                  Visualisation pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the visualisation stage: the ten manuscript
#   figures of v1.0.0 (formerly the scripts of
#   R/03_Visualisation/01_manuscript/), drawn from the built database.
#   Settings are in the `figures` and `graphical: manuscript`
#   sections of `config.yml`; colours in `colors.json`. The stage needs
#   the `maps` package (country outlines), internet access for the GADM
#   country border, and `vaultkeepr` for the five vaultkeepr figures.
# Run with:
#   R/Analyses/06_Visualisation/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

# Figure files are tracked with `format = "file"`; trusting time stamps
#   means a file is hashed when it is written and afterwards only when its
#   modification time changes
targets::tar_option_set(
  seed = config_seed,
  trust_timestamps = TRUE
)

# Combining plots measures them on a graphics device; without one, R would
#   open its default device and leave Rplots.pdf in the project root
base::options(device = function(...) grDevices::pdf(file = NULL, ...))


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# No store is imported. The upstream contract is the database and its
#   build manifest, which the last target of the database assembly
#   (R/Analyses/03_Database_assembly/00_run.R) writes next to the database.
#   The figures read the manifest on every run and every data target takes
#   it as an argument, so a new build redraws the figures without the
#   database itself being hashed.


#----------------------------------------------------------#
# 2. Define targets -----
#----------------------------------------------------------#

# Settings are read one value per target, each on every run: a changed
#   label or size then redraws only its figure and never extracts data
#   from the database again
list(
  #--------------------------------------------------#
  ## 2.1 Database, style and files -----
  #--------------------------------------------------#

  # Database to draw from: from `secrets.yaml`, or the disposable database
  #   of the `subset` profile. Resolved on every run, so a new path is
  #   noticed
  targets::tar_target(
    name = "path_database",
    command = resolve_database_path(),
    cue = targets::tar_cue(mode = "always")
  ),
  # Active profile, which the build manifest must record
  targets::tar_target(
    name = "profile_active",
    command = load_config_value(value = "profile"),
    cue = targets::tar_cue(mode = "always")
  ),
  # Build manifest next to the database
  targets::tar_target(
    name = "path_build_manifest",
    command = resolve_build_manifest_path(path_database = path_database)
  ),
  # Manifest content, read on every run and checked against the database
  #   file and the active profile; a new build writes a new manifest and so
  #   redraws every figure
  targets::tar_target(
    name = "list_build_manifest",
    command = load_build_manifest(
      path_manifest = path_build_manifest,
      path_database = path_database,
      profile_expected = profile_active
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Subset box, which replaces every example region in the `subset`
  #   profile
  targets::tar_target(
    name = "list_subset",
    command = load_config_value(value = "subset"),
    cue = targets::tar_cue(mode = "always")
  ),
  # Folder that receives the figures
  targets::tar_target(
    name = "dir_figures",
    command = resolve_output_dir(
      path_relative = load_config_value(value = c("figures", "output_dir")),
      section_name = "figures"
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "list_graphical_manuscript",
    command = load_config_value(value = c("graphical", "manuscript")),
    cue = targets::tar_cue(mode = "always")
  ),
  # Project colours, shared with the website
  targets::tar_target(
    name = "file_colors",
    command = here::here("colors.json"),
    format = "file"
  ),
  targets::tar_target(
    name = "list_colors",
    command = load_figure_colors(path_colors = file_colors)
  ),
  # Theme, sizes, colours and palettes of every figure
  targets::tar_target(
    name = "list_figure_style",
    command = build_figure_style(
      list_graphical = list_graphical_manuscript,
      list_colors = list_colors
    )
  ),

  #--------------------------------------------------#
  ## 2.2 Datasets per type and source type -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "data_dataset_counts",
    command = load_dataset_counts(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "fig_datasets",
    command = plot_dataset_counts(
      data_dataset_counts = data_dataset_counts,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_datasets",
    command = load_config_value(value = c("figures", "files", "datasets")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_datasets",
    command = save_manuscript_figure(
      plot = fig_datasets,
      dir_figures = dir_figures,
      list_figure_file = list_file_datasets,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.3 Sample ages of one dataset -----
  #--------------------------------------------------#

  # Holds only the dataset name, which may be NULL (not chosen yet)
  targets::tar_target(
    name = "list_settings_sample_age",
    command = load_config_value(value = c("figures", "sample_age")),
    cue = targets::tar_cue(mode = "always")
  ),
  # Stops with a message while `figures: sample_age: dataset_name` is not
  #   set in config.yml. The three sample-age targets have
  #   `error = "continue"`, so that the other figures are drawn meanwhile;
  #   on the default "stop", the plot target would end the whole run when
  #   it cannot load the errored data
  targets::tar_target(
    name = "data_sample_age_ranges",
    command = load_sample_age_ranges(
      path_database = path_database,
      dataset_name = purrr::pluck(list_settings_sample_age, "dataset_name"),
      list_build_manifest = list_build_manifest
    ),
    error = "continue"
  ),
  targets::tar_target(
    name = "fig_sample_age",
    command = plot_sample_age_ranges(
      data_sample_age_ranges = data_sample_age_ranges,
      list_figure_style = list_figure_style
    ),
    error = "continue"
  ),
  targets::tar_target(
    name = "list_file_sample_age",
    command = load_config_value(value = c("figures", "files", "sample_age")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_sample_age",
    command = save_manuscript_figure(
      plot = fig_sample_age,
      dir_figures = dir_figures,
      list_figure_file = list_file_sample_age,
      list_figure_style = list_figure_style
    ),
    format = "file",
    error = "continue"
  ),

  #--------------------------------------------------#
  ## 2.4 Vegetation plot sizes -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "data_plot_sizes",
    command = load_plot_sizes(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "fig_plot_size",
    command = plot_plot_sizes(
      data_plot_sizes = data_plot_sizes,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_plot_size",
    command = load_config_value(value = c("figures", "files", "plot_size")),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_plot_size",
    command = save_manuscript_figure(
      plot = fig_plot_size,
      dir_figures = dir_figures,
      list_figure_file = list_file_plot_size,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.5 Taxa per classification level -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "data_taxa_classification_counts",
    command = load_taxa_classification_counts(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "fig_taxa_classification",
    command = plot_taxa_classification(
      data_taxa_classification_counts = data_taxa_classification_counts,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_taxa_classification",
    command = load_config_value(
      value = c("figures", "files", "taxa_classification")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_taxa_classification",
    command = save_manuscript_figure(
      plot = fig_taxa_classification,
      dir_figures = dir_figures,
      list_figure_file = list_file_taxa_classification,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.6 Where and when vegetation is sampled -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "data_dataset_sample_ages",
    command = load_dataset_sample_ages(
      path_database = path_database,
      vec_dataset_types = c("vegetation_plot", "fossil_pollen_archive"),
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "fig_sample_coverage",
    command = plot_sample_coverage(
      data_dataset_sample_ages = data_dataset_sample_ages,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_sample_coverage",
    command = load_config_value(
      value = c("figures", "files", "sample_coverage")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_sample_coverage",
    command = save_manuscript_figure(
      plot = fig_sample_coverage,
      dir_figures = dir_figures,
      list_figure_file = list_file_sample_coverage,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.7 Gridpoints and their links in one country -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "list_region_gridpoint_example",
    command = resolve_figure_region(
      list_region = load_config_value(
        value = c("figures", "gridpoint_example", "region")
      ),
      list_subset = list_subset
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "list_overview_gridpoint_example",
    command = load_config_value(
      value = c("figures", "gridpoint_example", "overview")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_country_code_gridpoint_example",
    command = load_config_value(
      value = c("figures", "gridpoint_example", "country_code")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_abiotic_variable_gridpoint_example",
    command = load_config_value(
      value = c("figures", "gridpoint_example", "abiotic_variable_name")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Downloaded from GADM again only when the country code or this code
  #   changes
  targets::tar_target(
    name = "data_country_border",
    command = load_country_border(
      country_code = sel_country_code_gridpoint_example,
      dir_cache = base::tempdir()
    )
  ),
  targets::tar_target(
    name = "data_gridpoint_locations",
    command = load_gridpoint_locations(
      path_database = path_database,
      list_region = list_region_gridpoint_example,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "data_gridpoint_links_raw",
    command = load_gridpoint_links(
      path_database = path_database,
      list_region = list_region_gridpoint_example,
      abiotic_variable_name = sel_abiotic_variable_gridpoint_example,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "data_gridpoint_links",
    command = prepare_gridpoint_links(
      data_gridpoint_links_raw = data_gridpoint_links_raw
    )
  ),
  targets::tar_target(
    name = "fig_gridpoint_example",
    command = plot_gridpoint_example(
      data_country_border = data_country_border,
      data_gridpoint_locations = data_gridpoint_locations,
      data_gridpoint_links = data_gridpoint_links,
      list_region = list_region_gridpoint_example,
      list_overview = list_overview_gridpoint_example,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_gridpoint_example",
    command = load_config_value(
      value = c("figures", "files", "gridpoint_example")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_gridpoint_example",
    command = save_manuscript_figure(
      plot = fig_gridpoint_example,
      dir_figures = dir_figures,
      list_figure_file = list_file_gridpoint_example,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.8 vaultkeepr example: one genus over time -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "list_region_taxon_example",
    command = resolve_figure_region(
      list_region = load_config_value(
        value = c("figures", "taxon_example", "region")
      ),
      list_subset = list_subset
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_taxon_name_taxon_example",
    command = load_config_value(
      value = c("figures", "taxon_example", "taxon_name")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_age_min_taxon_example",
    command = load_config_value(
      value = c("figures", "taxon_example", "age_min")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_age_max_taxon_example",
    command = load_config_value(
      value = c("figures", "taxon_example", "age_max")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_age_bin_width_taxon_example",
    command = load_config_value(
      value = c("figures", "taxon_example", "age_bin_width")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "data_taxon_occurrences_raw",
    command = load_taxon_occurrences(
      path_database = path_database,
      list_region = list_region_taxon_example,
      age_min = sel_age_min_taxon_example,
      age_max = sel_age_max_taxon_example,
      taxon_name = sel_taxon_name_taxon_example,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "data_taxon_occurrences",
    command = prepare_taxon_occurrences(
      data_taxon_occurrences_raw = data_taxon_occurrences_raw,
      taxon_name = sel_taxon_name_taxon_example,
      age_bin_width = sel_age_bin_width_taxon_example,
      age_min = sel_age_min_taxon_example,
      age_max = sel_age_max_taxon_example
    )
  ),
  targets::tar_target(
    name = "fig_taxon_example",
    command = plot_taxon_occurrences(
      data_taxon_occurrences = data_taxon_occurrences,
      list_region = list_region_taxon_example,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_taxon_example",
    command = load_config_value(
      value = c("figures", "files", "taxon_example")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_taxon_example",
    command = save_manuscript_figure(
      plot = fig_taxon_example,
      dir_figures = dir_figures,
      list_figure_file = list_file_taxon_example,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.9 vaultkeepr example: plots with their climate -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "list_region_climate_example",
    command = resolve_figure_region(
      list_region = load_config_value(
        value = c("figures", "climate_example", "region")
      ),
      list_subset = list_subset
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_abiotic_variable_climate_example",
    command = load_config_value(
      value = c("figures", "climate_example", "abiotic_variable_name")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_abiotic_label_climate_example",
    command = load_config_value(
      value = c("figures", "climate_example", "abiotic_variable_label")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "data_plot_climate_raw",
    command = load_plot_climate(
      path_database = path_database,
      list_region = list_region_climate_example,
      abiotic_variable_name = sel_abiotic_variable_climate_example,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "data_plot_climate",
    command = prepare_plot_climate(
      data_plot_climate_raw = data_plot_climate_raw
    )
  ),
  targets::tar_target(
    name = "fig_climate_example",
    command = plot_plot_climate(
      data_plot_climate = data_plot_climate,
      list_region = list_region_climate_example,
      abiotic_variable_label = sel_abiotic_label_climate_example,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_climate_example",
    command = load_config_value(
      value = c("figures", "files", "climate_example")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_climate_example",
    command = save_manuscript_figure(
      plot = fig_climate_example,
      dir_figures = dir_figures,
      list_figure_file = list_file_climate_example,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.10 vaultkeepr example: fossil records and traits -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "list_region_trait_example",
    command = resolve_figure_region(
      list_region = load_config_value(
        value = c("figures", "trait_example", "region")
      ),
      list_subset = list_subset
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_trait_domain_trait_example",
    command = load_config_value(
      value = c("figures", "trait_example", "trait_domain_name")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_age_min_trait_example",
    command = load_config_value(
      value = c("figures", "trait_example", "age_min")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_age_max_trait_example",
    command = load_config_value(
      value = c("figures", "trait_example", "age_max")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "sel_value_label_trait_example",
    command = load_config_value(
      value = c("figures", "trait_example", "value_label")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "data_trait_example_raw",
    command = load_trait_example(
      path_database = path_database,
      list_region = list_region_trait_example,
      age_min = sel_age_min_trait_example,
      age_max = sel_age_max_trait_example,
      trait_domain_name = sel_trait_domain_trait_example,
      list_build_manifest = list_build_manifest
    )
  ),
  targets::tar_target(
    name = "data_dataset_age_ranges",
    command = summarise_dataset_age_ranges(
      data_trait_example_raw = data_trait_example_raw
    )
  ),
  targets::tar_target(
    name = "data_taxa_per_sample",
    command = summarise_taxa_per_sample(
      data_trait_example_raw = data_trait_example_raw
    )
  ),
  targets::tar_target(
    name = "data_trait_by_taxon",
    command = summarise_trait_by_taxon(
      data_trait_example_raw = data_trait_example_raw
    )
  ),
  targets::tar_target(
    name = "fig_trait_example",
    command = plot_trait_example(
      data_dataset_age_ranges = data_dataset_age_ranges,
      data_taxa_per_sample = data_taxa_per_sample,
      data_trait_by_taxon = data_trait_by_taxon,
      value_label = sel_value_label_trait_example,
      list_figure_style = list_figure_style
    )
  ),
  targets::tar_target(
    name = "list_file_trait_example",
    command = load_config_value(
      value = c("figures", "files", "trait_example")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_trait_example",
    command = save_manuscript_figure(
      plot = fig_trait_example,
      dir_figures = dir_figures,
      list_figure_file = list_file_trait_example,
      list_figure_style = list_figure_style
    ),
    format = "file"
  ),

  #--------------------------------------------------#
  ## 2.11 The three vaultkeepr examples together -----
  #--------------------------------------------------#

  targets::tar_target(
    name = "fig_vaultkeepr_examples",
    command = plot_vaultkeepr_examples(
      fig_taxon_occurrences = fig_taxon_example,
      fig_plot_climate = fig_climate_example,
      fig_trait_example = fig_trait_example
    )
  ),
  targets::tar_target(
    name = "list_file_vaultkeepr_examples",
    command = load_config_value(
      value = c("figures", "files", "vaultkeepr_examples")
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "file_fig_vaultkeepr_examples",
    command = save_manuscript_figure(
      plot = fig_vaultkeepr_examples,
      dir_figures = dir_figures,
      list_figure_file = list_file_vaultkeepr_examples,
      list_figure_style = list_figure_style
    ),
    format = "file"
  )
)
