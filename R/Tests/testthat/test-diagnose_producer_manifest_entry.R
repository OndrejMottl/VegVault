#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_manifest_entry() passes valid ones", {
  file_splot <-
    "data_splot_2000-01-01__000608b7c919d261ab30308e780dc9aa__.qs"

  list_pinned <-
    list(
      artefact_id = "splot_plots",
      contract_version = "1.0.0",
      note = "Pinned for a test.",
      release = list(
        tag = "v2.0.0",
        files = list(
          list(
            file_name = file_splot,
            size = 547L,
            sha256 = base::strrep("a", 64L)
          )
        )
      ),
      dev = list(files = file_splot)
    )

  testthat::expect_equal(
    diagnose_producer_manifest_entry(
      list_entry = list_pinned,
      dir_contracts = here::here("Data", "Contracts")
    ),
    base::character(0)
  )

  list_placeholder <-
    list(
      artefact_id = "splot_plots",
      contract_version = "1.0.0",
      release = list(tag = NULL, files = list()),
      dev = list(files = list())
    )

  testthat::expect_equal(
    diagnose_producer_manifest_entry(
      list_entry = list_placeholder,
      dir_contracts = here::here("Data", "Contracts")
    ),
    base::character(0)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_manifest_entry() lists problems", {
  list_entry <-
    list(
      artefact_id = "splot_plots",
      contract_version = "1.1.0",
      owner = "someone",
      release = list(
        tag = "main",
        files = list(
          list(
            file_name = "data_splot.qs",
            size = -1,
            sha256 = "abc"
          )
        )
      ),
      dev = list(files = c("other_2000-01-01__abc__.qs"))
    )

  res <-
    diagnose_producer_manifest_entry(
      list_entry = list_entry,
      dir_contracts = here::here("Data", "Contracts")
    )

  vec_expected <-
    c(
      "unknown field 'owner'.",
      "contract_version '1.1.0' differs from the contract (1.0.0).",
      "release.tag 'main' is not a release tag such as v2.0.0.",
      "release.files: 'data_splot.qs' does not match a file-name template",
      "release.files[1]: size must be a positive whole number.",
      "release.files[1]: sha256 must be 64 lower-case hexadecimal",
      "dev.files: 'other_2000-01-01__abc__.qs' does not match a file-name"
    )

  purrr::walk(
    .x = vec_expected,
    .f = ~ testthat::expect_true(
      base::any(stringr::str_detect(res, stringr::fixed(.x))),
      label = .x
    )
  )

  testthat::expect_true(
    base::all(stringr::str_starts(res, "splot_plots: "))
  )
})

testthat::test_that("diagnose_producer_manifest_entry() reports shapes", {
  file_splot <-
    "data_splot_2000-01-01__000608b7c919d261ab30308e780dc9aa__.qs"

  # Each entry breaks the shape of one part; none may crash or report NA
  list_cases <-
    list(
      list(
        release = list(tag = NULL, files = list()),
        dev = list(files = "../outside.qs"),
        expected = "dev.files: '../outside.qs' must be a plain file name."
      ),
      list(
        release = list(
          tag = "v2.0.0",
          files = list(list(size = 1L, sha256 = base::strrep("a", 64L)))
        ),
        dev = list(files = list()),
        expected = "release.files[1]: missing field 'file_name'."
      ),
      list(
        release = list(
          tag = "v2.0.0",
          files = list(
            list(
              file_name = c(file_splot, file_splot),
              size = 1L,
              sha256 = base::strrep("a", 64L)
            )
          )
        ),
        dev = list(files = list()),
        expected = "release.files[1]: file_name must be one text value."
      ),
      list(
        release = list(tag = "v2.0.0", files = list(file_splot)),
        dev = list(files = list()),
        expected = "release.files[1]: must be a map with file_name, size"
      ),
      list(
        release = list(tag = NULL, files = list()),
        dev = list(files = list(list(file_splot))),
        expected = "dev.files: must be a list of file names."
      ),
      list(
        release = list(tag = NULL, files = list()),
        dev = list(files = list(name = file_splot)),
        expected = "dev.files: must be a list of file names."
      )
    )

  purrr::walk(
    .x = list_cases,
    .f = ~ {
      res <-
        diagnose_producer_manifest_entry(
          list_entry = list(
            artefact_id = "splot_plots",
            contract_version = "1.0.0",
            release = purrr::chuck(.x, "release"),
            dev = purrr::chuck(.x, "dev")
          ),
          dir_contracts = here::here("Data", "Contracts")
        )

      testthat::expect_false(base::anyNA(res))

      testthat::expect_true(
        base::any(
          stringr::str_detect(
            res,
            stringr::fixed(purrr::chuck(.x, "expected"))
          )
        ),
        label = purrr::chuck(.x, "expected")
      )
    }
  )
})

testthat::test_that("diagnose_producer_manifest_entry() checks tag rules", {
  file_splot <-
    "data_splot_2000-01-01__000608b7c919d261ab30308e780dc9aa__.qs"

  list_file <-
    list(file_name = file_splot, size = 547L, sha256 = base::strrep("a", 64L))

  # A placeholder with files, a tag without files, and a repeated file
  list_entries <-
    list(
      list(tag = NULL, files = list(list_file)),
      list(tag = "v2.0.0", files = list()),
      list(tag = "v2.0.0", files = list(list_file, list_file))
    )

  vec_messages <-
    c("placeholder", "no files", "more than once")

  purrr::walk2(
    .x = list_entries,
    .y = vec_messages,
    .f = ~ testthat::expect_true(
      base::any(
        stringr::str_detect(
          diagnose_producer_manifest_entry(
            list_entry = list(
              artefact_id = "splot_plots",
              contract_version = "1.0.0",
              release = .x,
              dev = list(files = list())
            ),
            dir_contracts = here::here("Data", "Contracts")
          ),
          stringr::fixed(.y)
        )
      ),
      label = .y
    )
  )
})

testthat::test_that("diagnose_producer_manifest_entry() needs a contract", {
  res <-
    diagnose_producer_manifest_entry(
      list_entry = list(
        artefact_id = "unknown_artefact",
        contract_version = "1.0.0",
        release = list(tag = NULL, files = list()),
        dev = list(files = list())
      ),
      dir_contracts = here::here("Data", "Contracts")
    )

  testthat::expect_true(
    base::any(stringr::str_detect(res, "no contract"))
  )

  res_missing <-
    diagnose_producer_manifest_entry(
      list_entry = list(contract_version = "1.0.0"),
      dir_contracts = here::here("Data", "Contracts")
    )

  testthat::expect_true(
    base::any(stringr::str_detect(res_missing, "missing field 'artefact_id'"))
  )

  testthat::expect_true(
    base::all(stringr::str_starts(res_missing, "artefact: "))
  )
})
