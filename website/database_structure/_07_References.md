

## References (`References`)

The `References` table is a central component that serves all sections
of the **VegVault** database. This table contains all `References`,
independent of the source of the reference and the type of data. Each
row contains a single `Reference`, which is then linked to the type of
data which is being referenced. This allows a single `Reference` to be
used across data types, but also one data point having many different
references.

Moreover, most primary sources of the data have a license, which
requires correct attribution. Therefore, each `Reference` has
information if such a `Reference` needs to be cited while using the
specific data.
