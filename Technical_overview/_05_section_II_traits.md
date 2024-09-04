

## Traits

Functional traits of vegetation taxa follow the same structure of
`Dataset` and `Samples` obtained directly from `Dataset` `Source-Types`.

<img src="DB_scheme_visualisation/Traits.png" style="width:100.0%"
data-fig-align="center" />

### Trait domain

As there are differences in trait names across sources of data and
individual `Datasets`, the **VegVault** database contains `Trait Domain`
information to group traits together.

<img src="DB_scheme_visualisation/TraitsDomain.png" style="width:100.0%"
data-fig-align="center" />

There are currently 6 `Trait Domains` following the [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489)

| Trait domain                        | Trait                                                                                                       | Data source |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------|-------------|
| Stem specific density               | stem wood density                                                                                           | BIEN        |
| Stem specific density               | Stem specific density (SSD, stem dry mass per stem fresh volume) or wood density                            | TRY         |
| Leaf nitrogen content per unit mass | leaf nitrogen content per leaf dry mass                                                                     | BIEN        |
| Leaf nitrogen content per unit mass | Leaf nitrogen (N) content per leaf dry mass                                                                 | TRY         |
| Diaspore mass                       | seed mass                                                                                                   | BIEN        |
| Diaspore mass                       | Seed dry mass                                                                                               | TRY         |
| Plant heigh                         | whole plant height                                                                                          | BIEN        |
| Plant heigh                         | Plant height vegetative                                                                                     | TRY         |
| Leaf Area                           | leaf area                                                                                                   | BIEN        |
| Leaf Area                           | Leaf area (in case of compound leaves undefined if leaf or leaflet, undefined if petiole is in- or exluded) | TRY         |
| Leaf Area                           | Leaf area (in case of compound leaves: leaf, petiole excluded)                                              | TRY         |
| Leaf Area                           | Leaf area (in case of compound leaves: leaf, petiole included)                                              | TRY         |
| Leaf Area                           | Leaf area (in case of compound leaves: leaf, undefined if petiole in- or excluded)                          | TRY         |
| Leaf mass per area                  | leaf mass per area                                                                                          | BIEN        |
| Leaf mass per area                  | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): petiole included                            | TRY         |
| Leaf mass per area                  | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): undefined if petiole is in- or excluded)    | TRY         |

<img src="../Figures/%20fig_n_traits_per_domain%20.png"
style="width:100.0%" data-fig-align="center" />

### Trait Values

Storing trait values in **VegVault** involves linking information across
`Datasets`, `Samples`, `Taxa`, and `Traits`. This comprehensive linkage
ensures that each trait value is accurately associated with its relevant
ecological, environmental and taxonomic context.

<img src="DB_scheme_visualisation/TraitsValue.png" style="width:100.0%"
data-fig-align="center" />

<img src="../Figures/%20fig_n_occurences_per_dommain%20.png"
style="width:100.0%" data-fig-align="center" />

### Trait reference

To ensure clarity and reproducibility, each trait in the **VegVault**
database can have additional `References` beyond the general `Dataset`
and `Sample` references. These trait-specific `References` provide
detailed provenance and citation information, supporting rigorous
scientific research and enabling users to trace the origins and
validation of each trait value.

<img src="DB_scheme_visualisation/TraitsReference.png"
style="width:100.0%" data-fig-align="center" />
