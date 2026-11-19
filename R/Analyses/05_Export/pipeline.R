#----------------------------------------------------------#
#
#
#                         VegVault
#
#                     Export pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the export stage: every table of the built
#   database as a CSV file, the column names and types of each table as a
#   CSV file, and one Word document listing all columns. Settings are in
#   the `export` section of `config.yml`; the stage needs the sqlite3
#   command-line tool and Quarto (for its pandoc).
# Run with:
#   R/Analyses/05_Export/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

# Export files are tracked with `format = "file"`; trusting time stamps
#   means a file of many gigabytes is hashed once, when it is written, and
#   afterwards only when its modification time changes
targets::tar_option_set(
  seed = config_seed,
  trust_timestamps = TRUE
)

# `export: rewrite: true` writes every export file again on the next run;
#   otherwise {targets} writes a file only after a new build, a code
#   change, or when the file is missing or was changed
cue_export <-
  build_export_cue(
    flag_rewrite = load_config_value(value = c("export", "rewrite"))
  )


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# No store is imported. The upstream contract is the database and its
#   build manifest, which the last target of the database assembly
#   (R/Analyses/03_Database_assembly/00_run.R) writes next to the database.
#   The export reads the manifest on every run and checks that it still
#   describes the database file, so it never hashes the database itself.


#----------------------------------------------------------#
# 2. Define targets -----
#----------------------------------------------------------#

# Branching patterns are written as bare `map()`: {targets} accepts only
#   the names from tar_pattern() there, not `targets::map()`
list(
  # Database to export: from `secrets.yaml`, or the disposable database of
  #   the `subset` profile. Resolved on every run, so a new path is noticed
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
  # Folder that receives the export
  targets::tar_target(
    name = "dir_export",
    command = resolve_output_dir(
      path_relative = load_config_value(value = c("export", "output_dir")),
      section_name = "export"
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # The sqlite3 tool and the pandoc of Quarto, checked on every run so that
  #   a missing tool stops the stage before any file is written
  targets::tar_target(
    name = "path_sqlite3",
    command = resolve_sqlite3_path(),
    cue = targets::tar_cue(mode = "always")
  ),
  targets::tar_target(
    name = "dir_pandoc",
    command = resolve_pandoc_dir(),
    cue = targets::tar_cue(mode = "always")
  ),
  # Build manifest next to the database
  targets::tar_target(
    name = "path_build_manifest",
    command = resolve_build_manifest_path(path_database = path_database)
  ),
  # Manifest content, read on every run and checked against the database
  #   file and the active profile; every export file is written again when
  #   a new build writes a new manifest
  targets::tar_target(
    name = "list_build_manifest",
    command = load_build_manifest(
      path_manifest = path_build_manifest,
      path_database = path_database,
      profile_expected = profile_active
    ),
    cue = targets::tar_cue(mode = "always")
  ),
  # Tables of the database, the units of the export
  targets::tar_target(
    name = "vec_table_names",
    command = load_database_table_names(
      path_database = path_database,
      list_build_manifest = list_build_manifest
    )
  ),
  # One CSV file per table, written by sqlite3
  targets::tar_target(
    name = "file_table_csv",
    command = save_table_csv(
      path_database = path_database,
      table_name = vec_table_names,
      list_build_manifest = list_build_manifest,
      dir_export = dir_export,
      path_sqlite3 = path_sqlite3
    ),
    pattern = map(vec_table_names),
    format = "file",
    cue = cue_export
  ),
  # Column names and types of each table
  targets::tar_target(
    name = "data_column_types",
    command = load_table_column_types(
      path_database = path_database,
      table_name = vec_table_names,
      list_build_manifest = list_build_manifest
    ),
    pattern = map(vec_table_names)
  ),
  # One column-name CSV file per table
  targets::tar_target(
    name = "file_column_names_csv",
    command = save_table_column_types(
      data_column_types = data_column_types,
      dir_export = dir_export
    ),
    pattern = map(data_column_types),
    format = "file",
    cue = cue_export
  ),
  # Word document listing the columns of every table, as in the v1 export
  targets::tar_target(
    name = "file_column_names_document",
    command = render_column_names_document(
      data_column_types = data_column_types,
      dir_export = dir_export,
      dir_pandoc = dir_pandoc
    ),
    format = "file",
    cue = cue_export
  )
)
