-- Schema prototype: WITHOUT ROWID junction and value tables
--
-- Changes to the v1 schema (Data/SQL/make_tables.sql), applied by
--   13_build_schema_prototypes.R. Each junction or value table whose key
--   holds in the regional subset becomes a WITHOUT ROWID table with a
--   composite primary key, so the table itself is the index on that key.
--   Indexes that start with the first key column are dropped; indexes on
--   the other direction stay where vaultkeepr used them in question 3.
--   TaxonClassification gets its taxon_id as INTEGER PRIMARY KEY.
-- SampleTaxa keeps its v1 form: 15 (sample_id, taxon_id) pairs occur twice
--   in the subset (sPlotOpen plots that list a taxon twice).
-- Rules of these files: one statement per `;` at a line end, full-line
--   comments only, and directives `-- @omit <table>`,
--   `-- @drop_index <index>` and `-- @check <name>: <one-line query>`.

-- @drop_index idx_datasetreferences_dataset_id
CREATE TABLE "DatasetReferences"
(
  "dataset_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("dataset_id", "reference_id"),
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_datasetsourcetypereference_data_source_type_id
CREATE TABLE "DatasetSourceTypeReference"
(
  "data_source_type_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("data_source_type_id", "reference_id"),
  FOREIGN KEY ("data_source_type_id") REFERENCES "DatasetSourceTypeID" ("data_source_type_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_datasetsourcesreference_data_source_id
CREATE TABLE "DatasetSourcesReference"
(
  "data_source_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("data_source_id", "reference_id"),
  FOREIGN KEY ("data_source_id") REFERENCES "DatasetSourcesID" ("data_source_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_samplingmethodreference_sampling_method_id
CREATE TABLE "SamplingMethodReference"
(
  "sampling_method_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("sampling_method_id", "reference_id"),
  FOREIGN KEY ("sampling_method_id") REFERENCES "SamplingMethodID" ("sampling_method_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_samplereference_sample_id
CREATE TABLE "SampleReference"
(
  "sample_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("sample_id", "reference_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_datasetsample_dataset_id
CREATE TABLE "DatasetSample"
(
  "dataset_id" INTEGER NOT NULL,
  "sample_id" INTEGER NOT NULL,
  PRIMARY KEY ("dataset_id", "sample_id"),
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id")
) WITHOUT ROWID;

-- @drop_index idx_sampleuncertainty_sample_id
CREATE TABLE "SampleUncertainty"
(
  "sample_id" INTEGER NOT NULL,
  "iteration" INTEGER NOT NULL,
  "age" INTEGER,
  PRIMARY KEY ("sample_id", "iteration"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id")
) WITHOUT ROWID;

CREATE TABLE "TaxonClassification"
(
  "taxon_id" INTEGER PRIMARY KEY,
  "taxon_species" INTEGER,
  "taxon_genus" INTEGER,
  "taxon_family" INTEGER,
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_species") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_genus") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_family") REFERENCES "Taxa" ("taxon_id")
);

-- @drop_index idx_taxonreference_taxon_id
CREATE TABLE "TaxonReference"
(
  "taxon_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("taxon_id", "reference_id"),
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- The key order follows the reads by dataset and sample; vaultkeepr reaches
--   trait values by taxon, through idx_traitsvalue_taxon_id, which stays
CREATE TABLE "TraitsValue"
(
  "trait_id" INTEGER NOT NULL,
  "dataset_id" INTEGER NOT NULL,
  "sample_id" INTEGER NOT NULL,
  "taxon_id" INTEGER NOT NULL,
  "trait_value" REAL,
  PRIMARY KEY ("dataset_id", "sample_id", "trait_id", "taxon_id"),
  FOREIGN KEY ("trait_id") REFERENCES "Traits" ("trait_id"),
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id")
) WITHOUT ROWID;

-- @drop_index idx_traitsreference_trait_id
CREATE TABLE "TraitsReference"
(
  "trait_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("trait_id", "reference_id"),
  FOREIGN KEY ("trait_id") REFERENCES "Traits" ("trait_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;

-- @drop_index idx_abioticdata_sample_id
CREATE TABLE "AbioticData"
(
  "sample_id" INTEGER NOT NULL,
  "abiotic_variable_id" INTEGER NOT NULL,
  "abiotic_value" REAL,
  PRIMARY KEY ("sample_id", "abiotic_variable_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("abiotic_variable_id") REFERENCES "AbioticVariable" ("abiotic_variable_id")
) WITHOUT ROWID;

-- @drop_index idx_abioticdatareference_sample_id
CREATE TABLE "AbioticDataReference"
(
  "sample_id" INTEGER NOT NULL,
  "sample_ref_id" INTEGER NOT NULL,
  "distance_in_km" INTEGER,
  "distance_in_years" INTEGER,
  PRIMARY KEY ("sample_id", "sample_ref_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("sample_ref_id") REFERENCES "Samples" ("sample_id")
) WITHOUT ROWID;

-- @drop_index idx_abioticvariablereference_abiotic_variable_id
CREATE TABLE "AbioticVariableReference"
(
  "abiotic_variable_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("abiotic_variable_id", "reference_id"),
  FOREIGN KEY ("abiotic_variable_id") REFERENCES "AbioticVariable" ("abiotic_variable_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
) WITHOUT ROWID;
