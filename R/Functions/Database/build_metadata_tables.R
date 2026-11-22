#' @title Build the version, producer and author rows of a build
#' @description
#' Return the rows of `version_control`, `BuildProducers` and `Authors`:
#' every database version in the order of `config.yml`, with the build
#' details on the version being built, one row per producer pin, and the
#' authors.
#' @param list_versions
#' List of the version records of `database: versions` in `config.yml`,
#' each with `version`, `update_date` and `changelog`; the last is the
#' version being built.
#' @param list_authors
#' List of author records, each with `fullname`, `email` and `orcid`.
#' @param list_producer_pins
#' List of producer pins as built by `build_producer_pins()`, each with
#' `artefact_id` and `tag` (`NULL` in a development build), and optionally
#' `commit_sha`.
#' @param build_profile
#' Character scalar. The configuration profile of the build.
#' @param git_commit
#' Character scalar. The commit of the VegVault code (see
#' `load_git_commit()`).
#' @param manifest_sha256
#' Character scalar. The SHA-256 of `Data/Producers/producer_manifest.yml`
#' (see `compute_text_file_sha256()`).
#' @return
#' A named list of three tibbles with the columns of the schema:
#' \itemize{
#'   \item `version_control`: `id`, `version`, `update_date`, `changelog`,
#'     `build_profile`, `git_commit`, `manifest_sha256`;
#'   \item `BuildProducers`: `version_id`, `producer`, `tag`,
#'     `commit_sha`;
#'   \item `Authors`: `author_id`, `author_fullname`, `author_email`,
#'     `author_orcid`.
#' }
#' @details
#' Version ids follow the order of `list_versions`, so the version being
#' built has the highest id; only its row gets the build profile, the
#' commit and the manifest checksum, as the validation stage expects. Every
#' producer pin is a `BuildProducers` row of that version, sorted by
#' producer; a missing tag or commit is stored as missing. Author ids
#' follow the order of `list_authors`. Aborts when there is no version, a
#' version repeats, a record lacks a field, a producer repeats, the commit
#' is not 40 hexadecimal characters, or the checksum not 64.
#' @seealso [save_build_manifest()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_metadata <-
#'   build_metadata_tables(
#'     list_versions = load_config_value(value = c("database", "versions")),
#'     list_authors = load_config_value(value = c("build", "authors")),
#'     list_producer_pins = list_producer_pins,
#'     build_profile = profile_build,
#'     git_commit = load_git_commit(),
#'     manifest_sha256 = compute_text_file_sha256(
#'       path_file = here::here("Data", "Producers", "producer_manifest.yml")
#'     )
#'   )
#' }
build_metadata_tables <- function(
  list_versions,
  list_authors,
  list_producer_pins,
  build_profile,
  git_commit,
  manifest_sha256
) {
  assertthat::assert_that(
    base::is.list(list_versions),
    base::length(list_versions) >= 1L,
    base::all(
      purrr::map_lgl(
        .x = list_versions,
        .f = ~ base::is.list(.x) &&
          base::all(
            c("version", "update_date", "changelog") %in% base::names(.x)
          )
      )
    ),
    msg = stringr::str_c(
      "`list_versions` must be a list of one or more version records with ",
      "`version`, `update_date` and `changelog`."
    )
  )

  assertthat::assert_that(
    base::is.list(list_authors),
    base::all(
      purrr::map_lgl(
        .x = list_authors,
        .f = ~ base::is.list(.x) &&
          base::all(c("fullname", "email", "orcid") %in% base::names(.x))
      )
    ),
    msg = stringr::str_c(
      "`list_authors` must be a list of author records with `fullname`, ",
      "`email` and `orcid`."
    )
  )

  assertthat::assert_that(
    base::is.list(list_producer_pins),
    base::all(
      purrr::map_lgl(
        .x = list_producer_pins,
        .f = ~ base::is.list(.x) && "artefact_id" %in% base::names(.x)
      )
    ),
    msg = "`list_producer_pins` must be a list of pins with `artefact_id`."
  )

  assertthat::assert_that(
    base::is.character(build_profile),
    base::length(build_profile) == 1L,
    !base::is.na(build_profile),
    base::nzchar(build_profile),
    msg = "`build_profile` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(git_commit),
    base::length(git_commit) == 1L,
    stringr::str_detect(
      string = git_commit,
      pattern = "^[0-9a-f]{40}$"
    ),
    msg = "`git_commit` must be a commit hash of 40 hexadecimal characters."
  )

  assertthat::assert_that(
    base::is.character(manifest_sha256),
    base::length(manifest_sha256) == 1L,
    stringr::str_detect(
      string = manifest_sha256,
      pattern = "^[0-9a-f]{64}$"
    ),
    msg = "`manifest_sha256` must be a SHA-256 of 64 hexadecimal characters."
  )

  # Text fields of the records; a NULL field is a missing value
  data_versions <-
    tibble::tibble(
      version = purrr::map_chr(
        .x = list_versions,
        .f = ~ base::as.character(purrr::chuck(.x, "version"))
      ),
      update_date = purrr::map_chr(
        .x = list_versions,
        .f = ~ base::as.character(
          purrr::pluck(.x, "update_date", .default = NA_character_)
        )
      ),
      changelog = purrr::map_chr(
        .x = list_versions,
        .f = ~ base::as.character(
          purrr::pluck(.x, "changelog", .default = NA_character_)
        )
      )
    )

  vec_versions <-
    dplyr::pull(data_versions, version)

  vec_repeated <-
    vec_versions[base::duplicated(vec_versions)]

  if (
    base::length(vec_repeated) > 0L
  ) {
    cli::cli_abort(
      "Versions repeat in {.arg list_versions}: {.val {vec_repeated}}."
    )
  }

  n_versions <-
    base::length(list_versions)

  vec_is_built <-
    base::seq_len(n_versions) == n_versions

  data_version_control <-
    data_versions |>
    dplyr::mutate(
      id = base::seq_len(n_versions),
      build_profile = dplyr::if_else(
        vec_is_built,
        build_profile,
        NA_character_
      ),
      git_commit = dplyr::if_else(vec_is_built, git_commit, NA_character_),
      manifest_sha256 = dplyr::if_else(
        vec_is_built,
        manifest_sha256,
        NA_character_
      )
    ) |>
    dplyr::select(
      id, version, update_date, changelog, build_profile, git_commit,
      manifest_sha256
    )

  data_build_producers <-
    tibble::tibble(
      version_id = n_versions,
      producer = purrr::map_chr(
        .x = list_producer_pins,
        .f = ~ base::as.character(purrr::chuck(.x, "artefact_id"))
      ),
      tag = purrr::map_chr(
        .x = list_producer_pins,
        .f = ~ base::as.character(
          purrr::pluck(.x, "tag", .default = NA_character_)
        )
      ),
      commit_sha = purrr::map_chr(
        .x = list_producer_pins,
        .f = ~ base::as.character(
          purrr::pluck(.x, "commit_sha", .default = NA_character_)
        )
      )
    ) |>
    dplyr::arrange(producer, .locale = "C")

  vec_producers <-
    dplyr::pull(data_build_producers, producer)

  vec_producers_repeated <-
    vec_producers[base::duplicated(vec_producers)]

  if (
    base::length(vec_producers_repeated) > 0L
  ) {
    cli::cli_abort(
      "Producer pins repeat: {.val {base::unique(vec_producers_repeated)}}."
    )
  }

  data_authors <-
    tibble::tibble(
      author_id = base::seq_along(list_authors),
      author_fullname = purrr::map_chr(
        .x = list_authors,
        .f = ~ base::as.character(purrr::chuck(.x, "fullname"))
      ),
      author_email = purrr::map_chr(
        .x = list_authors,
        .f = ~ base::as.character(
          purrr::pluck(.x, "email", .default = NA_character_)
        )
      ),
      author_orcid = purrr::map_chr(
        .x = list_authors,
        .f = ~ base::as.character(
          purrr::pluck(.x, "orcid", .default = NA_character_)
        )
      )
    )

  res <-
    base::list(
      version_control = data_version_control,
      BuildProducers = data_build_producers,
      Authors = data_authors
    )

  return(res)
}
