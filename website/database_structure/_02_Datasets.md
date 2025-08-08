

## <span class="text-background-brownDark text-color-white text-bold">Datasets</span>

### <span class="text-background-brownDark text-color-white text-bold">Dataset Structure Overview</span> (`[Datasets]{.text-background-brownDark .text-color-white .text-bold}`)

The
<span class="text-background-brownDark text-color-white text-bold">`Datasets`</span>
table represents the main organizational structure in
**<span class="text-background-black text-color-white text-bold">VegVault</span>**,
serving as the keystone for managing and organizing all data. Each
<span class="text-background-brownDark text-color-white text-bold">Dataset</span>
contains one row with a unique
<span class="text-background-brownDark text-color-white text-bold">Dataset
ID</span> (`dataset_id`),
<span class="text-background-brownDark text-color-white text-bold">Dataset
name</span> (`dataset_name`), geographic location (`coord_lat`,
`coord_long`),
<span class="text-background-brownDark text-color-white text-bold">Dataset
Type</span> (`dataset_type_id`),
<span class="text-background-brownDark text-color-white text-bold">Dataset
Source</span> (`data_source_id`),
<span class="text-background-brownDark text-color-white text-bold">Dataset
Source Type</span> (`dataset_source_type_id`), and
<span class="text-background-brownLight text-color-black text-bold">Sampling
Method</span> (`sampling_method_id`).

| column_name         | data_type | description                          |
|---------------------|-----------|--------------------------------------|
| dataset_id          | INTEGER   | ID of a Dataset (unique)             |
| dataset_name        | TEXT      | Name of each Dataset                 |
| data_source_id      | INTEGER   | ID of a Dataset Source               |
| dataset_type_id     | INTEGER   | ID of a Dataset Type                 |
| data_source_type_id | INTEGER   | ID of a Dataset Source-Type          |
| coord_long          | REAL      | Geographical coordinates - longitude |
| coord_lat           | REAL      | Geographical coordinates - latitude  |
| sampling_method_id  | INTEGER   | ID of a Sampling Method              |

Column names and types for table Datasets.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Datasets.png"
style="width:100.0%" data-fig-align="center" />

#### <span class="text-background-brownDark text-color-white text-bold">Dataset Types</span> (`[DatasetTypeID]{.text-background-brownDark .text-color-white .text-bold}`)

The
<span class="text-background-brownDark text-color-white text-bold">`Dataset Type`</span>
defines the most basic classification of each
<span class="text-background-brownDark text-color-white text-bold">`Dataset`</span>,
ensuring that the vast amount of data is categorized systematically.
Currently,
**<span class="text-background-black text-color-white text-bold">VegVault</span>**
contains the following types of
<span class="text-background-brownDark text-color-white text-bold">`Datasets`</span>:

- <span class="text-background-greenLight text-color-black text-bold">`vegetation_plot`</span>:
  This type includes
  <span class="text-background-greenLight text-color-black text-bold">contemporary
  vegetation plot data</span>, capturing contemporary vegetation
  characteristics and distributions.
- <span class="text-background-purpleLight text-color-black text-bold">`fossil_pollen_archive`</span>:
  This type encompasses
  <span class="text-background-purpleLight text-color-black text-bold">past
  vegetation plot data</span> derived from
  <span class="text-background-purpleLight text-color-black text-bold">fossil
  pollen records</span>, providing insights into past vegetation and
  climate dynamics.
- <span class="text-background-blueDark text-color-white text-bold">`traits`</span>:
  This type contains
  <span class="text-background-blueDark text-color-white text-bold">functional
  trait data</span>, detailing specific characteristics of plant species
  that influence their ecological roles.
- <span class="text-background-greenDark text-color-white text-bold">`gridpoints`</span>:
  This type holds artificially created
  <span class="text-background-brownDark text-color-white text-bold">`Datasets`</span>
  to manage
  <span class="text-background-greenDark text-color-white text-bold">abiotic
  data</span>, here
  <span class="text-background-greenDark text-color-white text-bold">climate</span>
  and
  <span class="text-background-greenDark text-color-white text-bold">soil
  information</span> (a
  <span class="text-background-brownDark text-color-white text-bold">dataset
  type</span> created to hold
  <span class="text-background-greenDark text-color-white text-bold">abiotic
  data</span>, see details in the Methods section).

| column_name | data_type | description |
|----|----|----|
| dataset_type_id | INTEGER | ID of a Dataset Type (unique) |
| dataset_type | TEXT | Text description of individual Dataset Types (currently vegetation_plot, fossil_pollen_archive, traits, gridpoints) |

Column names and types for table DatasetTypeID.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_type.png"
style="width:100.0%" data-fig-align="center" />

#### <span class="text-background-brownDark text-color-white text-bold">Dataset Source-Types</span> (`[DatasetSourceTypeID]{.text-background-brownDark .text-color-white .text-bold}`)

**<span class="text-background-black text-color-white text-bold">VegVault</span>**
maintains detailed information about the
<span class="text-background-brownDark text-color-white text-bold">primary
data source</span>, thereby enhancing the findability and referencing of
<span class="text-background-brownDark text-color-white text-bold">primary
data sources</span>. Each
<span class="text-background-brownDark text-color-white text-bold">`Dataset`</span>
is derived from a specific
<span class="text-background-brownDark text-color-white text-bold">`Source-Type`</span>
that provides detailed information on the source used to retrieve the
original data. The current
<span class="text-background-brownDark text-color-white text-bold">`Source-Types`</span>
in
**<span class="text-background-black text-color-white text-bold">VegVault</span>**
include:

- **<span class="text-background-greenLight text-color-black text-bold">BIEN</span>** -
  [Botanical Information and Ecology
  Network](https://bien.nceas.ucsb.edu/bien/)
- **<span class="text-background-greenLight text-color-black text-bold">sPlotOpen</span>** -
  [The open-access version of
  sPlot](https://idiv-biodiversity.de/en/splot/splotopen.html)
- **<span class="text-background-blueDark text-color-white text-bold">TRY</span>** -
  [TRY Plant Trait Database](https://www.try-db.org/TryWeb/Home.php)
- **<span class="text-background-purpleLight text-color-black text-bold">Neotoma-FOSSILPOL</span>** -
  [The workflow that aims to process and standardise global
  palaeoecological pollen
  data](https://hope-uib-bio.github.io/FOSSILPOL-website/). Note that we
  specifically state
  <span class="text-background-purpleLight text-color-black text-bold">Neotoma-FOSSILPOL</span>
  and not just Neotoma, as
  <span class="text-background-purpleLight text-color-black text-bold">FOSSILPOL</span>
  not only provides the
  <span class="text-background-brownLight text-color-black text-bold">data
  acquisition</span> but also alters it (e.g., creating new
  <span class="text-background-purpleLight text-color-black text-bold">age-depth
  models</span>). It also addresses major challenges in
  <span class="text-background-purpleLight text-color-black text-bold">paleoecological
  data integration</span>, such as
  <span class="text-background-purpleLight text-color-black text-bold">age
  uncertainty</span>, by incorporating
  <span class="text-background-purpleLight text-color-black text-bold">probabilistic
  age-depth models</span> and their associated
  <span class="text-background-purpleLight text-color-black text-bold">uncertainty
  matrices</span>. This enables the propagation of
  <span class="text-background-purpleLight text-color-black text-bold">temporal
  uncertainty</span> in subsequent analyses, a critical advancement for
  robust macroecological studies, previously flagged as a major issue
  with
  <span class="text-background-purpleLight text-color-black text-bold">paleo-data</span>.
- **<span class="text-background-greenDark text-color-white text-bold">gridpoints</span>** -
  artificially created
  <span class="text-background-brownDark text-color-white text-bold">`Datasets`</span>
  to hold
  <span class="text-background-greenDark text-color-white text-bold">abiotic
  data</span>

| column_name | data_type | description |
|----|----|----|
| data_source_type_id | INTEGER | ID of a Dataset Source-Type (unique) |
| dataset_source_type | TEXT | Text description of individual Dataset Source-Type (currently, BEIN, sPlotOpen, TRY, Neotoma-FOSSILPOL, gridpoints) |

Column names and types for table DatasetSourceTypeID.

| column_name         | data_type | description            |
|---------------------|-----------|------------------------|
| data_source_type_id | INTEGER   | NA                     |
| reference_id        | INTEGER   | ID of a Reference      |
| data_source_id      | NA        | ID of a Dataset Source |

Column names and types for table DatasetSourceTypeReference.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourceTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source_type.png"
style="width:100.0%" data-fig-align="center" />

#### Dataset Sources (`DatasetSourcesID`)

Each individual `Dataset` from a specific `Dataset` `Source-Type` can
have information on the source of the data (i.e. sub-database).
**VegVault** v1.0.0 currently includes 706 sources of `Datasets`, where
each dataset can also have one or more direct references to specific
data, ensuring that users can accurately cite and verify the sources of
their data. This should help to promote better findability of the
primary source of data and referencing.

| column_name | data_type | description |
|----|----|----|
| data_source_id | INTEGER | ID of a Dataset Source (unique) |
| data_source_desc | TEXT | Text description of individual Dataset Sources (e.g., name of the sub-database from the primary source) |

Column names and types for table DatasetSourcesID.

| column_name    | data_type | description            |
|----------------|-----------|------------------------|
| data_source_id | INTEGER   | ID of a Dataset Source |
| reference_id   | INTEGER   | ID of a Reference      |

Column names and types for table DatasetSourcesReference.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourcesID.png"
style="width:100.0%" data-fig-align="center" />

Currently, there are 691 sources of datasets.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source.png"
style="width:100.0%" data-fig-align="center" />

#### Sampling Methods (`SamplingMethodID`)

Sampling methods vary significantly across the different types of
`Datasets` integrated into **VegVault**, reflecting the diverse nature
of the data collected. Such information is crucial for understanding the
context and limitations of each `Dataset Type`. For contemporary
vegetation plots, sampling involves standardised plot inventories and
surveys that capture detailed vegetation characteristics across various
regions. Fossil pollen data are collected from sediment records from
numerous different depositional environments representing past
vegetation and climate dynamics. Therefore, information on sampling
methods is only available for both `vegetation_plot` and
`fossil_pollen_archive` `Datasets`, providing metadata that ensures
accurate and contextually relevant analyses.

| column_name | data_type | description |
|----|----|----|
| sampling_method_id | INTEGER | ID of a Dataset Sampling Method (unique) |
| sampling_method_details | TEXT | Text description of individual Dataset Sampling Methods |

Column names and types for table SamplingMethodID.

| column_name        | data_type | description                     |
|--------------------|-----------|---------------------------------|
| sampling_method_id | INTEGER   | ID of a Dataset Sampling Method |
| reference_id       | INTEGER   | ID of a Reference               |

Column names and types for table SamplingMethodReference.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SamplingMethodID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_sampling_methods_per_dataset_type.png"
style="width:100.0%" data-fig-align="center" />

#### Dataset References (`DatasetReferences`)

To support robust and transparent scientific research, each `Dataset` in
**VegVault** can have multiple references at different levels. The
`Dataset` `Source-Type`, `Dataset Source`, and `Sampling Method` can all
have their own references, providing detailed provenance and citation
information. This multi-level referencing system enhances the
traceability and validation of the data. Each dataset can also have one
or more direct references to specific data, further ensuring that users
can accurately cite and verify the sources of their data.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| dataset_id   | INTEGER   | ID of a Dataset   |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table DatasetReferences.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetReference.png"
style="width:100.0%" data-fig-align="center" />

This means that one dataset can have one/several references from each of
those parts. Let’s take a look at an example of what that could mean in
practice.

We have selected dataset ID: 91256, which is a fossil pollen archive.
Therefore, it has the reference of the *Dataset Source-Type*:

- *Flantua, S. G. A., Mottl, O., Felde, V. A., Bhatta, K. P., Birks, H.
  H., Grytnes, J.-A., Seddon, A. W. R., & Birks, H. J. B. (2023). A
  guide to the processing and standardization of global palaeoecological
  data for large-scale syntheses using fossil pollen. Global Ecology and
  Biogeography, 32, 1377–1394. https://doi.org/10.1111/geb.13693*

and reference for the individual dataset:

- *Grimm, E.C., 2008. Neotoma: an ecosystem database for the Pliocene,
  Pleistocene, and Holocene. Illinois State Museum Scientific Papers E
  Series, 1.*
