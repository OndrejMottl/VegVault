# Tables behind the database design note

These are the summary tables that the numbers of `Database_design_2.0.0.md` come from, exported by `R/Analyses/90_Database_research/22_export_note_tables.R` from the git-ignored research folder `Data/Temp/Database_research/`. They hold counts, sizes, timings and distributions only. Each row below names the script that wrote the file and the run folder it came from, relative to the research folder.

| File | Script | Run folder |
| --- | --- | --- |
| `q1_v1_content/Scan_calibration__run_info.csv` | `05_calibrate_scan_rates.R` | `Scan_calibration` |
| `q1_v1_content/Scan_calibration__scan_rates.csv` | `05_calibrate_scan_rates.R` | `Scan_calibration` |
| `q1_v1_content/Scan_calibration__scan_runs.csv` | `05_calibrate_scan_rates.R` | `Scan_calibration` |
| `q1_v1_content/V1_candidate_boxes__box_content.csv` | `03_count_v1_candidate_boxes.R` | `V1_candidate_boxes` |
| `q1_v1_content/V1_candidate_boxes__box_links.csv` | `03_count_v1_candidate_boxes.R` | `V1_candidate_boxes` |
| `q1_v1_content/V1_candidate_boxes__boxes.csv` | `03_count_v1_candidate_boxes.R` | `V1_candidate_boxes` |
| `q1_v1_content/V1_candidate_boxes__run_info.csv` | `03_count_v1_candidate_boxes.R` | `V1_candidate_boxes` |
| `q1_v1_content/V1_full_scans__abiotic_values_per_variable.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__dataset_composition.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__dbstat_by_object.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__duplicate_dataset_names.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__duplicate_sample_names.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__foreign_key_check.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__gridpoint_ages.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__gridpoint_samples_without_values_or_links.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__link_distance_types.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__links_per_gridpoint.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__links_per_sample.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__sample_composition.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__samples_without_links.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_dbstat_by_object.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_foreign_key_check.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_link_distance_types.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_links_per_sample.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_sample_composition.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__seconds_tuples_all_sources.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__trait_samples_without_value.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__trait_values_per_sample.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__tuples_all_sources.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_full_scans__tuples_per_source.csv` | `06_scan_v1_full.R` | `V1_full_scans` |
| `q1_v1_content/V1_link_sample__cell_spacing.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__dataset_ages.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__distance_types.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__gridpoint_ages.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__gridpoint_samples.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__links_per_stratum.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__sample_composition.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_link_sample__step_seconds.csv` | `02_sample_v1_link_structure.R` | `V1_link_sample` |
| `q1_v1_content/V1_metadata__abiotic_variable.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__dataset_source_type.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__dataset_type.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__file_state.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__header_fields.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__pragmas.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__rowid_bounds.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__schema_comparison.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_metadata__version_control.csv` | `01_inspect_v1_metadata.R` | `V1_metadata` |
| `q1_v1_content/V1_subset_extraction__step_seconds.csv` | `04_extract_v1_subset.R` | `V1_subset_extraction` |
| `q1_v1_content/V1_subset_extraction__subset_foreign_key_check.csv` | `04_extract_v1_subset.R` | `V1_subset_extraction` |
| `q1_v1_content/V1_subset_extraction__subset_row_counts.csv` | `04_extract_v1_subset.R` | `V1_subset_extraction` |
| `q2_v1_build/V1_extrapolation__box_batches.csv` | `11_extrapolate_v1_gridpoint_stage.R` | `V1_extrapolation` |
| `q2_v1_build/V1_extrapolation__global_coarse.csv` | `11_extrapolate_v1_gridpoint_stage.R` | `V1_extrapolation` |
| `q2_v1_build/V1_extrapolation__stage06_inputs.csv` | `11_extrapolate_v1_gridpoint_stage.R` | `V1_extrapolation` |
| `q2_v1_build/V1_extrapolation__stage06_terms.csv` | `11_extrapolate_v1_gridpoint_stage.R` | `V1_extrapolation` |
| `q2_v1_build/V1_extrapolation__stage06_write_alternative.csv` | `11_extrapolate_v1_gridpoint_stage.R` | `V1_extrapolation` |
| `q2_v1_build/profiling_core__rprof_by_self.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_core__rprof_by_total.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_core__run_info.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_core__step_summary.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_core__trace_steps.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_core__validation_links.csv` | `08_profile_v1_gridpoints.R` | `Profiling/core/run_20261119_150146` |
| `q2_v1_build/profiling_full_box__rprof_by_self.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_full_box__rprof_by_total.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_full_box__run_info.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_full_box__step_summary.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_full_box__trace_steps.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_full_box__validation_links.csv` | `08_profile_v1_gridpoints.R` | `Profiling/alaska_yukon/run_20261119_153502` |
| `q2_v1_build/profiling_global__batch_runs.csv` | `09_profile_v1_global_batches.R` | `Profiling/global/run_20261119_154626` |
| `q2_v1_build/profiling_global__link_agreement.csv` | `09_profile_v1_global_batches.R` | `Profiling/global/run_20261119_154626` |
| `q2_v1_build/profiling_global__run_info.csv` | `09_profile_v1_global_batches.R` | `Profiling/global/run_20261119_154626` |
| `q2_v1_build/profiling_global__step_summary.csv` | `09_profile_v1_global_batches.R` | `Profiling/global/run_20261119_154626` |
| `q2_v1_build/profiling_global__trace_steps.csv` | `09_profile_v1_global_batches.R` | `Profiling/global/run_20261119_154626` |
| `q2_v1_build/profiling_kenai__rprof_by_self.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_kenai__rprof_by_total.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_kenai__run_info.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_kenai__step_summary.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_kenai__trace_steps.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_kenai__validation_links.csv` | `08_profile_v1_gridpoints.R` | `Profiling/kenai/run_20261119_145954` |
| `q2_v1_build/profiling_writes__in_query_runs.csv` | `10_benchmark_link_writes.R` | `Profiling/writes/run_20261119_155159` |
| `q2_v1_build/profiling_writes__read_runs.csv` | `10_benchmark_link_writes.R` | `Profiling/writes/run_20261119_155159` |
| `q2_v1_build/profiling_writes__run_info.csv` | `10_benchmark_link_writes.R` | `Profiling/writes/run_20261119_155159` |
| `q2_v1_build/profiling_writes__write_batches.csv` | `10_benchmark_link_writes.R` | `Profiling/writes/run_20261119_155159` |
| `q2_v1_build/profiling_writes__write_summary.csv` | `10_benchmark_link_writes.R` | `Profiling/writes/run_20261119_155159` |
| `q3_vaultkeepr/vaultkeepr_v1__index_usage.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/v1/run_20261119_170655` |
| `q3_vaultkeepr/vaultkeepr_v1__run_info.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/v1/run_20261119_170655` |
| `q3_vaultkeepr/vaultkeepr_v1__table_scans.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/v1/run_20261119_170655` |
| `q3_vaultkeepr/vaultkeepr_v1__vaultkeepr_info.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/v1/run_20261119_170655` |
| `q3_vaultkeepr/vaultkeepr_v1__workload_summary.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/v1/run_20261119_170655` |
| `q4_schema/prototype_queries__query_summary.csv` | `14_query_schema_prototypes.R` | `Prototypes/run_20261119_203020/queries_20261119_205950` |
| `q4_schema/prototype_queries__run_info.csv` | `14_query_schema_prototypes.R` | `Prototypes/run_20261119_203020/queries_20261119_205950` |
| `q4_schema/prototype_queries__version_probe.csv` | `14_query_schema_prototypes.R` | `Prototypes/run_20261119_203020/queries_20261119_205950` |
| `q4_schema/prototypes__build_files.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__build_summary.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__content_checks.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__object_sizes.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__run_info.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__schema_checks.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__size_projection.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__size_projection_by_table.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__size_projection_counts.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__type_probe_checks.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/prototypes__type_probe_sizes.csv` | `13_build_schema_prototypes.R and 16_project_schema_sizes.R` | `Prototypes/run_20261119_203020` |
| `q4_schema/v1_schema_checks__ages_by_dataset_type.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__coordinates_out_of_range.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__gridpoint_columns.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__gridpoint_references.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__key_duplicates.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__link_set_draw.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__link_set_draw_summary.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__mandatory_values.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__position_link_counts.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__position_sizes.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__run_info.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__sample_taxa_duplicates_by_source.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/v1_schema_checks__step_seconds.csv` | `15_check_v1_schema_candidates.R` | `V1_schema_checks/run_20261119_210338` |
| `q4_schema/vaultkeepr_on_prototypes__workload_summary.csv` | `12_profile_vaultkeepr_queries.R` | `Vaultkeepr/prototype_<prototype run>_<variant>` |
| `q5_engines/engines__comparison.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__distance_check.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__duckdb_versions.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__engine_summary.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__extrapolation_counts.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__extrapolation_steps.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__extrapolation_totals.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__links_against_v1.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__links_new_only_reasons.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__memory.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__run_info.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__run_status.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/engines__steps.csv` | `17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and 19_compare_links_with_v1.R` | `Engines/run_20261120_090633` |
| `q5_engines/full_links_v1__compare_with_v1_by_stratum.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__counts.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__links_by_latitude_band.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__links_per_position.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__new_links_other_reason.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__run_info.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__steps.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q5_engines/full_links_v1__v1_links_not_reproduced.csv` | `20_run_full_size_links.R` | `Full_links/run_20261120_092514_v1` |
| `q6_bulk_load/bulk_load__analyze.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__checksums.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__compression.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__files.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__run_info.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__run_status.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__source_info.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__steps.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__vacuum.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/bulk_load__variant_summary.csv` | `21_benchmark_bulk_load.R` | `Bulk_load/run_20261120_094152` |
| `q6_bulk_load/chunk_size__chunk_check.csv` | `20_run_full_size_links.R (positions)` | `Full_links/run_<time>_positions_chunk<n>` |
| `q6_bulk_load/chunk_size__run_info.csv` | `20_run_full_size_links.R (positions)` | `Full_links/run_<time>_positions_chunk<n>` |
| `q6_bulk_load/chunk_size__steps.csv` | `20_run_full_size_links.R (positions)` | `Full_links/run_<time>_positions_chunk<n>` |
