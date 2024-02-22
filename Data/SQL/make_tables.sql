CREATE TABLE "Datasets" (
  "dataset_id" INTEGER PRIMARY KEY,
  "dataset_name" TEXT,
  "data_source_id" INTEGER,
  "dataset_type_id" INTEGER,
  "data_source_type_id" INTEGER,
  "coord_long" REAL,
  "coord_lat" REAL,
  "sampling_method_id" INTEGER,
  FOREIGN KEY ("dataset_type_id") REFERENCES "DatasetTypeID" ("dataset_type_id"),
  FOREIGN KEY ("sampling_method_id") REFERENCES "SamplingMethodID" ("sampling_method_id"),
  FOREIGN KEY ("data_source_id") REFERENCES "DatasetSourcesID" ("data_source_id"),
  FOREIGN KEY ("data_source_type_id") REFERENCES "DatasetSourceTypeID" ("data_source_type_id")
);
CREATE TABLE "DatasetReferences" (
  "dataset_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "DatasetTypeID" (
  "dataset_type_id" INTEGER PRIMARY KEY,
  "dataset_type" TEXT
);
CREATE TABLE "DatasetSourceTypeID" (
  "data_source_type_id" INTEGER PRIMARY KEY,
  "dataset_source_type" TEXT
);
CREATE TABLE "DatasetSourceTypeReference" (
  "data_source_type_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("data_source_type_id") REFERENCES "DatasetSourceTypeID" ("data_source_type_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "DatasetSourcesID" (
  "data_source_id" INTEGER PRIMARY KEY,
  "data_source_desc" TEXT
);
CREATE TABLE "DatasetSourcesReference" (
  "data_source_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("data_source_id") REFERENCES "DatasetSourcesID" ("data_source_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "SamplingMethodID" (
  "sampling_method_id" INTEGER PRIMARY KEY,
  "sampling_method_details" TEXT
);
CREATE TABLE "SamplingMethodReference" (
  "sampling_method_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("sampling_method_id") REFERENCES "SamplingMethodID" ("sampling_method_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "Samples" (
  "sample_id" INTEGER PRIMARY KEY,
  "sample_name" TEXT,
  "sample_details" TEXT,
  "age" REAL,
  "sample_size_id" INTEGER,
  FOREIGN KEY ("sample_size_id") REFERENCES "SampleSizeID" ("sample_size_id")
);
CREATE TABLE "SampleReference" (
  "sample_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "DatasetSample" (
  "dataset_id" INTEGER,
  "sample_id" INTEGER,
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id")
);
CREATE TABLE "SampleUncertainty" (
  "sample_id" INTEGER,
  "iteration" INTEGER,
  "age" INTEGER,
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id")
);
CREATE TABLE "SampleSizeID" (
  "sample_size_id" INTEGER PRIMARY KEY,
  "sample_size" REAL,
  "description" TEXT
);
CREATE TABLE "SampleTaxa" (
  "sample_id" INTEGER,
  "taxon_id" INTEGER,
  "value" REAL,
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id")
);
CREATE TABLE "Taxa" (
  "taxon_id" INTEGER PRIMARY KEY,
  "taxon_name" TEXT
);
CREATE TABLE "TaxonClassification" (
  "taxon_id" INTEGER,
  "taxon_name_exact" INTEGER,
  "taxon_name_raw" INTEGER,
  "taxon_species" INTEGER,
  "taxon_genus" INTEGER,
  "taxon_family" INTEGER,
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_name_exact") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_name_raw") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_species") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_genus") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("taxon_family") REFERENCES "Taxa" ("taxon_id")
);
CREATE TABLE "TaxonReference" (
  "taxon_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "TraitsDomain" (
  "trait_domain_id" INTEGER PRIMARY KEY,
  "trait_domain_name" TEXT,
  "trait_domanin_description" TEXT
);
CREATE TABLE "Traits" (
  "trait_id" INTEGER PRIMARY KEY,
  "trait_domain_id" INTEGER,
  "trait_name" TEXT,
  FOREIGN KEY ("trait_domain_id") REFERENCES "TraitsDomain" ("trait_domain_id")
);
CREATE TABLE "TraitsValue" (
  "trait_id" INTEGER,
  "dataset_id" INTEGER,
  "sample_id" INTEGER,
  "taxon_id" INTEGER,
  "trait_value" REAL,
  FOREIGN KEY ("trait_id") REFERENCES "Traits" ("trait_id"),
  FOREIGN KEY ("dataset_id") REFERENCES "Datasets" ("dataset_id"),
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("taxon_id") REFERENCES "Taxa" ("taxon_id")
);
CREATE TABLE "TraitsReference" (
  "trait_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("trait_id") REFERENCES "Traits" ("trait_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "AbioticData" (
  "sample_id" INTEGER,
  "abiotic_variable_id" INTEGER,
  "value" REAL,
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("abiotic_variable_id") REFERENCES "AbioticVariable" ("abiotic_variable_id")
);
CREATE TABLE "AbioticVariable" (
  "abiotic_variable_id" INTEGER PRIMARY KEY,
  "abiotic_variable_name" TEXT,
  "abiotic_variable_unit" TEXT,
  "measure_details" TEXT
);
CREATE TABLE "AbioticVariableReference" (
  "abiotic_variable_id" INTEGER,
  "reference_id" INTEGER,
  FOREIGN KEY ("abiotic_variable_id") REFERENCES "AbioticVariable" ("abiotic_variable_id"),
  FOREIGN KEY ("reference_id") REFERENCES "References" ("reference_id")
);
CREATE TABLE "References" (
  "reference_id" INTEGER PRIMARY KEY,
  "reference_detail" TEXT
);
