

## Samples

<span class="database">Samples</span> represent the main unit of data in
<span class="vegvault">VegVault</span>, serving as the fundamental
building blocks for all analyses. There are currently over 13 million
<span class="database">Samples</span> in
<span class="vegvault">VegVault</span> v1.0.0 (of which ~ 1.6 million
are <span class="abiotic">gridpoints</span> of
<span class="abiotic">abiotic data</span>, see [Database
Assembly](.\website/database_assembly.qmd#iii-creation-of-gridpoints-for-abiotic-data)).

<span class="vegvault">VegVault</span> encompasses both
<span class="neo-vegetation">contemporary</span> and
<span class="paleo">paleo data</span>, necessitating accurate
<span class="paleo">age information</span> for each
<span class="database">Sample</span>.
<span class="neo-vegetation">Contemporary</span>
<span class="database">Samples</span> are assigned an age of `0`, while
<span class="database">Samples</span> from <span class="paleo">fossil
pollen records</span> are in <span class="paleo">calibrated years before
the present (cal yr BP)</span>. The *present* is here specified as
`1950 AD`.

### <span class="database">Sample Structure Overview</span> (`Samples`)

The table contains one <span class="database">Sample</span> per row,
with each <span class="database">Sample</span> containing: a unique
<span class="database">Sample ID</span> (`sample_id`),
<span class="database">Sample name</span> (`sample_name`), temporal
information about <span class="database">Sample</span>
(<span class="paleo">age</span>), sample site (size of the plot if
available; `sample_size_id`), and additional information about sample
(`sample_details`; this is currently not being used in v1.0.0.). As
<span class="vegvault">VegVault</span> encompasses both
<span class="neo-vegetation">contemporary</span> and
<span class="paleo">paleo-data</span>, accurate <span class="paleo">age
information</span> is required for each
<span class="database">Sample</span>.

| column_name | data_type | description |
|----|----|----|
| sample_id | INTEGER | ID of a Sample (unique) |
| sample_name | TEXT | Name of a Sample |
| sample_details | TEXT | Specific description of a Sample. Currently not being used. |
| age | REAL | Age of sample. Mainly used for `fossil_pollen_archives`, where note the age of a <span class="database">Sample</span> in calibrated years before present. Note that all contemporary <span class="database">Samples</span>, have age of 0. |
| sample_size_id | INTEGER | ID of a Sample Size |

Column names and types for table `Samples`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Samples.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Dataset-Sample</span> (`DatasetSample`)

Each <span class="database">Sample</span> is linked to a specific
<span class="database">Dataset</span> via the `DatasetSample` table,
which ensures that every <span class="database">Sample</span> is
correctly associated with its corresponding
<span class="database">Dataset Type</span> (whether it is
`vegetation_plot`, `fossil_pollen_archive`, `traits`, or `gridpoint`)
and other <span class="database">Dataset</span> properties (e.g.,
geographic location). One <span class="database">Dataset</span> contains
several <span class="database">Samples</span> only in a case where they
differ in time (`age`).

| column_name | data_type | description     |
|-------------|-----------|-----------------|
| dataset_id  | INTEGER   | ID of a Dataset |
| sample_id   | INTEGER   | ID of a Sample  |

Column names and types for table `DatasetSample`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSample.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Sample Size</span> (`SampleSizeID`)

The size of vegetation plots can vary substantially. This detail is
crucial for ecological studies where plot size can influence species
diversity and abundance metrics, thus impacting follow-up analyses and
interpretations. To account for this variability, information about the
plot size is recorded separately for each
<span class="neo-vegetation">contemporary</span>
<span class="database">Sample</span>.

| column_name | data_type | description |
|----|----|----|
| sample_size_id | INTEGER | ID of a size category (unique) |
| sample_size | REAL | Numeric expression of size |
| description | TEXT | Mostly description of units in which the values are stored |

Column names and types for table `SampleSizeID`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleSizeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_samples_plot_size.png"
style="width:100.0%" data-fig-align="center" />

### <span class="paleo">Sample age uncertainty</span> (`SampleUncertainty`)

Each <span class="database">Sample</span> from the
`fossil_pollen_archive` <span class="database">Dataset</span> is also
associated with an <span class="paleo">uncertainty matrix</span>
generated during the re-estimation of ages using [FOSSILPOL
workflow](%5Bhttps%5D(https://bit.ly/FOSSILPOL)). This matrix provides a
range of potential ages derived from <span class="paleo">age-depth
modelling</span>, reflecting the inherent uncertainty in dating
<span class="paleo">paleoecological records</span>.

| column_name | data_type | description |
|----|----|----|
| sample_id | INTEGER | ID of a Sample |
| iteration | INTEGER | ID of a iteration from age depth model. Currently, the is 1000 iteration per each Sample. |
| age | INTEGER | Potential age of a Sample |

Column names and types for table `SampleUncertainty`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleUncertainty.png"
style="width:100.0%" data-fig-align="center" />

We can show this on the previously selected fossil pollen archive with
dataset ID: 91256.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_sample_age.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Sample Reference</span>

Each <span class="database">Sample</span> in
<span class="vegvault">VegVault</span> can have specific
<span class="database">References</span> in addition to those at the
<span class="database">Dataset</span>-level. These individual
<span class="database">Sample References</span> provide detailed
provenance and citation information, ensuring that users can trace the
origin and validation of each data point. Note that a single
<span class="database">Sample</span> can have several
<span class="database">References</span>. This level of referencing
enhances the transparency and reliability of the data, especially when
the dataset continues to be updated in the future.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| sample_id    | INTEGER   | ID of a Sample    |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table `SampleReference`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleReference.png"
style="width:100.0%" data-fig-align="center" />

<br>
