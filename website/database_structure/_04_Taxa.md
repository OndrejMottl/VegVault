

## Taxa

### <span class="database">Taxa Structure Overview</span> (`Taxa`)

The <span class="vegvault">VegVault</span> database records the original
<span class="database">taxonomic names</span> derived directly from the
<span class="data-processing">primary data sources</span>, and
currently, it holds over 100 thousand <span class="database">taxonomic
names</span>.

| column_name | data_type | description                          |
|-------------|-----------|--------------------------------------|
| taxon_id    | INTEGER   | ID of a Taxon (unique)               |
| taxon_name  | TEXT      | Name of a Taxon from primary source. |

Column names and types for table `Taxa`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Taxa.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Sample-Taxa</span> (`SampleTaxa`)

Each individual <span class="database">Taxon</span> is linked to
corresponding <span class="database">Samples</span> through the
`SampleTaxa` table, ensuring accurate and systematic association between
species and their ecological data. Note that the abundance information
varies across the primary data sources. Therefore, users have to be
careful while processing data from various sources.

| column_name | data_type | description |
|----|----|----|
| sample_id | INTEGER | ID of a Sample |
| taxon_id | INTEGER | ID of a Taxon |
| value | REAL | Abundance representation of a Taxon (the units may differ among primary sources, i.e. Dataset Source-Types) |

Column names and types for table SampleTaxa.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleTaxa.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_taxa_per_source_type.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Taxon Classification</span> (`TaxonClassification`)

Each taxonomic name undergoes an automated classification (see [Database
Assembly](.\website/database_assembly.qmd)) and results are stored in
the `TaxonClassification` table. To classify the diverse taxa present in
the <span class="vegvault">VegVault</span> database, the
{[taxospace](https://github.com/OndrejMottl/taxospace)} R package was
used. This tool automatically aligns taxa names with the [Taxonomy
Backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
from the [Global Biodiversity Information
Facility](https://www.gbif.org/), providing a standardized
classification framework. Specifically, we try to find the best match of
the raw names of taxa using [Global Names
Resolver](https://resolver.globalnames.org/).

| column_name   | data_type | description                                      |
|---------------|-----------|--------------------------------------------------|
| taxon_id      | INTEGER   | ID of a Taxon                                    |
| taxon_species | INTEGER   | ID of a Taxon, which was assign as species level |
| taxon_genus   | INTEGER   | ID of a Taxon, which was assign as genus level   |
| taxon_family  | INTEGER   | ID of a Taxon, which was assign as family level  |

Column names and types for table `TaxonClassification`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TaxonClassification.png"
style="width:100.0%" data-fig-align="center" />

Taxonomic classification for some <span class="database">Taxa</span>
might be only available down to the genus or family level, while most of
the data is classified to species level. Classification information,
detailed up to the family level, is stored for each taxon, ensuring
consistency and facilitating comparative analyses across different
datasets. Currently, the <span class="vegvault">VegVault</span> database
holds over 110 thousand taxonomic names, of which we were unable to
classify only 1312 (1.2%).

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_taxa_per_class.png"
style="width:100.0%" data-fig-align="center" />

### <span class="database">Taxon Reference</span> (`TaxonReference`)

Each taxon might get a reference. Currently, this is used to track the
origin of the <span class="database">Taxon</span> name (i.e. which
primary source was used first with this
<span class="database">Taxon</span>). Note that
<span class="database">Taxa</span>, generated from taxonomic
classification are associated with `taxospace` reference.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| taxon_id     | INTEGER   | ID of a Taxon     |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table `TaxonReference`.

<br>
