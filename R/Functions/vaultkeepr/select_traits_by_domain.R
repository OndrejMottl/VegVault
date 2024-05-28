select_traits_by_domain <- function(con, sel_domain) {
  # test various things

  sel_data <- con$data

  sel_con <- con$db_con

  assertthat::assert_that(
    "dataset_type" %in% colnames(sel_data),
    msg = paste(
      "The dataset does not contain `dataset_type` columns. Please add",
      "`select_dataset_by_type()` to the pipe before this function."
    )
  )

  data_traits <-
    dplyr::inner_join(
      dplyr::tbl(sel_con, "TraitsDomain"),
      dplyr::tbl(sel_con, "Traits"),
      by = "trait_domain_id"
    )

  dat_res <-
    sel_data %>%
    dplyr::left_join(
      data_traits,
      by = "trait_id"
    ) %>%
    dplyr::mutate(
      keep = dplyr::case_when(
        .default = TRUE,
        !(trait_domain_name %in% sel_domain) & dataset_type == "traits" ~ FALSE
      )
    ) %>%
    dplyr::filter(
      keep == TRUE
    ) %>%
    dplyr::select(-keep)

  res <-
    structure(
      list(
        data = dat_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}
