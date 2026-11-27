-- Secondary indexes of the build-engine benchmark output, created after
--   loading by every engine: the `tuple_links` index set of question 4,
--   plus the two primary-key duplicates that the reference check of
--   vaultkeepr 0.1.0 uses.
-- Rules: one statement per `;` at a line end and full-line comments only.

CREATE UNIQUE INDEX idx_datasets_dataset_id ON Datasets(dataset_id);
CREATE INDEX idx_datasets_dataset_type_id ON Datasets(dataset_type_id);
CREATE INDEX idx_datasets_data_source_id ON Datasets(data_source_id);
CREATE INDEX idx_datasets_data_source_type_id ON Datasets(data_source_type_id);
CREATE INDEX idx_datasets_coord_long_lat ON Datasets(coord_long, coord_lat);
CREATE INDEX idx_datasets_sampling_method_id ON Datasets(sampling_method_id);
CREATE INDEX idx_datasetreferences_reference_id ON DatasetReferences(reference_id);
CREATE INDEX idx_datasetsourcetypereference_reference_id ON DatasetSourceTypeReference(reference_id);
CREATE INDEX idx_datasetsourcesreference_reference_id ON DatasetSourcesReference(reference_id);
CREATE UNIQUE INDEX idx_samples_sample_id ON Samples(sample_id);
CREATE INDEX idx_samplereference_reference_id ON SampleReference(reference_id);
CREATE INDEX idx_datasetsample_sample_id ON DatasetSample(sample_id);
CREATE INDEX idx_sampletaxa_taxon_id ON SampleTaxa(taxon_id);
CREATE INDEX idx_sampletaxa_sample_id_taxon_id ON SampleTaxa(sample_id, taxon_id);
CREATE INDEX idx_traitsvalue_taxon_id ON TraitsValue(taxon_id);
CREATE INDEX idx_abioticvariablereference_reference_id ON AbioticVariableReference(reference_id);
