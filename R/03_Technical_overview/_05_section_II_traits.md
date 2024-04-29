

- [Traits](#traits)
  - [Trait domain](#trait-domain)
  - [Trait Values](#trait-values)
  - [Trait reference](#trait-reference)

## Traits

Functional traits of vegetation taxa follow the same structure of
`Dataset` and `Samples` obtained directly from *Dataset Source-types*.

<img src="DB_scheme_visualisation/Traits.png" style="width:100.0%"
data-fig-align="center" />

### Trait domain

As there are many varying names for the same “traits”, the **VegVault**
database contains *Trait Domain* information to group traits together.

<img src="DB_scheme_visualisation/TraitsDomain.png" style="width:100.0%"
data-fig-align="center" />

There are currently 6 trait domains following the [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489)

| Trait domain                        |
|-------------------------------------|
| Stem specific density               |
| Leaf nitrogen content per unit mass |
| Diaspore mass                       |
| Plant heigh                         |
| Leaf Area                           |
| Leaf mass per area                  |

<img src="figures/trait%20per%20domain%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

### Trait Values

To store a trait value, information needs to be linked among `Dataset`,
`Sample`, `Taxa`, and `Trait`.

<img src="DB_scheme_visualisation/TraitsValue.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/trait%20value%20occurences%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

### Trait reference

For full clarity, on top of `Dataset` and `Sample`, each `Trait` can
have additional references.

<img src="DB_scheme_visualisation/TraitsReference.png"
style="width:100.0%" data-fig-align="center" />
