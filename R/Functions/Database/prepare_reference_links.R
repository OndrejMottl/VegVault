#' @title Prepare the rows of a reference link table
#' @description
#' Turn pairs of an entity key and a reference text into the id pairs of a
#' link table such as `SampleReference` or `TaxonReference`.
#' @param data_links
#' A data frame with the entity key columns `vec_entity_keys` and the
#' column `reference_detail`, one row per link (repeats allowed).
#' @param data_entity_ids
#' A data frame with the id column `name_entity_id` and the columns
#' `vec_entity_keys`, one row per entity.
#' @param data_reference_ids
#' A data frame with the columns `reference_id` and `reference_detail`,
#' one row per reference.
#' @param vec_entity_keys
#' Character vector. The natural-key columns of the entity.
#' @param name_entity_id
#' Character scalar. The id column of the entity, for example
#' `"sample_id"`.
#' @param name_table
#' Character scalar. Name of the link table, used in error messages.
#' @return
#' A tibble with the integer columns `name_entity_id` and `reference_id`,
#' one row per distinct pair, sorted by both.
#' @details
#' Both ids are resolved with `prepare_table_foreign_key()`, so an entity
#' or a reference without a row aborts with the name of the link table.
#' Rows with a missing reference text are not links and are dropped.
#' @seealso [build_database_tables()], [prepare_table_foreign_key()]
#' @examples
#' \dontrun{
#' data_sample_reference <-
#'   prepare_reference_links(
#'     data_links = data_sample_references,
#'     data_entity_ids = data_samples,
#'     data_reference_ids = data_references,
#'     vec_entity_keys = "sample_name",
#'     name_entity_id = "sample_id",
#'     name_table = "SampleReference"
#'   )
#' }
prepare_reference_links <- function(
  data_links,
  data_entity_ids,
  data_reference_ids,
  vec_entity_keys,
  name_entity_id,
  name_table
) {
  assertthat::assert_that(
    base::is.data.frame(data_links),
    base::all(c(vec_entity_keys, "reference_detail") %in%
      base::names(data_links)),
    msg = stringr::str_c(
      "`data_links` must hold the entity keys and `reference_detail`."
    )
  )

  assertthat::assert_that(
    base::is.data.frame(data_reference_ids),
    base::all(
      c("reference_id", "reference_detail") %in%
        base::names(data_reference_ids)
    ),
    msg = stringr::str_c(
      "`data_reference_ids` must hold `reference_id` and ",
      "`reference_detail`."
    )
  )

  data_pairs <-
    data_links |>
    dplyr::filter(!base::is.na(reference_detail)) |>
    dplyr::distinct(
      dplyr::pick(dplyr::all_of(c(vec_entity_keys, "reference_detail")))
    )

  data_with_entity <-
    prepare_table_foreign_key(
      data_child = data_pairs,
      data_parent = data_entity_ids,
      vec_key_columns = vec_entity_keys,
      name_id = name_entity_id,
      name_table = name_table
    )

  data_with_reference <-
    prepare_table_foreign_key(
      data_child = data_with_entity,
      data_parent = dplyr::select(
        data_reference_ids,
        reference_id,
        reference_detail
      ),
      vec_key_columns = "reference_detail",
      name_id = "reference_id",
      name_table = name_table
    )

  res <-
    data_with_reference |>
    dplyr::distinct(
      dplyr::pick(dplyr::all_of(c(name_entity_id, "reference_id")))
    ) |>
    dplyr::arrange(
      dplyr::pick(dplyr::all_of(c(name_entity_id, "reference_id")))
    )

  return(res)
}
