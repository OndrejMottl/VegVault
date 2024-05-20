# Section IV: Examples of usage


## Example 1

``` r
# create the plan
plan_na_plots_picea <-
  open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  get_datasets() %>%
  # select both modern and paleo plot data
  select_dataset_by_type(
    sel_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  # limit data to North America
  select_dataset_by_geo(
    lat_lim = c(22, 60),
    long_lim = c(-135, -60)
  ) %>%
  get_samples() %>%
  get_taxa() %>%
  # Harmonise all data to a genus level
  harmonise_taxa(to = "genus") %>%
  # Extract only Picea data
  select_by_taxa(sel_taxa = c("Picea"))

# execute the plan
data_na_plots_picea <-
  extract_data(plan_na_plots_picea)
```

<img src="figures/Example%201%20-%20plot-1.png" style="width:100.0%"
data-fig-align="center" />

## Example 2

## Example 3
