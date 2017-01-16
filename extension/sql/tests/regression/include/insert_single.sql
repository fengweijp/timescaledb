\set ON_ERROR_STOP 1

\ir create_single_db.sql

\c single

\set ECHO ALL
SELECT add_cluster_user('postgres', NULL);

SELECT set_meta('single' :: NAME, 'fakehost');--fakehost makes sure there is no network communication
SELECT add_node('single' :: NAME, 'fakehost');

CREATE TABLE PUBLIC."testNs" (
  "timeCustom" BIGINT NOT NULL,
  device_id TEXT NOT NULL,
  series_0 DOUBLE PRECISION NULL,
  series_1 DOUBLE PRECISION NULL,
  series_2 DOUBLE PRECISION NULL,
  series_bool BOOLEAN NULL
);
CREATE INDEX ON PUBLIC."testNs" (device_id, "timeCustom" DESC NULLS LAST) WHERE device_id IS NOT NULL;
CREATE INDEX ON PUBLIC."testNs" ("timeCustom" DESC NULLS LAST, series_0) WHERE series_0 IS NOT NULL;
CREATE INDEX ON PUBLIC."testNs" ("timeCustom" DESC NULLS LAST, series_1)  WHERE series_1 IS NOT NULL;
CREATE INDEX ON PUBLIC."testNs" ("timeCustom" DESC NULLS LAST, series_2) WHERE series_2 IS NOT NULL;
CREATE INDEX ON PUBLIC."testNs" ("timeCustom" DESC NULLS LAST, series_bool) WHERE series_bool IS NOT NULL;

SELECT * FROM create_hypertable('"public"."testNs"', 'timeCustom', 'device_id', hypertable_name=>'testNs', associated_schema_name=>'testNs' );

SELECT set_is_distinct_flag('"public"."testNs"', 'device_id', TRUE);

BEGIN;
\COPY "testNs" FROM 'data/ds1_dev1_1.tsv' NULL AS '';
COMMIT;

SELECT close_chunk_end(c.id)
FROM get_open_partition_for_key('testNs', 'dev1') part
INNER JOIN chunk c ON (c.partition_id = part.id);

INSERT INTO "testNs"("timeCustom", device_id, series_0, series_1) VALUES
(1257987600000000000, 'dev1', 1.5, 1),
(1257987600000000000, 'dev1', 1.5, 2),
(1257894000000000000, 'dev20', 1.5, 1),
(1257894002000000000, 'dev1', 2.5, 3);

INSERT INTO "testNs"("timeCustom", device_id, series_0, series_1) VALUES
(1257894000000000000, 'dev20', 1.5, 2);


CREATE TABLE chunk_closing_test(
        time       BIGINT,
        metric     INTEGER,
        device_id  TEXT
    );

-- Test chunk closing/creation
SELECT * FROM create_hypertable('chunk_closing_test', 'time', 'device_id', chunk_size_bytes => 10000);
INSERT INTO chunk_closing_test VALUES(1, 1, 'dev1');
INSERT INTO chunk_closing_test VALUES(2, 2, 'dev2');
INSERT INTO chunk_closing_test VALUES(3, 3, 'dev3');
SELECT * FROM chunk_closing_test;
SELECT * FROM chunk c
    LEFT JOIN chunk_replica_node crn ON (c.id = crn.chunk_id) 
    LEFT JOIN partition_replica pr ON (crn.partition_replica_id = pr.id)
    WHERE hypertable_name = 'public.chunk_closing_test';
