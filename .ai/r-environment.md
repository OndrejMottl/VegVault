# VegVault R Environment, Packages, and Tests

Canonical guidance for the R version, `renv` package management, artefact formats, and test runs in VegVault and the sibling producer repositories. Each repository is its own `renv` project with its own lockfile.

## R version

- The suite runs on R 4.6.2, selected machine-wide with `rig default`. Packages are built with Rtools45, which R 4.6 uses.
- The repositories share one R version. Move them to a new version together, on a dedicated branch in each repository, rather than pinning one repository to an older R.

## Lockfile and restore

- The lockfile is `renv/library_list.lock`, not `renv.lock`. Pass it explicitly to every `renv` call that reads or writes a lockfile.
- Sourcing `R/00_Config_file.R` runs `renv::restore(lockfile = here::here("renv/library_list.lock"))` and then attaches every package in `package_list`. Do not source it in a session whose library is being changed, and expect the first run after a lockfile change to install packages.
- Never edit, patch, reformat, or search-and-replace the lockfile or `renv/activate.R`.

## Changing packages

Adding, removing, or upgrading a package requires explicit user approval first. Then, from the repository root in a fresh R session:

1. Install with `renv::install()`. Prefer the CRAN release; use a GitHub source only for packages that are not on CRAN.
2. If scripts attach the package, add it to `package_list` in `R/00_Config_file.R`.
3. Snapshot with `renv::snapshot(lockfile = "renv/library_list.lock", type = "all")`.
4. Inspect `git diff -- renv/library_list.lock` and confirm that only the intended packages changed.
5. In a new session, confirm that `renv::restore(lockfile = "renv/library_list.lock")` reports a synchronised library and that the changed packages load.

Use `type = "all"`. The config attaches packages through `sapply(package_list, library, character.only = TRUE)`, which `renv`'s default implicit snapshot cannot detect, so an implicit snapshot silently drops packages such as `tidyverse`.

Other `renv` pitfalls seen in this suite:

- Upgrade `renv` itself only with a current `renv` from the user library, which writes `renv/activate.R` correctly. An older project `renv` running `renv::upgrade()` writes a broken `activate.R` and an unwanted root `renv.lock`.
- `phangorn` (a dependency of `taxize`) requires `BiocManager` and `BiocVersion` to be installed before `renv` allows a snapshot.
- Installing GitHub packages needs a GitHub token in `GITHUB_PAT`; without it the anonymous API limit fails the install.

## Artefact formats

- Producer artefacts are saved and loaded through `RUtilpol::save_latest_file()` and `RUtilpol::get_latest_file()`, which use `qs2` under the `.qs` file extension.
- Do not reintroduce the `qs` package. It is archived from CRAN and does not compile on R 4.6, and `qs2` cannot read files written by `qs`. Read `.qs` artefacts with `qs2::qs_read()`.

## Running R and tests

- Run scripts non-interactively with `Rscript` from the repository root, so the project `.Rprofile` activates `renv`.
- VegVault follows the project template (`.ai/analysis-structure.md`): function tests live in `R/Tests/testthat/test-<function_name>.R` and the full suite runs with `Rscript R/Tests/Run_tests.R`, which sources `R/___setup_project___.R`. For a focused run, source the setup and call `run_test_file()`. The rest of this section applies to the producer repositories until they are converted.
- Function tests live in `tests/testthat/test-<function_name>.R`. The runner `tests/testthat.R` sources every file under `R/Functions/` into a test environment and runs `tests/testthat/`; run the full suite with `Rscript tests/testthat.R` from the repository root. It does not source `R/00_Config_file.R`.
- For a focused run, source the function files the same way and call `testthat::test_file()` on the matching test file.
- A repository without `tests/testthat.R` gets that runner, copied from `VegVault-Trait_data`, before its first function test. Script-level integration checks that are not function tests, such as `tests/test_trait_v2_integration.R`, are run directly with `Rscript`.
