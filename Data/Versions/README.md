# Numbers of each VegVault release

The changelog page of the website (`website/database_changelog.qmd`) gives each release its own section, and that section compares the release with the one before it. The website always reads the newest release database, so the numbers of an older release cannot come from it. They are saved here once, in one folder per release, and the changelog reads them from these files. A file of a published release is never changed afterwards.

The counts of VegVault 1.0.0 are not here: they are the reference counts of the validation stage, `Data/Validation/v1.0.0_reference_counts.csv`, read from the v1.0.0 database by `R/Validation/build_v1_reference_counts.R`.

## `<version>/database_counts.csv`

The counts of the release database, written by `Rscript R/Website/save_version_counts.R` from the database of `database_path` in `secrets.yaml`, opened read-only, once the release build is accepted. One row per count, with the columns:

- `version`: the database version, as in `database: versions` of `config.yml`;
- `metric` and `scope`: what is counted. The metrics of `compute_database_counts()` (`table_rows` per table, `datasets`, `samples`, `positions`, `sample_taxa_rows` and `traits_value_rows` per dataset type and source, `abiotic_values` per variable, `sample_links` of `all`) use the scopes of the v1.0.0 reference counts. The summary statistics of `load_database_statistics()` (`n_tables`, `n_views`, `n_columns`, `size_bytes`, `n_taxa_unclassified`, ...) have the scope `database`;
- `n`: the count.

## `2.0.0/vaultkeepr_query_times.csv`

Query times of the nine example workflows of the vaultkeepr articles, measured on 2026-11-26 on the build computer (24 cores, 64 GB RAM) with no other R job running: vaultkeepr 0.1.0 on VegVault 1.0.0 (six workflows), and vaultkeepr 0.2.0 (commit `4a65799`) on 1.0.0 and on 2.0.0. Each workflow ran five times, taking turns with the others, from opening the database to the extracted table. The method was decided on 2026-11-25 (decision record of VegVault issue 86) and the result is reported on VegVault issue 84. vaultkeepr 0.1.0 did not run the two trait workflows and "Taxa of all samples, Czechia": its geographic window does not apply to trait datasets (changed in vaultkeepr 0.2.0), so their results cannot be compared. Columns:

- `workflow` and `description`: the workflow;
- `database_version` and `vaultkeepr_version`: what was timed;
- `n_runs` and `n_errors`: the runs and the runs that ended with an error;
- `seconds_median`, `seconds_min` and `seconds_max`: the time of the runs in seconds;
- `n_rows`: the rows of the result, the same in every run.
