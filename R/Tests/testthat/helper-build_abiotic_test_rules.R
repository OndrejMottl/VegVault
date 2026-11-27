# Value rules in the format of build_abiotic_value_rules(), small enough to
#   check by hand: bio1 at age 0 and at 500 to 18000 years, bio4 with an
#   excluded lower bound and bio12 at age 0, bio18 with a forbidden value,
#   and a soil code
build_abiotic_test_rules <- function() {
  res <-
    tibble::tribble(
      ~artefact_id, ~variable, ~unit, ~details, ~age_min, ~age_max,
      ~range_min, ~range_max, ~flag_min_inclusive, ~flag_max_inclusive,
      ~list_forbidden, ~list_allowed, ~flag_whole_number,
      "chelsa_neoclimate", "bio1", "C (degree Celsius)",
      "mean annual air temperature", 0, 0, -80, 45, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio4", "C/100 (hundredths of a degree Celsius)",
      "temperature seasonality", 0, 0, 0, 3000, FALSE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio12", "kg m-2 year-1",
      "annual precipitation amount", 0, 0, 0, 15000, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio18", "kg m-2 quarter-1",
      "precipitation amount of the warmest quarter", 0, 0, 0, 12000,
      TRUE, TRUE, list(6553.5), list(numeric(0)), FALSE,
      "chelsa_trace21k_palaeoclimate", "bio1", "C (degree Celsius)",
      "mean annual air temperature", 500, 18000, -80, 45, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_trace21k_palaeoclimate", "bio12", "kg m-2 year-1",
      "annual precipitation amount", 500, 18000, 0, 15000, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "hwsd_soil", "HWSD2", "Unitless", NA_character_, -Inf, Inf,
      -Inf, Inf, TRUE, TRUE, list(numeric(0)), list(as.numeric(1:32)), TRUE
    ) |>
    dplyr::mutate(
      list_forbidden = purrr::map(list_forbidden, unlist),
      list_allowed = purrr::map(list_allowed, unlist)
    )

  return(res)
}
