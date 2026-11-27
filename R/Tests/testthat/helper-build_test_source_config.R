# A source entry of `build: sources` for the tests: the fixed values of a
#   source and one reference per role (the source type and the data source
#   mandatory, the others not).
build_test_source_config <- function(
  dataset_type = "test_type",
  dataset_source_type = "TestSource",
  sample_size_description = "square meters"
) {
  res <-
    base::list(
      dataset_type = dataset_type,
      dataset_source_type = dataset_source_type,
      sample_size_description = sample_size_description,
      references = base::list(
        base::list(
          role = "source_type",
          mandatory = TRUE,
          detail = stringr::str_c("Citation of ", dataset_source_type)
        ),
        base::list(
          role = "data_source",
          mandatory = TRUE,
          detail = "Data source citation"
        ),
        base::list(
          role = "sampling_method",
          mandatory = FALSE,
          detail = "Method reference"
        ),
        base::list(
          role = "taxon",
          mandatory = FALSE,
          detail = "Taxon reference"
        ),
        base::list(
          role = "trait",
          mandatory = FALSE,
          detail = "Trait reference"
        )
      )
    )

  return(res)
}
