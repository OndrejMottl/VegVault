

## Datasets {#datasets .topic-database .topic-icon}

### Dataset Structure Overview (`Datasets`) {#dataset-structure-overview-datasets .topic-database}

The `Datasets` table represents the main organizational structure in
<span class="vegvault">VegVault</span>, serving as the keystone for
managing and organizing all data. Each
<span class="database">Dataset</span> contains one row with a unique
<span class="database">Dataset ID</span> (`dataset_id`),
<span class="database">Dataset name</span> (`dataset_name`), geographic
location (`coord_lat`, `coord_long`), <span class="database">Dataset
Type</span> (`dataset_type_id`), <span class="database">Dataset
Source</span> (`data_source_id`), <span class="database">Dataset Source
Type</span> (`data_source_type_id`), and <span class="database">Sampling
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

Column names and types for table `Datasets`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Datasets.svg){fig-align="center"
width="100%"}

#### Dataset Types (`DatasetTypeID`) {#dataset-types-datasettypeid .topic-database}

The <span class="database">Dataset Type</span> defines the most basic
classification of each <span class="database">Dataset</span>, ensuring
that the vast amount of data is categorized systematically. Currently,
<span class="vegvault">VegVault</span> contains the following types of
<span class="database">Datasets</span>:

- `vegetation_plot`: This type includes
  <span class="neo-vegetation">contemporary vegetation plot data</span>,
  capturing contemporary vegetation characteristics and distributions.
- `fossil_pollen_archive`: This type encompasses
  <span class="paleo">past vegetation plot data</span> derived from
  <span class="paleo">fossil pollen records</span>, providing insights
  into past vegetation and climate dynamics.
- `traits`: This type contains <span class="traits">functional trait
  data</span>, detailing specific characteristics of plant species that
  influence their ecological roles.
- `gridpoints`: This type holds artificially created
  <span class="database">Datasets</span> to manage
  <span class="abiotic">abiotic data</span>, here
  <span class="abiotic">climate</span> and <span class="abiotic">soil
  information</span> (a <span class="database">Dataset Type</span>
  created to hold <span class="abiotic">abiotic data</span>, see details
  in the [Database
  Assemly](database_assembly.qmd#iii-creation-of-gridpoints-for-abiotic-data)).

| column_name | data_type | description |
|----|----|----|
| dataset_type_id | INTEGER | ID of a Dataset Type (unique) |
| dataset_type | TEXT | Text description of individual Dataset Types (currently vegetation_plot, fossil_pollen_archive, traits, gridpoints) |

Column names and types for table `DatasetTypeID`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetTypeID.svg){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_type.png){fig-align="center"
width="100%"}

#### Dataset Source-Types (`DatasetSourceTypeID`) {#dataset-source-types-datasetsourcetypeid .topic-database}

<span class="vegvault">VegVault</span> maintains detailed information
about the <span class="database">primary data source</span>, thereby
enhancing the findability and referencing of
<span class="database">primary data sources</span>. Each
<span class="database">Dataset</span> is derived from a specific
<span class="database">Source-Type</span> that provides detailed
information on the source used to retrieve the original data. The
current <span class="database">Source-Types</span> in
<span class="vegvault">VegVault</span> include:

- <span class="neo-vegetation">BIEN</span> - [Botanical Information and
  Ecology Network](https://bien.nceas.ucsb.edu/bien/)
- <span class="neo-vegetation">sPlotOpen</span> - [The open-access
  version of
  sPlot](https://idiv-biodiversity.de/en/splot/splotopen.html)
- <span class="traits">TRY</span> - [TRY Plant Trait
  Database](https://www.try-db.org/TryWeb/Home.php)
- <span class="paleo">Neotoma-FOSSILPOL</span> (source type `FOSSILPOL`
  in the database) - [The workflow that aims to process and standardise
  global palaeoecological pollen
  data](https://hope-uib-bio.github.io/FOSSILPOL-website/). Note that we
  specifically state <span class="paleo">Neotoma-FOSSILPOL</span> and
  not just Neotoma, as <span class="paleo">FOSSILPOL</span> not only
  provides the <span class="reproducibility">data acquisition</span> but
  also alters it (e.g., creating new <span class="paleo">age-depth
  models</span>). It also addresses major challenges in
  <span class="database">paleoecological data integration</span>, such
  as <span class="paleo">age uncertainty</span>, by incorporating
  probabilistic <span class="paleo">age-depth models</span> and their
  associated <span class="paleo">uncertainty matrices</span>. This
  enables the propagation of <span class="paleo">temporal
  uncertainty</span> in subsequent analyses, a critical advancement for
  robust macroecological studies, previously flagged as a major issue
  with <span class="paleo">paleo-data</span>.
- <span class="abiotic">gridpoints</span> - artificially created
  <span class="database">Datasets</span> to hold
  <span class="abiotic">abiotic data</span>. See [Database
  Assembly](database_assembly.qmd#iii-creation-of-gridpoints-for-abiotic-data)
  for more details.

| column_name | data_type | description |
|----|----|----|
| data_source_type_id | INTEGER | ID of a Dataset Source-Type (unique) |
| dataset_source_type | TEXT | Text description of individual Dataset Source-Type (currently, BIEN, sPlotOpen, TRY, FOSSILPOL, gridpoints) |

Column names and types for table `DatasetSourceTypeID`.

| column_name         | data_type | description                 |
|---------------------|-----------|-----------------------------|
| data_source_type_id | INTEGER   | ID of a Dataset Source-Type |
| reference_id        | INTEGER   | ID of a Reference           |

Column names and types for table `DatasetSourceTypeReference`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourceTypeID.svg){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source_type.png){fig-align="center"
width="100%"}

#### Dataset Sources (`DatasetSourcesID`) {#dataset-sources-datasetsourcesid .topic-database}

Each individual <span class="database">Dataset</span> from a specific
<span class="database">Dataset</span>
<span class="database">Source-Type</span> can have information on the
source of the data (i.e. sub-database).
<span class="vegvault">VegVault</span> 2.0.0 currently includes 693
sources of <span class="database">Datasets</span>, where each dataset
can also have one or more direct references to specific data, ensuring
that users can accurately cite and verify the sources of their data.
This should help to promote better findability of the primary source of
data and referencing.

| column_name | data_type | description |
|----|----|----|
| data_source_id | INTEGER | ID of a Dataset Source (unique) |
| data_source_desc | TEXT | Text description of individual Dataset Sources (e.g., name of the sub-database from the primary source) |

Column names and types for table `DatasetSourcesID`.

| column_name    | data_type | description            |
|----------------|-----------|------------------------|
| data_source_id | INTEGER   | ID of a Dataset Source |
| reference_id   | INTEGER   | ID of a Reference      |

Column names and types for table `DatasetSourcesReference`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourcesID.svg){fig-align="center"
width="100%"}

Currently, there are 693 sources of
<span class="database">Datasets</span>.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source.png){fig-align="center"
width="100%"}

#### Sampling Methods (`SamplingMethodID`) {#sampling-methods-samplingmethodid .topic-database}

Sampling methods vary significantly across the different types of
<span class="database">Datasets</span> integrated into
<span class="vegvault">VegVault</span>, reflecting the diverse nature of
the data collected. Such information is crucial for understanding the
context and limitations of each <span class="database">Dataset
Type</span>. For <span class="neo-vegetation">contemporary vegetation
plots</span>, sampling involves standardised plot inventories and
surveys that capture detailed vegetation characteristics across various
regions. <span class="paleo">Fossil pollen</span> data are collected
from sediment records from numerous different depositional environments
representing past vegetation. Therefore, information on sampling methods
is only available for both `vegetation_plot` and `fossil_pollen_archive`
<span class="database">Datasets</span>, providing metadata that ensures
accurate and contextually relevant analyses.

| column_name | data_type | description |
|----|----|----|
| sampling_method_id | INTEGER | ID of a Dataset Sampling Method (unique) |
| sampling_method_details | TEXT | Text description of individual Dataset Sampling Methods |

Column names and types for table `SamplingMethodID`.

| column_name        | data_type | description                     |
|--------------------|-----------|---------------------------------|
| sampling_method_id | INTEGER   | ID of a Dataset Sampling Method |
| reference_id       | INTEGER   | ID of a Reference               |

Column names and types for table `SamplingMethodReference`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SamplingMethodID.svg){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_sampling_methods_per_dataset_type.png){fig-align="center"
width="100%"}

#### Dataset References (`DatasetReferences`) {#dataset-references-datasetreferences .topic-database}

To support robust and transparent scientific research, each
<span class="database">Dataset</span> in
<span class="vegvault">VegVault</span> can have multiple references at
different levels. The <span class="database">Dataset</span>
<span class="database">Source-Type</span>,
<span class="database">Dataset Source</span>, and
<span class="database">Sampling Method</span> can all have their own
references, providing detailed provenance and citation information. This
multi-level referencing system enhances the traceability and validation
of the data. Each <span class="database">Dataset</span> can also have
one or more direct references to specific data, further ensuring that
users can accurately cite and verify the sources of their data.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| dataset_id   | INTEGER   | ID of a Dataset   |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table `DatasetReferences`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetReference.svg){fig-align="center"
width="100%"}

This means that one dataset can have one/several references from each of
those parts. Let’s take a look at an example of what that could mean in
practice.

We have selected the dataset fossilpol_1001 (dataset ID 91184 in this
version), Hail Lake in Yukon, which is a <span class="paleo">fossil
pollen archive</span>. Therefore, it has the reference of the *Dataset
Source-Type*:

- *Flantua, S. G. A., Mottl, O., Felde, V. A., Bhatta, K. P., Birks, H.
  H., Grytnes, J.-A., Seddon, A. W. R., & Birks, H. J. B. (2023). A
  guide to the processing and standardization of global palaeoecological
  data for large-scale syntheses using fossil pollen. Global Ecology and
  Biogeography, 32, 1377–1394. https://doi.org/10.1111/geb.13693*

and reference for the individual dataset:

- *Grimm, E.C., 2008. Neotoma: an ecosystem database for the Pliocene,
  Pleistocene, and Holocene. Illinois State Museum Scientific Papers E
  Series, 1.*

<br>
