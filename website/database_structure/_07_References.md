

## References

The `References` table is a central component that serves all sections
of the <span class="vegvault">VegVault</span> database. This table
contains all <span class="database">References</span>, independent of
the source of the <span class="database">reference</span> and the type
of data. Each row contains a single
<span class="database">Reference</span>, which is then linked to the
type of data which is being referenced. This allows a single
<span class="database">Reference</span> to be used across data types,
but also one data point having many different
<span class="database">references</span>.

Moreover, most <span class="database">primary sources</span> of the data
have a license, which requires <span class="reproducibility">correct
attribution</span>. Therefore, each
<span class="database">Reference</span> has information if such a
<span class="database">Reference</span> needs to be
<span class="reproducibility">cited</span> while using the specific
data.
