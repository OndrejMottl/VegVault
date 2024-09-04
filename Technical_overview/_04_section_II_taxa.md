

## Taxa

The **VegVault** database records taxa names derived directly from the
primary data sources. Each individual `Taxon` is linked to corresponding
`Samples` through the `SampleTaxa` table, ensuring accurate and
systematic association between species and their ecological data.

<img src="DB_scheme_visualisation/Taxa.png" style="width:100.0%"
data-fig-align="center" />

<img src="DB_scheme_visualisation/SampleTaxa.png" style="width:100.0%"
data-fig-align="center" />

<img src="../Figures/%20fig_n_taxa_per_source_type%20.png"
style="width:100.0%" data-fig-align="center" />

### Classification

To classify the diverse taxa present in the **VegVault** database, the
{[taxospace](https://github.com/OndrejMottl/taxospace)} R package was
used. This tool automatically aligns taxa names with the [Taxonomy
Backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
from the [Global Biodiversity Information
Facility](https://www.gbif.org/), providing a standardized
classification framework. Specifically, we try to find the best match of
the raw names of taxa using [Global Names
Resolver](https://resolver.globalnames.org/). Classification
information, detailed up to the family level, is stored for each taxon,
ensuring consistency and facilitating comparative analyses across
different datasets. Currently, the **VegVault** database holds over 110
thousand taxonomic names, of which we were unable to classify only 1312
(1.2%).

<img src="DB_scheme_visualisation/TaxonClassification.png"
style="width:100.0%" data-fig-align="center" />

<img src="../Figures/%20fig_n_taxa_per_class%20.png"
style="width:100.0%" data-fig-align="center" />
