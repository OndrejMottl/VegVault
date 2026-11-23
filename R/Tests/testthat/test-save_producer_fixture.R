hash_a <- "0123456789abcdef0123456789abcdef"

list_fixture_test <-
  base::list(
    tibble::tibble(
      plot_id = c("a", "b"),
      taxa = base::list(
        tibble::tibble(taxon = "x"),
        tibble::tibble(taxon = c("y", "z"))
      )
    ),
    tibble::tibble(plot_id = "c", taxa = base::list(NULL))
  ) |>
  rlang::set_names(
    c(
      stringr::str_c("data_test_2000-01-01__", hash_a, "__.qs"),
      stringr::str_c("data_test_full_2000-01-01__", hash_a, "__.rds")
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_producer_fixture() writes every object", {
  path_dir <-
    withr::local_tempdir()

  res <-
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(
    base::basename(res),
    base::names(list_fixture_test)
  )

  testthat::expect_true(base::all(base::file.exists(res)))
})

testthat::test_that("save_producer_fixture() round-trips qs2 and rds", {
  path_dir <-
    withr::local_tempdir()

  res <-
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir
    )

  testthat::expect_identical(
    qs2::qs_read(file = res[1]),
    purrr::chuck(list_fixture_test, 1)
  )

  testthat::expect_identical(
    base::readRDS(file = res[2]),
    purrr::chuck(list_fixture_test, 2)
  )
})

testthat::test_that("save_producer_fixture() returns paths invisibly", {
  path_dir <-
    withr::local_tempdir()

  testthat::expect_invisible(
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir
    )
  )
})


testthat::test_that("save_producer_fixture() writes csv with LF line ends", {
  path_dir <-
    withr::local_tempdir()

  data_rules <-
    tibble::tibble(
      rule_key = c("rule_a", "rule_b"),
      multiplier = c(1.5, 100),
      note = c("first, quoted", NA)
    )

  res <-
    save_producer_fixture(
      list_fixture = base::list("rules.csv" = data_rules),
      dir_output = path_dir
    )

  # LF on every system, so a rebuilt fixture is byte-identical
  vec_bytes <-
    base::readBin(con = res, what = "raw", n = 10000L)

  testthat::expect_false(base::as.raw(13L) %in% vec_bytes)

  data_read <-
    utils::read.csv(file = res, na.strings = "") |>
    tibble::as_tibble()

  testthat::expect_equal(data_read, data_rules)
})

testthat::test_that("save_producer_fixture() needs flat tables for csv", {
  path_dir <-
    withr::local_tempdir()

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = base::list(
        "nested.csv" = purrr::chuck(list_fixture_test, 1)
      ),
      dir_output = path_dir
    ),
    regexp = "csv"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_producer_fixture() protects existing files", {
  path_dir <-
    withr::local_tempdir()

  save_producer_fixture(
    list_fixture = list_fixture_test,
    dir_output = path_dir
  )

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir
    ),
    regexp = "flag_overwrite"
  )

  res <-
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir,
      flag_overwrite = TRUE
    )

  testthat::expect_true(base::all(base::file.exists(res)))
})

testthat::test_that("save_producer_fixture() writes nothing on refusal", {
  path_dir <-
    withr::local_tempdir()

  path_existing <-
    base::file.path(path_dir, base::names(list_fixture_test)[2])

  base::writeLines(text = "placeholder", con = path_existing)

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = path_dir
    ),
    regexp = "flag_overwrite"
  )

  testthat::expect_false(
    base::file.exists(
      base::file.path(path_dir, base::names(list_fixture_test)[1])
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_producer_fixture() validates arguments", {
  path_dir <-
    withr::local_tempdir()

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = rlang::set_names(list_fixture_test, c("a.txt", "b.qs")),
      dir_output = path_dir
    ),
    regexp = "list_fixture"
  )

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = base::unname(list_fixture_test),
      dir_output = path_dir
    ),
    regexp = "list_fixture"
  )

  testthat::expect_error(
    save_producer_fixture(
      list_fixture = list_fixture_test,
      dir_output = base::file.path(path_dir, "missing")
    ),
    regexp = "dir_output"
  )
})
