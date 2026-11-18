# VegVault R Function, Documentation, and Test Guidance

Canonical guidance for creating or materially editing R functions and their
focused tests in VegVault and sibling producer repositories. Also follow
`.ai/r-coding.md`; repository-local data and execution safeguards remain
binding.

## One function per file

- Store every reusable function under `R/Functions/` in a responsibility-based
  subdirectory.
- Put each function in a separate `.R` file whose basename exactly matches the
  function name.
- A function file contains exactly one function definition. Do not place
  another top-level, nested, or local named helper in the file by default.
- Search existing functions before creating another helper with overlapping
  behaviour.
- A helper definition inside a script or function is exceptional. It is allowed
  only when its complete body is approximately 5-10 lines, it drastically
  reduces repetition in that single owner, and extracting it would obscure
  rather than clarify the contract. State the reason in a nearby comment. If
  any condition is not met, create a separately named function file with its
  own roxygen and test file.
- Prefer a short anonymous `purrr` formula for a genuinely local transformation
  that satisfies the same exception. Do not use local helpers to avoid
  documenting or testing reusable behaviour.
- Always construct a result object and finish with an explicit `return(res)` or
  `return(invisible(res))`.

## Roxygen2 contract

Every function must have a roxygen2 block immediately above its definition.
The block is part of the function contract and must exist in the initial stub.

- Do not put empty roxygen lines such as `#'` between fields.
- Every documentation line starts with `#'` and follows valid roxygen2 syntax.
- Use explicit tags: `@title`, `@description`, one `@param` per argument,
  `@return`, and `@details`. Add `@examples`, `@seealso`, and `@export` when
  applicable.
- Document input structure, output type and fields, units, side effects,
  failure conditions, and important edge cases where relevant.
- Keep every roxygen line within the R line-width limit.
- Write the intended behaviour, not an incidental detail of the current body.

```r
#' @title Validate trait records
#' @description Validate records against the canonical trait contract.
#' @param data_source A data frame containing canonical trait columns.
#' @return The validated data frame with its input rows preserved.
#' @details The function aborts when required identifiers or units are missing.
#' @export
validate_trait_records <- function(data_source) {
  res <-
    data_source

  return(res)
}
```

## One focused test file per function

- Every function has one matching test file named
  `test-<function_name>.R` in the repository's established `testthat`
  directory.
- The test filename match is exact and mechanically auditable.
- Do not redefine or source the function under test from its test file; use the
  project test runner described in `.ai/r-environment.md`.
- Test the documented contract: valid behaviour, output structure and values,
  argument or data-contract failures, and relevant boundary cases.
- Test files follow the same one-function and local-helper restrictions. Small
  fixtures should normally be written directly in the test file; repeated
  fixture construction becomes a separately documented and tested helper when
  it is genuinely reusable.
- Use fully qualified namespaces and the immutable-object conventions from
  `.ai/r-coding.md` in tests as well as production functions.

## Strict test-driven development

Use this sequence for every new function:

1. Create only the matching function file with its complete roxygen2 contract
   and a stub body such as `cli::cli_abort("Not implemented.")`.
2. Write the complete matching test file from the documented contract.
3. Run the focused tests against the stub and verify that every test fails for
   the expected missing behaviour. Record the red result in the working notes
   or progress update.
4. Only after the red run, implement the function body.
5. Run the focused test file until it passes.
6. Run the complete repository test suite and any smallest relevant contract
   check.

Do not write a body before tests, and do not weaken tests merely to make an
implementation pass. A historical red step cannot be recreated after a
function already exists; never claim retroactive documentation or tests were
written test-first. Bring such functions under the contract, validate them,
and use strict TDD for all subsequent new behaviour.

For a behaviour change to an existing function, update the roxygen contract and
tests first, verify that the new or changed expectations fail against the old
body, and then edit the implementation.
