# VegVault Debugging Guidance

Reproduce and understand a problem before changing production code or data. Use the smallest safe experiment that distinguishes the likely causes.

## Workflow

1. Create a self-contained script in an ignored temporary location such as `Data/Temp/debug_<topic>.R` or the system temporary directory.
2. Run it with `Rscript` from the correct repository root in a clean session.
3. Load the project setup only when the problem requires full project context: `R/___setup_project___.R` in VegVault, `R/00_Config_file.R` in the producer repositories and the legacy VegVault scripts. Remember that it sources functions, attaches packages and resolves private storage, and that `R/00_Config_file.R` may also restore packages.
4. Use a small fixture, temporary SQLite database, or representative raster/data subset rather than live data.
5. Apply the smallest source change that fixes the confirmed cause.
6. Remove temporary files and run the narrowest reliable validation before broadening.

## Repository-specific cautions

- Do not use the live `path_to_vegvault` for a reproduction.
- Do not toggle overwrite flags, rerun Bchron models, redownload global data, or rebuild climate rasters merely to test a hypothesis.
- Missing ignored or licensed external data is an environment constraint, not automatically a regression.
- On Windows, inspect R output before interpreting a warning-driven non-zero exit as a failed pipeline.
- If a producer contract changes, validate the consumer boundary rather than only the producer's final save call.

## Validation ladder

Use, in order: parse/source check, focused function check, small data-contract check, disposable schema/import check, affected downstream script, and only then an authorized full workflow. State which levels were run and which were skipped.
