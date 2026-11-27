-- Secondary indexes of the bulk-load benchmark (21a_run_bulk_load.R),
--   created before or after loading: the reverse lookups from a gridpoint
--   to its links and from a position to its samples.
-- Rules: one statement per `;` at a line end and full-line comments only.

CREATE INDEX idx_positionlink_gridpoint_id ON PositionLink(gridpoint_id);
CREATE INDEX idx_sampleposition_position_id ON SamplePosition(position_id);
