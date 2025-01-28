

## Traits

Functional traits of vegetation taxa follow the same structure of
`Dataset` and `Samples` obtained directly from `Dataset` `Source-Types`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Traits.png"
style="width:100.0%" data-fig-align="center" />

### Trait domain

As there are differences in trait names across sources of data and
individual `Datasets`, the **VegVault** database contains `Trait Domain`
information to group traits together.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsDomain.png"
style="width:100.0%" data-fig-align="center" />

There are currently 6 `Trait Domains` following the [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489)

<table style="width:99%;">
<colgroup>
<col style="width: 23%" />
<col style="width: 67%" />
<col style="width: 8%" />
</colgroup>
<thead>
<tr>
<th>Trait domain</th>
<th>Trait</th>
<th>Data Source</th>
</tr>
</thead>
<tbody>
<tr>
<td>Stem specific density</td>
<td>stem wood density</td>
<td>BIEN</td>
</tr>
<tr>
<td>Stem specific density</td>
<td>Stem specific density (SSD, stem dry mass per stem fresh volume) or
wood density</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf nitrogen content per unit mass</td>
<td>leaf nitrogen content per leaf dry mass</td>
<td>BIEN</td>
</tr>
<tr>
<td>Leaf nitrogen content per unit mass</td>
<td>Leaf nitrogen (N) content per leaf dry mass</td>
<td>TRY</td>
</tr>
<tr>
<td>Diaspore mass</td>
<td>seed mass</td>
<td>BIEN</td>
</tr>
<tr>
<td>Diaspore mass</td>
<td>Seed dry mass</td>
<td>TRY</td>
</tr>
<tr>
<td>Plant heigh</td>
<td>whole plant height</td>
<td>BIEN</td>
</tr>
<tr>
<td>Plant heigh</td>
<td>Plant height vegetative</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf Area</td>
<td>leaf area</td>
<td>BIEN</td>
</tr>
<tr>
<td>Leaf Area</td>
<td>Leaf area (in case of compound leaves undefined if leaf or leaflet,
undefined if petiole is in- or exluded)</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf Area</td>
<td>Leaf area (in case of compound leaves: leaf, petiole excluded)</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf Area</td>
<td>Leaf area (in case of compound leaves: leaf, petiole included)</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf Area</td>
<td>Leaf area (in case of compound leaves: leaf, undefined if petiole
in- or excluded)</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf mass per area</td>
<td>leaf mass per area</td>
<td>BIEN</td>
</tr>
<tr>
<td>Leaf mass per area</td>
<td>Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA):
petiole included</td>
<td>TRY</td>
</tr>
<tr>
<td>Leaf mass per area</td>
<td>Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA):
undefined if petiole is in- or excluded)</td>
<td>TRY</td>
</tr>
</tbody>
</table>

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_traits_per_domain.png"
style="width:100.0%" data-fig-align="center" />

### Trait Values

Storing trait values in **VegVault** involves linking information across
`Datasets`, `Samples`, `Taxa`, and `Traits`. This comprehensive linkage
ensures that each trait value is accurately associated with its relevant
ecological, environmental and taxonomic context.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsValue.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_n_occurences_per_dommain.png"
style="width:100.0%" data-fig-align="center" />

### Trait reference

To ensure clarity and reproducibility, each trait in the **VegVault**
database can have additional `References` beyond the general `Dataset`
and `Sample` references. These trait-specific `References` provide
detailed provenance and citation information, supporting rigorous
scientific research and enabling users to trace the origins and
validation of each trait value.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsReference.png"
style="width:100.0%" data-fig-align="center" />
