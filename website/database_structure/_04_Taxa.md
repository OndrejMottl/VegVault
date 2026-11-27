

## Taxa {#taxa .topic-taxa .topic-icon}

### Taxa Structure Overview (`Taxa`) {#taxa-structure-overview-taxa .topic-taxa}

The <span class="vegvault">VegVault</span> database records the original
<span class="taxa">taxonomic names</span> derived directly from the
<span class="database">primary data sources</span>, and currently, it
holds 109,220 <span class="taxa">taxonomic names</span>.

| column_name | data_type | description                          |
|-------------|-----------|--------------------------------------|
| taxon_id    | INTEGER   | ID of a Taxon (unique)               |
| taxon_name  | TEXT      | Name of a Taxon from primary source. |

Column names and types for table `Taxa`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Taxa.svg){fig-align="center"
width="100%"}

### Sample-Taxa (`SampleTaxa`) {#sample-taxa-sampletaxa .topic-taxa}

Each individual <span class="taxa">Taxon</span> is linked to
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

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/SampleTaxa.svg){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_taxa_per_source_type.png){fig-align="center"
width="100%"}

### Taxon Classification (`TaxonClassification`) {#taxon-classification-taxonclassification .topic-taxa}

Each taxonomic name undergoes an automated classification (see [Database
Assembly](database_assembly.qmd)) and results are stored in the
`TaxonClassification` table. To classify the diverse taxa present in the
<span class="vegvault">VegVault</span> database, the
{[taxospace](https://github.com/OndrejMottl/taxospace)} R package was
used. This tool automatically aligns taxa names with the [Taxonomy
Backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
from the [Global Biodiversity Information
Facility](https://www.gbif.org/), providing a standardized
classification framework. Specifically, we try to find the best match of
the raw names of taxa using the [Global Names
Verifier](https://verifier.globalnames.org/). Two kinds of names are
corrected by hand after the automatic classification: fossil pollen
types that combine two or more taxa, and the pollen type “Pinus Picea”
(see [Database
Assembly](database_assembly.qmd#i-taxonomic-classification)).

| column_name   | data_type | description                                      |
|---------------|-----------|--------------------------------------------------|
| taxon_id      | INTEGER   | ID of a Taxon                                    |
| taxon_species | INTEGER   | ID of a Taxon, which was assign as species level |
| taxon_genus   | INTEGER   | ID of a Taxon, which was assign as genus level   |
| taxon_family  | INTEGER   | ID of a Taxon, which was assign as family level  |

Column names and types for table `TaxonClassification`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TaxonClassification.svg){fig-align="center"
width="100%"}

Taxonomic classification for some <span class="taxa">Taxa</span> might
be only available down to the genus or family level, while most of the
data is classified to species level. Classification information,
detailed up to the family level, is stored for each taxon, ensuring
consistency and facilitating comparative analyses across different
datasets. Currently, the <span class="vegvault">VegVault</span> database
holds 109,220 taxonomic names, of which we were unable to classify only
900 (0.8%).

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_taxa_per_class.png){fig-align="center"
width="100%"}

### Taxon Reference (`TaxonReference`) {#taxon-reference-taxonreference .topic-taxa}

Each taxon might get a reference. Currently, this is used to track the
origin of the <span class="taxa">Taxon</span> name (i.e. which primary
source was used first with this <span class="taxa">Taxon</span>). Note
that <span class="taxa">Taxa</span>, generated from taxonomic
classification are associated with `taxospace` reference.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| taxon_id     | INTEGER   | ID of a Taxon     |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table `TaxonReference`.

<br>
