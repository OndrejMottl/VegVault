

## Samples

`Samples` represent the main unit of data in **VegVault**, serving as
the fundamental building blocks for all analyses. There are currently
over 13 million `Samples` in **VegVault** v1.0.0 (of which ~ 1.6 million
are gridpoints of abiotic data, see [Database
Assembly](.\website/database_assembly.qmd)).

**VegVault** encompasses both contemporary and paleo data, necessitating
accurate age information for each `Sample`. Contemporary `Samples` are
assigned an age of `0`, while `Samples` from fossil pollen records are
in calibrated years before the present (cal yr BP). The “present” is
here specified as 1950 AD.

### Sample Structure Overview (`Samples`)

The table contains one `Sample` per row, with each `Sample` containing:
a unique Sample ID (`sample_id`), Sample name (`sample_name`), temporal
information about Sample (`age`), sample site (size of the plot if
available; `sample_size_id`), and additional information about sample
(`sample_details`; this is currently not being used in v1.0.0.). As
**VegVault** encompasses both contemporary and paleo-data, accurate age
information is required for each Sample.

| column_name | data_type | description |
|----|----|----|
| sample_id | INTEGER | ID of a Sample (unique) |
| sample_name | TEXT | Name of a Sample |
| sample_details | TEXT | Specific description of a Sample. Currently not being used. |
| age | REAL | Age of sample. Mainly used for fossil_pollen_archives, where note the age of a Sample in calibrated years before present. Note that all contemporary Samples, have age of 0. |
| sample_size_id | INTEGER | ID of a Sample Size |

Column names and types for table Samples.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Samples.png"
style="width:100.0%" data-fig-align="center" />

### Dataset-Sample (`DatasetSample`)

Each Sample is linked to a specific `Dataset` via the `DatasetSample`
table, which ensures that every Sample is correctly associated with its
corresponding `Dataset Type` (whether it is `vegetation_plot`,
`fossil_pollen_archive`, `traits`, or `gridpoint`) and other `Dataset`
properties (e.g., geographic location). One `Dataset` contains several
`Samples` only in a case where they differ in time (`age`).

| column_name | data_type | description     |
|-------------|-----------|-----------------|
| dataset_id  | INTEGER   | ID of a Dataset |
| sample_id   | INTEGER   | ID of a Sample  |

Column names and types for table DatasetSample.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSample.png"
style="width:100.0%" data-fig-align="center" />

### Sample Size (`SampleSizeID`)

The size of vegetation plots can vary substantially. This detail is
crucial for ecological studies where plot size can influence species
diversity and abundance metrics, thus impacting follow-up analyses and
interpretations. To account for this variability, information about the
plot size is recorded separately for each contemporary Sample.

| column_name | data_type | description |
|----|----|----|
| sample_size_id | INTEGER | ID of a size category (unique) |
| sample_size | REAL | Numeric expression of size |
| description | TEXT | Mostly description of units in which the values are stored |

Column names and types for table SampleSizeID.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleSizeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_samples_plot_size.png"
style="width:100.0%" data-fig-align="center" />

### Sample age uncertainty (`SampleUncertainty`)

Each Sample from the `fossil_pollen_archive` `Dataset` is also
associated with an uncertainty matrix generated during the re-estimation
of ages using FOSSILPOL workflow. This matrix provides a range of
potential ages derived from age-depth modelling, reflecting the inherent
uncertainty in dating paleoecological records.

| column_name | data_type | description |
|----|----|----|
| sample_id | INTEGER | ID of a Sample |
| iteration | INTEGER | ID of a iteration from age depth model. Currently, the is 1000 iteration per each Sample. |
| age | INTEGER | Potential age of a Sample |

Column names and types for table SampleUncertainty.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleUncertainty.png"
style="width:100.0%" data-fig-align="center" />

We can show this on the previously selected fossil pollen archive with
dataset ID: 91256.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_sample_age.png"
style="width:100.0%" data-fig-align="center" />

### Sample Reference

Each `Sample` in **VegVault** can have specific `References` in addition
to those at the `Dataset`-level. These individual `Sample References`
provide detailed provenance and citation information, ensuring that
users can trace the origin and validation of each data point. Note that
a single `Sample` can have several References. This level of referencing
enhances the transparency and reliability of the data, especially when
the dataset continues to be updated in the future.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| sample_id    | INTEGER   | ID of a Sample    |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table SampleReference.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleReference.png"
style="width:100.0%" data-fig-align="center" />
