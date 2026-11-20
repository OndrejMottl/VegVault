#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() validates arguments", {
  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  testthat::expect_error(
    build_database_schema(con = "not a connection"),
    regexp = "con"
  )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      testthat::expect_error(
        build_database_schema(con = .x, path_schema = 1),
        regexp = "path_schema"
      )

      testthat::expect_error(
        build_database_schema(
          con = .x,
          path_schema = base::file.path(base::tempdir(), "missing.sql")
        ),
        regexp = "path_schema"
      )

      testthat::expect_error(
        build_database_schema(con = .x, sel_objects = "views"),
        regexp = "sel_objects"
      )

      testthat::expect_error(
        build_database_schema(con = .x, sel_objects = c("all", "tables")),
        regexp = "sel_objects"
      )
    }
  )

  # Nothing was created by the refused calls
  vec_objects <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT name FROM sqlite_schema",
      flag_read_only = TRUE
    ) |>
    dplyr::pull(name)

  testthat::expect_length(vec_objects, 0L)
})


#----------------------------------------------------------#
# Outputs and functionality on a small schema -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() builds tables, then indexes", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "-- A small schema; with a comment",
      "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY, x REAL);",
      "CREATE VIEW view_beta AS SELECT x FROM tbl_alpha;",
      "CREATE INDEX idx_alpha_x ON tbl_alpha (x);"
    ),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  res_tables <-
    run_with_database(
      path_database = path_database,
      fn = build_database_schema,
      path_schema = path_schema,
      sel_objects = "tables"
    )

  testthat::expect_s3_class(res_tables, "tbl_df")

  testthat::expect_named(
    res_tables,
    c("statement_id", "object_type", "object_name")
  )

  testthat::expect_equal(
    dplyr::pull(res_tables, object_name),
    c("tbl_alpha", "view_beta")
  )

  vec_objects_tables <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT name FROM sqlite_schema ORDER BY name",
      flag_read_only = TRUE
    ) |>
    dplyr::pull(name)

  testthat::expect_equal(vec_objects_tables, c("tbl_alpha", "view_beta"))

  res_indexes <-
    run_with_database(
      path_database = path_database,
      fn = build_database_schema,
      path_schema = path_schema,
      sel_objects = "indexes"
    )

  testthat::expect_equal(dplyr::pull(res_indexes, statement_id), 3L)

  testthat::expect_equal(dplyr::pull(res_indexes, object_name), "idx_alpha_x")

  run_with_database(
    path_database = base::file.path(withr::local_tempdir(), "all.sqlite"),
    fn = ~ testthat::expect_invisible(
      build_database_schema(con = .x, path_schema = path_schema)
    )
  )
})


#----------------------------------------------------------#
# Errors on a small schema -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() stops and rolls back", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY);",
      "CREATE TABLE tbl_broken (broken_id INTEGER PRIMARY KEY,);",
      "CREATE TABLE tbl_gamma (gamma_id INTEGER PRIMARY KEY);"
    ),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = build_database_schema,
      path_schema = path_schema
    ),
    regexp = "2.*tbl_broken"
  )

  vec_objects <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT name FROM sqlite_schema",
      flag_read_only = TRUE
    ) |>
    dplyr::pull(name)

  testthat::expect_length(vec_objects, 0L)
})

testthat::test_that("build_database_schema() refuses other statements", {
  path_schema <-
    withr::local_tempfile(fileext = ".sql")

  base::writeLines(
    text = c(
      "CREATE TABLE tbl_alpha (alpha_id INTEGER PRIMARY KEY);",
      "INSERT INTO tbl_alpha VALUES (1);"
    ),
    con = path_schema
  )

  path_database <-
    base::file.path(withr::local_tempdir(), "db.sqlite")

  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = build_database_schema,
      path_schema = path_schema
    ),
    regexp = "only create"
  )

  vec_objects <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT name FROM sqlite_schema",
      flag_read_only = TRUE
    ) |>
    dplyr::pull(name)

  testthat::expect_length(vec_objects, 0L)
})


#----------------------------------------------------------#
# The project schema: objects and keys -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() builds the project schema", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  res <-
    run_with_database(
      path_database = path_database,
      fn = build_database_schema
    )

  testthat::expect_equal(base::nrow(res), 65L)

  data_objects <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT type, name FROM sqlite_schema ",
        "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name"
      ),
      flag_read_only = TRUE
    )

  vec_tables_expected <-
    c(
      "AbioticData", "AbioticVariable", "AbioticVariableReference",
      "Authors", "BuildProducers", "DatasetReferences", "DatasetSample",
      "DatasetSourceTypeID", "DatasetSourceTypeReference",
      "DatasetSourcesID", "DatasetSourcesReference", "DatasetTypeID",
      "Datasets", "PositionLink", "Positions", "References",
      "SamplePosition", "SampleReference", "SampleSizeID", "SampleTaxa",
      "SampleUncertainty", "Samples", "SamplingMethodID",
      "SamplingMethodReference", "Taxa", "TaxonClassification",
      "TaxonReference", "TraitDerivation", "TraitUnitConversion", "Traits",
      "TraitsDomain", "TraitsReference", "TraitsValue", "version_control"
    )

  vec_indexes_expected <-
    c(
      "idx_abioticdata_abiotic_variable_id",
      "idx_abioticvariablereference_reference_id",
      "idx_datasetreferences_reference_id",
      "idx_datasets_coord_long_lat",
      "idx_datasets_data_source_id",
      "idx_datasets_data_source_type_id",
      "idx_datasets_dataset_id",
      "idx_datasets_dataset_type_id",
      "idx_datasets_sampling_method_id",
      "idx_datasetsample_sample_id",
      "idx_datasetsourcesreference_reference_id",
      "idx_datasetsourcetypereference_reference_id",
      "idx_samplereference_reference_id",
      "idx_samples_sample_id",
      "idx_samples_sample_size_id",
      "idx_sampletaxa_sample_id_taxon_id",
      "idx_sampletaxa_taxon_id",
      "idx_samplingmethodreference_reference_id",
      "idx_taxonclassification_taxon_family",
      "idx_taxonclassification_taxon_genus",
      "idx_taxonclassification_taxon_species",
      "idx_taxonreference_reference_id",
      "idx_traits_trait_domain_id",
      "idx_traitsdomain_trait_domain_name",
      "idx_traitsreference_reference_id",
      "idx_traitsvalue_sample_id",
      "idx_traitsvalue_taxon_id",
      "idx_traitsvalue_trait_derivation_id",
      "idx_traitsvalue_trait_id",
      "idx_traitsvalue_trait_unit_conversion_id"
    )

  testthat::expect_equal(
    data_objects |>
      dplyr::filter(type == "table") |>
      dplyr::pull(name) |>
      base::sort(method = "radix"),
    base::sort(vec_tables_expected, method = "radix")
  )

  testthat::expect_equal(
    data_objects |>
      dplyr::filter(type == "index") |>
      dplyr::pull(name),
    vec_indexes_expected
  )

  testthat::expect_equal(
    data_objects |>
      dplyr::filter(type == "view") |>
      dplyr::pull(name),
    "AbioticDataReference"
  )
})

testthat::test_that("build_database_schema() sets the project keys", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  list_keys_expected <-
    list(
      AbioticData = c("sample_id", "abiotic_variable_id"),
      AbioticVariable = "abiotic_variable_id",
      AbioticVariableReference = c("abiotic_variable_id", "reference_id"),
      Authors = "author_id",
      BuildProducers = c("version_id", "producer"),
      DatasetReferences = c("dataset_id", "reference_id"),
      DatasetSample = c("dataset_id", "sample_id"),
      DatasetSourceTypeID = "data_source_type_id",
      DatasetSourceTypeReference = c("data_source_type_id", "reference_id"),
      DatasetSourcesID = "data_source_id",
      DatasetSourcesReference = c("data_source_id", "reference_id"),
      DatasetTypeID = "dataset_type_id",
      Datasets = "dataset_id",
      PositionLink = c("position_id", "sample_ref_id"),
      Positions = "position_id",
      References = "reference_id",
      SamplePosition = "sample_id",
      SampleReference = c("sample_id", "reference_id"),
      SampleSizeID = "sample_size_id",
      SampleUncertainty = c("sample_id", "iteration"),
      Samples = "sample_id",
      SamplingMethodID = "sampling_method_id",
      SamplingMethodReference = c("sampling_method_id", "reference_id"),
      Taxa = "taxon_id",
      TaxonClassification = "taxon_id",
      TaxonReference = c("taxon_id", "reference_id"),
      TraitDerivation = "trait_derivation_id",
      TraitUnitConversion = "trait_unit_conversion_id",
      Traits = "trait_id",
      TraitsDomain = "trait_domain_id",
      TraitsReference = c("trait_id", "reference_id"),
      TraitsValue = c("dataset_id", "sample_id", "trait_id", "taxon_id"),
      version_control = "id"
    )

  vec_without_rowid_expected <-
    c(
      "AbioticData", "AbioticVariableReference", "BuildProducers",
      "DatasetReferences", "DatasetSample", "DatasetSourceTypeReference",
      "DatasetSourcesReference", "PositionLink", "SampleReference",
      "SampleUncertainty", "SamplingMethodReference", "TaxonReference",
      "TraitsReference", "TraitsValue"
    )

  data_keys <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT m.name AS table_name, p.name AS column_name, p.pk ",
        "FROM sqlite_schema AS m JOIN pragma_table_info(m.name) AS p ",
        "WHERE m.type = 'table' AND p.pk > 0 ORDER BY m.name, p.pk"
      ),
      flag_read_only = TRUE
    )

  list_keys <-
    base::split(
      x = dplyr::pull(data_keys, column_name),
      f = dplyr::pull(data_keys, table_name)
    )

  testthat::expect_equal(
    list_keys[base::sort(base::names(list_keys), method = "radix")],
    list_keys_expected[
      base::sort(base::names(list_keys_expected), method = "radix")
    ]
  )

  vec_without_rowid <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT name FROM pragma_table_list ",
        "WHERE schema = 'main' AND wr = 1 ORDER BY name"
      ),
      flag_read_only = TRUE
    ) |>
    dplyr::pull(name)

  testthat::expect_equal(
    base::sort(vec_without_rowid, method = "radix"),
    base::sort(vec_without_rowid_expected, method = "radix")
  )

  # Every foreign key refers to the single-column primary key of its parent
  data_foreign_keys <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT m.name AS table_name, f.\"table\" AS ref_table_name, ",
        "f.\"to\" AS ref_column_name ",
        "FROM sqlite_schema AS m ",
        "JOIN pragma_foreign_key_list(m.name) AS f ",
        "WHERE m.type = 'table'"
      ),
      flag_read_only = TRUE
    )

  vec_refs_to_keys <-
    purrr::map2_lgl(
      .x = dplyr::pull(data_foreign_keys, ref_table_name),
      .y = dplyr::pull(data_foreign_keys, ref_column_name),
      .f = ~ base::identical(list_keys_expected[[.x]], .y)
    )

  testthat::expect_true(base::nrow(data_foreign_keys) > 0L)

  testthat::expect_true(base::all(vec_refs_to_keys))
})


#----------------------------------------------------------#
# The project schema: constraints -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() rejects repeated keys", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  data_cases <-
    tibble::tribble(
      ~statement_first, ~statement_repeat, ~regexp,
      "INSERT INTO Samples (sample_id, sample_name) VALUES (1, 's1')",
      "INSERT INTO Samples (sample_id, sample_name) VALUES (2, 's1')",
      "UNIQUE.*Samples.sample_name",
      "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (1, 'd1')",
      "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (2, 'd1')",
      "UNIQUE.*Datasets.dataset_name",
      "INSERT INTO DatasetSample VALUES (1, 1)",
      "INSERT INTO DatasetSample VALUES (1, 1)",
      "UNIQUE.*DatasetSample",
      "INSERT INTO TraitsValue VALUES (1, 1, 1, 1, 2.5, 1, NULL)",
      "INSERT INTO TraitsValue VALUES (1, 1, 1, 1, 3.5, 1, NULL)",
      "UNIQUE.*TraitsValue",
      "INSERT INTO Positions VALUES (1, 14, 50, 0)",
      "INSERT INTO Positions VALUES (2, 14, 50, 0)",
      "UNIQUE.*Positions",
      "INSERT INTO version_control (id, version) VALUES (1, '2.0.0')",
      "INSERT INTO version_control (id, version) VALUES (2, '2.0.0')",
      "UNIQUE.*version_control.version",
      "INSERT INTO BuildProducers VALUES (1, 'splot_plots', NULL, NULL)",
      "INSERT INTO BuildProducers VALUES (1, 'splot_plots', 'v2.0.0', 'a')",
      "UNIQUE.*BuildProducers"
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      purrr::pwalk(
        .l = data_cases,
        .f = ~ {
          DBI::dbExecute(conn = con, statement = ..1)

          testthat::expect_error(
            DBI::dbExecute(conn = con, statement = ..2),
            regexp = ..3
          )
        }
      )
    }
  )
})

testthat::test_that("build_database_schema() rejects missing keys", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  data_cases <-
    tibble::tribble(
      ~statement, ~regexp,
      "INSERT INTO Samples (sample_id) VALUES (1)",
      "NOT NULL.*Samples.sample_name",
      "INSERT INTO Datasets (dataset_id) VALUES (1)",
      "NOT NULL.*Datasets.dataset_name",
      "INSERT INTO version_control (id) VALUES (1)",
      "NOT NULL.*version_control.version",
      "INSERT INTO Positions VALUES (1, 14, 50, NULL)",
      "NOT NULL.*Positions.age",
      "INSERT INTO DatasetSample VALUES (1, NULL)",
      "NOT NULL.*DatasetSample.sample_id"
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      purrr::pwalk(
        .l = data_cases,
        .f = ~ testthat::expect_error(
          DBI::dbExecute(conn = con, statement = ..1),
          regexp = ..2
        )
      )
    }
  )
})

testthat::test_that("build_database_schema() rejects values out of range", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  vec_statements <-
    c(
      stringr::str_c(
        "INSERT INTO Datasets (dataset_name, coord_long, coord_lat) ",
        "VALUES ('d1', 180.5, 50)"
      ),
      stringr::str_c(
        "INSERT INTO Datasets (dataset_name, coord_long, coord_lat) ",
        "VALUES ('d2', 14, -90.5)"
      ),
      "INSERT INTO Positions VALUES (1, -181, 50, 0)",
      "INSERT INTO Positions VALUES (2, 14, 91, 0)",
      "INSERT INTO PositionLink VALUES (1, 1, 51, 0)",
      "INSERT INTO PositionLink VALUES (1, 2, -1, 0)",
      "INSERT INTO PositionLink VALUES (1, 3, 10, 5001)",
      "INSERT INTO PositionLink VALUES (1, 4, 10, -1)",
      "INSERT INTO \"References\" (reference_detail, mandatory) VALUES ('r', 2)"
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      purrr::walk(
        .x = vec_statements,
        .f = ~ testthat::expect_error(
          DBI::dbExecute(conn = con, statement = .x),
          regexp = "CHECK constraint failed"
        )
      )
    }
  )

  # Missing coordinates stay allowed, and the limits themselves pass
  vec_accepted_statements <-
    c(
      stringr::str_c(
        "INSERT INTO Datasets (dataset_name, coord_long, coord_lat) ",
        "VALUES ('d3', NULL, NULL)"
      ),
      stringr::str_c(
        "INSERT INTO Datasets (dataset_name, coord_long, coord_lat) ",
        "VALUES ('d4', -180, 90)"
      ),
      "INSERT INTO PositionLink VALUES (1, 5, 50, 5000)",
      "INSERT INTO PositionLink VALUES (1, 6, 0, 0)",
      "INSERT INTO \"References\" (reference_detail) VALUES ('r')"
    )

  vec_accepted <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res <-
          purrr::map_int(
            .x = vec_accepted_statements,
            .f = ~ DBI::dbExecute(conn = con, statement = .x)
          )

        return(res)
      }
    )

  testthat::expect_equal(vec_accepted, base::rep(1L, 5L))
})

testthat::test_that("build_database_schema() declares foreign keys", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(conn = .x, statement = "PRAGMA foreign_keys = ON")

      DBI::dbExecute(
        conn = .x,
        statement = stringr::str_c(
          "INSERT INTO Samples (sample_id, sample_name) ",
          "VALUES (1, 's1')"
        )
      )

      testthat::expect_error(
        DBI::dbExecute(
          conn = .x,
          statement = "INSERT INTO SamplePosition VALUES (1, 999)"
        ),
        regexp = "FOREIGN KEY constraint failed"
      )
    }
  )
})


#----------------------------------------------------------#
# The project schema: links per position -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() returns links per sample", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  # Samples 1 and 2 share position 1, which links to gridpoint sample 3
  vec_inserts <-
    c(
      stringr::str_c(
        "INSERT INTO Samples (sample_id, sample_name, age) ",
        "VALUES (1, 'plot_1', 0), (2, 'plot_2', 0), (3, 'grid_1', 0)"
      ),
      "INSERT INTO Positions VALUES (1, 14, 50, 0)",
      "INSERT INTO SamplePosition VALUES (1, 1), (2, 1)",
      "INSERT INTO PositionLink VALUES (1, 3, 10, 0)"
    )

  run_with_database(
    path_database = path_database,
    fn = ~ purrr::walk(
      .x = vec_inserts,
      .f = DBI::dbExecute,
      conn = .x
    )
  )

  data_links <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT * FROM AbioticDataReference ORDER BY sample_id"
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    data_links,
    base::data.frame(
      sample_id = c(1L, 2L),
      sample_ref_id = c(3L, 3L),
      distance_in_km = c(10L, 10L),
      distance_in_years = c(0L, 0L)
    )
  )

  list_checks <-
    run_with_database(
      path_database = path_database,
      fn = ~ list(
        foreign_keys = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA foreign_key_check"
        ),
        integrity = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA integrity_check"
        )
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(base::nrow(list_checks[["foreign_keys"]]), 0L)

  testthat::expect_equal(
    dplyr::pull(list_checks[["integrity"]], 1),
    "ok"
  )
})


#----------------------------------------------------------#
# The project schema: aligned with the DBML diagram -----
#----------------------------------------------------------#

testthat::test_that("build_database_schema() matches the DBML diagram", {
  path_database <-
    base::file.path(withr::local_tempdir(), "schema.sqlite")

  run_with_database(
    path_database = path_database,
    fn = build_database_schema
  )

  list_dbml <-
    load_dbml_structure(
      path_dbml = here::here("Data", "SQL", "database_structure.dbml")
    )

  data_columns_sql <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT m.name AS table_name, p.name AS column_name, ",
        "p.type AS column_type, p.pk > 0 AS flag_primary_key, ",
        "p.\"notnull\" AS flag_not_null ",
        "FROM sqlite_schema AS m JOIN pragma_table_info(m.name) AS p ",
        "WHERE m.type = 'table'"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      flag_primary_key = base::as.logical(flag_primary_key),
      flag_not_null = base::as.logical(flag_not_null)
    ) |>
    dplyr::arrange(table_name, column_name)

  data_columns_dbml <-
    list_dbml[["columns"]] |>
    dplyr::arrange(table_name, column_name)

  testthat::expect_equal(data_columns_dbml, data_columns_sql)

  data_references_sql <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT m.name AS table_name, f.\"from\" AS column_name, ",
        "f.\"table\" AS ref_table_name, f.\"to\" AS ref_column_name ",
        "FROM sqlite_schema AS m ",
        "JOIN pragma_foreign_key_list(m.name) AS f ",
        "WHERE m.type = 'table'"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::arrange(table_name, column_name, ref_table_name)

  data_references_dbml <-
    list_dbml[["references"]] |>
    dplyr::arrange(table_name, column_name, ref_table_name)

  testthat::expect_equal(data_references_dbml, data_references_sql)
})
