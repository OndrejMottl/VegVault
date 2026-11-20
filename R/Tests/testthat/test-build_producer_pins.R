#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_pins() records every artefact", {
  data_files_splot <-
    tibble::tibble(
      artefact_id = "splot_plots",
      mode = "release",
      tag = "v2.0.0",
      file_name = "data_splot.qs",
      path = "cache/data_splot.qs",
      size = 10,
      sha256 = base::strrep("a", 64L),
      format = "qs2"
    )

  data_files_bien <-
    tibble::tibble(
      artefact_id = "bien_traits",
      mode = "dev",
      tag = NA_character_,
      file_name = c("data_traits_bien_0.qs", "data_traits_bien_1.qs"),
      path = c("dev/data_traits_bien_0.qs", "dev/data_traits_bien_1.qs"),
      size = c(1, 2),
      sha256 = c(base::strrep("b", 64L), base::strrep("c", 64L)),
      format = "qs2"
    )

  data_manifest <-
    tibble::tibble(
      artefact_id = c("bien_traits", "splot_plots"),
      contract_version = c("1.0.0", "1.1.0")
    )

  res <-
    build_producer_pins(
      list_data_files = list(data_files_splot, data_files_bien),
      data_manifest = data_manifest
    )

  testthat::expect_type(res, "list")

  testthat::expect_length(res, 2L)

  testthat::expect_equal(
    purrr::chuck(res, 1L),
    list(
      artefact_id = "splot_plots",
      contract_version = "1.1.0",
      mode = "release",
      tag = "v2.0.0",
      files = list(
        list(
          file_name = "data_splot.qs",
          size = 10,
          sha256 = base::strrep("a", 64L)
        )
      )
    )
  )

  testthat::expect_named(
    purrr::chuck(res, 2L),
    c("artefact_id", "contract_version", "mode", "tag", "files")
  )

  # The field exists (checked above) and holds NULL
  testthat::expect_null(purrr::pluck(res, 2L, "tag"))

  testthat::expect_length(purrr::chuck(res, 2L, "files"), 2L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_producer_pins() writes no paths", {
  data_files <-
    tibble::tibble(
      artefact_id = "bien_traits",
      mode = "dev",
      tag = NA_character_,
      file_name = "data_traits_bien_0.qs",
      path = "private/folder/data_traits_bien_0.qs",
      size = 1,
      sha256 = base::strrep("b", 64L),
      format = "qs2"
    )

  res <-
    build_producer_pins(
      list_data_files = list(data_files),
      data_manifest = tibble::tibble(
        artefact_id = "bien_traits",
        contract_version = "1.0.0"
      )
    )

  vec_yaml <-
    yaml::as.yaml(res)

  testthat::expect_no_match(vec_yaml, "private")

  # A dev pin has no tag, written as YAML null
  testthat::expect_match(vec_yaml, "tag: ~")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_pins() validates its input", {
  data_files <-
    tibble::tibble(
      artefact_id = "splot_plots",
      mode = "dev",
      tag = NA_character_,
      file_name = "data_splot.qs",
      path = "dev/data_splot.qs",
      size = 10,
      sha256 = base::strrep("a", 64L),
      format = "qs2"
    )

  data_manifest <-
    tibble::tibble(artefact_id = "splot_plots", contract_version = "1.0.0")

  testthat::expect_error(
    build_producer_pins(
      list_data_files = list(data_files, data_files),
      data_manifest = data_manifest
    ),
    regexp = "more\\s+than\\s+once"
  )

  testthat::expect_error(
    build_producer_pins(
      list_data_files = list(
        dplyr::bind_rows(
          data_files,
          dplyr::mutate(data_files, artefact_id = "bien_plots")
        )
      ),
      data_manifest = data_manifest
    ),
    regexp = "one\\s+artefact"
  )

  testthat::expect_error(
    build_producer_pins(
      list_data_files = list(dplyr::slice(data_files, 0L)),
      data_manifest = data_manifest
    ),
    regexp = "one\\s+artefact"
  )

  testthat::expect_error(
    build_producer_pins(
      list_data_files = list(
        dplyr::mutate(data_files, artefact_id = "bien_plots")
      ),
      data_manifest = data_manifest
    ),
    regexp = "bien_plots"
  )

  testthat::expect_error(
    build_producer_pins(
      list_data_files = list(dplyr::select(data_files, -sha256)),
      data_manifest = data_manifest
    ),
    regexp = "sha256"
  )
})
