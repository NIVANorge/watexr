
DROP TABLE IF EXISTS test_dump;
CREATE TABLE test_dump AS
SELECT (ST_Dump(boundary)).path[1] as sid, (ST_Dump(boundary)).geom as geom
FROM metno.dataBoundaries;

CREATE INDEX dump_idx ON test_dump USING GIST(geom);

DROP TABLE IF EXISTS subdivided_geoms;
CREATE TABLE subdivided_geoms AS
SELECT ST_Subdivide(basin,32) AS geom
FROM metno.resultsShp
WHERE station_name ='Håelva';

CREATE INDEX subdivided_idx ON test_dump USING GIST(geom);

DROP TABLE IF EXISTS metno.areas;
CREATE TABLE metno.areas AS
WITH biglim AS (
    SELECT a.sid,ST_Area(ST_Intersection(b.geom, a.geom)) AS area FROM  test_dump AS a, subdivided_geoms AS b
    WHERE ST_Intersects(a.geom,b.geom)
) 
SELECT sid,SUM(area) as area FROM biglim
GROUP BY sid;
