

# Section II: Internal Database Structure

## `Dataset`

The `Dataset` represents the main structure in the **VegVault**, serving
as the keystone for organizing and managing data. Here we will explain
some, but not all, of the features of the `Dataset`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Datasets.png"
style="width:100.0%" data-fig-align="center" />

### `Dataset Type`

The `Dataset Type` defines the most basic classification of each
`Dataset`, ensuring that the vast amount of data is categorized
systematically. Currently, **VegVault** contains the following types of
`Datasets`:

-   `vegetation_plot`: This type includes contemporary vegetation plot
    data, capturing contemporary vegetation characteristics and
    distributions.
-   `fossil_pollen_archive`: This type encompasses past vegetation plot
    data derived from fossil pollen records, providing insights into
    historical vegetation patterns.
-   `traits`: This type contains functional trait data, detailing
    specific characteristics of plant species that influence their
    ecological roles.
-   `gridpoints`: This type holds artificially created `Datasets` to
    manage abiotic data, here climate and soil information

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_type.png"
style="width:100.0%" data-fig-align="center" />

### `Dataset` `Source-Type`

VegVault maintains the detailed information on the source used to
retrieve the original data, thereby enhancing the findability and
referencing of primary data sources. Each `Dataset` is derived from a
specific `Source-Type` provides detailed information on the source,
which was used to retrieve the original data, enhancing the findability
and referencing of primary data sources. The current `Source-Types` in
**VegVault** include

-   **BIEN** - [Botanical Information and Ecology
    Network](https://bien.nceas.ucsb.edu/bien/)
-   **sPlotOpen** - [The open-access version of
    sPlot](https://idiv-biodiversity.de/en/splot/splotopen.html)
-   **TRY** - [TRY Plant Trait
    Database](https://www.try-db.org/TryWeb/Home.php)
-   **FOSSILPOL** - [The workflow that aims to process and standardise
    global palaeoecological pollen
    data](https://hope-uib-bio.github.io/FOSSILPOL-website/). Note that
    we specifically state FOSSILPOL and not Neotoma, as FOSSILPOL not
    only provides the data but also alters it (e.g, new age-depth
    models).
-   **gridpoints** - artificially created `Datasets` to hold abiotic
    data

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourceTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source_type.png"
style="width:100.0%" data-fig-align="center" />

### `Dataset Source`

Each individual `Dataset` from a specific `Dataset` `Source-Type` can
have information on the source of the data (i.e. sub-database). This
should help to promote better findability of the primary source of data
and referencing.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetSourcesID.png"
style="width:100.0%" data-fig-align="center" />

Currently, there are 691 sources of datasets.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_datasetes_per_source.png"
style="width:100.0%" data-fig-align="center" />

### Sampling Method

Sampling methods vary significantly across the different types of
`Datasets` integrated into **VegVault**, reflecting the diverse nature
of the data collected. For current vegetation plots, sampling involves
standardized plot inventories and surveys that capture detailed
vegetation characteristics across various regions. In contrast, fossil
pollen data are collected from sediment cores, representing past
vegetation and depositional environments. These sampling methods are
crucial for understanding the context and limitations of each Dataset
Type. Therefore, information on sampling methods is only present for
both `vegetation_plot` and `fossil_pollen_archive` `Datasets`, providing
metadata that ensures accurate and contextually relevant analyses

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SamplingMethodID.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_sampling_methods_per_dataset_type.png"
style="width:100.0%" data-fig-align="center" />

### References

To support robust and transparent scientific research, each `Dataset` in
**VegVault** can have multiple references at different levels. The
`Dataset` `Source-Type`, `Dataset Source`, and `Sampling Method` can all
have their own references, providing detailed provenance and citation
information. This multi-level referencing system enhances the
traceability and validation of the data. **VegVault** currently includes
706 sources of `Datasets`, each documented to ensure reliability and
ease of use. Each dataset can also have one or more direct references to
specific data, further ensuring that users can accurately cite and
verify the sources of their data.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/DatasetReference.png"
style="width:100.0%" data-fig-align="center" />

This means that one dataset can have one/several references from each of
those parts. Let’s take a look at an example, of what that could mean in
practice.

We have selected dataset ID: 91256, which is a fossil pollen archive.
Therefore, it has the reference of the *Dataser Source-Type*:

-   *Flantua, S. G. A., Mottl, O., Felde, V. A., Bhatta, K. P.,
    Birks, H. H., Grytnes, J.-A., Seddon, A. W. R., & Birks, H. J. B.
    (2023). A guide to the processing and standardization of global
    palaeoecological data for large-scale syntheses using fossil pollen.
    Global Ecology and Biogeography, 32, 1377–1394.
    https://doi.org/10.1111/geb.13693*

and reference for the individual dataset:

-   *Grimm, E.C., 2008. Neotoma: an ecosystem database for the Pliocene,
    Pleistocene, and Holocene. Illinois State Museum Scientific Papers E
    Series, 1.*
