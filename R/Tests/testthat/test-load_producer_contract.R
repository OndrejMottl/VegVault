list_contract_base <-
  base::list(
    contract_id = "test_plots",
    contract_version = "1.0.0",
    status = "active",
    title = "Test plots",
    producer = base::list(
      repository = "OndrejMottl/VegVault-Vegetation_data",
      directory = "Outputs/Data"
    ),
    consumers = "R/02_Main_analyses/01_Import_splot_data.R",
    file = base::list(
      name_templates = "data_test_{date}__{hash}__.qs"
    ),
    partitioning = base::list(scheme = "none"),
    columns = base::list(
      base::list(
        name = "plot_id",
        class = "numeric",
        nullable = FALSE,
        description = "Plot identifier.",
        evidence = "test"
      ),
      base::list(
        name = "longitude",
        class = "numeric",
        nullable = FALSE,
        unit = "decimal degree",
        description = "Longitude.",
        evidence = "test",
        checks = base::list(range = base::list(min = -180, max = 180))
      )
    ),
    keys = base::list("plot_id")
  )

list_contract_climate <-
  base::list(
    contract_id = "test_climate",
    contract_version = "2.1.0",
    status = "conditional",
    status_note = "Kept only while the source is in use.",
    title = "Test climate",
    producer = base::list(
      repository = "OndrejMottl/VegVault-abiotic_data",
      directory = "Outputs/Data/Palaoclimate"
    ),
    consumers = c("a.R", "b.R"),
    file = base::list(
      name_templates = "bio{variable}_batch_{partition}_{date}__{hash}__.qs"
    ),
    partitioning = base::list(scheme = "integer", first = 1L),
    columns = base::list(
      base::list(
        name = "long",
        class = "numeric",
        nullable = FALSE,
        description = "Longitude.",
        evidence = "test"
      ),
      base::list(
        name = "value",
        class = "numeric",
        nullable = FALSE,
        description = "Value.",
        evidence = "test"
      )
    ),
    keys = base::list("long"),
    dependencies = base::list(
      base::list(determinant = "long", dependent = "value")
    ),
    variables = base::list(
      value_column = "value",
      table = base::list(
        base::list(
          variable = "bio1",
          file_token = "01",
          unit = "C (degree Celsius)",
          description = "Mean annual air temperature.",
          evidence = "test",
          checks = base::list(range = base::list(min = -90, max = 60))
        ),
        base::list(
          variable = "bio12",
          file_token = "12",
          unit = "kg m-2 year-1",
          description = "Annual precipitation.",
          evidence = "test"
        )
      )
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_contract() returns the contract", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(x = list_contract_base, file = path_contract)

  res <-
    load_producer_contract(path_contract = path_contract)

  testthat::expect_type(res, "list")

  testthat::expect_equal(purrr::chuck(res, "contract_id"), "test_plots")

  testthat::expect_equal(purrr::chuck(res, "extra_columns"), "allow")

  testthat::expect_null(purrr::pluck(res, "variables"))

  testthat::expect_equal(purrr::chuck(res, "dependencies"), base::list())

  testthat::expect_equal(purrr::chuck(res, "relations"), base::list())

  testthat::expect_true(
    purrr::chuck(res, "partitioning", "contiguous")
  )

  vec_patterns <-
    purrr::chuck(res, "file", "name_patterns")

  testthat::expect_length(vec_patterns, 1L)

  testthat::expect_true(
    stringr::str_detect(
      "data_test_2000-01-01__0123456789abcdef0123456789abcdef__.qs",
      vec_patterns
    )
  )
})

testthat::test_that("load_producer_contract() compiles variable templates", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_climate.yml")

  yaml::write_yaml(x = list_contract_climate, file = path_contract)

  res <-
    load_producer_contract(path_contract = path_contract)

  vec_patterns <-
    purrr::chuck(res, "file", "name_patterns")

  testthat::expect_true(
    stringr::str_detect(
      "bio12_batch_2_2000-01-01__0123456789abcdef0123456789abcdef__.qs",
      vec_patterns
    )
  )

  testthat::expect_false(
    stringr::str_detect(
      "bio04_batch_2_2000-01-01__0123456789abcdef0123456789abcdef__.qs",
      vec_patterns
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_producer_contract() needs id equal to file name", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "other_name.yml")

  yaml::write_yaml(x = list_contract_base, file = path_contract)

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "contract_id"
  )
})

testthat::test_that("load_producer_contract() names missing fields", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, consumers = rlang::zap()),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "consumers"
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "test_plots.yml"
  )
})

testthat::test_that("load_producer_contract() rejects unknown fields", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, colums = "x"),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "colums"
  )
})

testthat::test_that("load_producer_contract() checks status and version", {
  path_dir <-
    withr::local_tempdir()

  path_status <-
    base::file.path(path_dir, "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, status = "draft"),
    file = path_status
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_status),
    regexp = "status"
  )

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, status = "retired"),
    file = path_status
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_status),
    regexp = "status_note"
  )

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, contract_version = "1.0"),
    file = path_status
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_status),
    regexp = "contract_version"
  )
})

testthat::test_that("load_producer_contract() reports column problems", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_base,
      where = base::list("columns", 2, "class"),
      value = "numerik"
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "numerik"
  )
})

testthat::test_that("load_producer_contract() checks keys and dependencies", {
  path_dir <-
    withr::local_tempdir()

  path_keys <-
    base::file.path(path_dir, "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_base,
      keys = base::list(c("plot_id", "plot_name"))
    ),
    file = path_keys
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_keys),
    regexp = "plot_name"
  )

  path_dependencies <-
    base::file.path(path_dir, "test_climate.yml")

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_climate,
      dependencies = base::list(
        base::list(determinant = "long", dependent = "unit")
      )
    ),
    file = path_dependencies
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_dependencies),
    regexp = "unit"
  )
})

testthat::test_that("load_producer_contract() checks partitioning", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_climate.yml")

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = "partitioning",
      value = base::list(scheme = "integer")
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "first"
  )

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = "partitioning",
      value = base::list(scheme = "none")
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "partition"
  )
})

testthat::test_that("load_producer_contract() checks the variables table", {
  path_dir <-
    withr::local_tempdir()

  path_contract <-
    base::file.path(path_dir, "test_climate.yml")

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = c("variables", "value_column"),
      value = "val"
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "value_column"
  )

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = base::list("variables", "table", 2, "file_token"),
      value = "01"
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "file_token"
  )

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = base::list("variables", "table", 1, "unit"),
      value = rlang::zap()
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "unit"
  )
})

testthat::test_that("load_producer_contract() reports all problems at once", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_base,
      status = "draft",
      colums = "x"
    ),
    file = path_contract
  )

  res_error <-
    testthat::expect_error(
      load_producer_contract(path_contract = path_contract)
    )

  text_error <-
    base::conditionMessage(res_error)

  testthat::expect_match(text_error, "status")

  testthat::expect_match(text_error, "colums")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_contract() validates the path", {
  testthat::expect_error(
    load_producer_contract(path_contract = "no_such_contract.yml"),
    regexp = "path_contract"
  )

  path_text <-
    base::file.path(withr::local_tempdir(), "test_plots.txt")

  base::writeLines(text = "contract_id: test_plots", con = path_text)

  testthat::expect_error(
    load_producer_contract(path_contract = path_text),
    regexp = "path_contract"
  )
})


#----------------------------------------------------------#
# Shipped contracts -----
#----------------------------------------------------------#

testthat::test_that("load_producer_contract() loads every shipped contract", {
  vec_paths <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$",
      full.names = TRUE
    )

  testthat::expect_gt(base::length(vec_paths), 0L)

  purrr::walk(
    .x = vec_paths,
    .f = ~ testthat::expect_no_error(
      load_producer_contract(path_contract = .x)
    )
  )
})


#----------------------------------------------------------#
# Row minimum, rounded keys and partition count -----
#----------------------------------------------------------#

testthat::test_that("load_producer_contract() fills min_rows, rounded_keys", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(x = list_contract_base, file = path_contract)

  res <-
    load_producer_contract(path_contract = path_contract)

  testthat::expect_equal(purrr::chuck(res, "min_rows"), 1L)

  testthat::expect_equal(purrr::chuck(res, "rounded_keys"), base::list())
})

testthat::test_that("load_producer_contract() checks min_rows, rounded_keys", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_plots.yml")

  yaml::write_yaml(
    x = purrr::list_modify(list_contract_base, min_rows = -1),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "min_rows"
  )

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_base,
      rounded_keys = base::list(
        base::list(columns = c("longitude", "elevation"), digits = 2L)
      )
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "elevation"
  )

  yaml::write_yaml(
    x = purrr::list_modify(
      list_contract_base,
      rounded_keys = base::list(
        base::list(columns = "longitude", digits = 1.5)
      )
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "digits"
  )
})

testthat::test_that("load_producer_contract() checks the partition count", {
  path_contract <-
    base::file.path(withr::local_tempdir(), "test_climate.yml")

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = c("partitioning", "count"),
      value = 0L
    ),
    file = path_contract
  )

  testthat::expect_error(
    load_producer_contract(path_contract = path_contract),
    regexp = "count"
  )

  yaml::write_yaml(
    x = purrr::assign_in(
      list_contract_climate,
      where = c("partitioning", "count"),
      value = 3L
    ),
    file = path_contract
  )

  res <-
    load_producer_contract(path_contract = path_contract)

  testthat::expect_equal(purrr::chuck(res, "partitioning", "count"), 3L)
})
