#! /bin/bash
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.getElevation(_table text,_station text) RETURNS void AS \$\$ 
DECLARE
  table_name text := 'test.' || _table;
  station  text := _station;
BEGIN 
  EXECUTE 'DROP TABLE IF EXISTS subdivided;';
  EXECUTE FORMAT('CREATE TEMP TABLE subdivided AS 
                  SELECT ST_Subdivide(basin,256) AS geom 
                  FROM test.resultsshp AS a 
                  WHERE a.station_name=%s;', '''' || station || '''' );
  EXECUTE 'DROP INDEX IF EXISTS subdivided_idx';
  EXECUTE 'CREATE INDEX subdivided_idx ON subdivided USING GIST(geom)';
  
  EXECUTE 'DROP TABLE IF EXISTS elevData';
  EXECUTE FORMAT('CREATE TEMP TABLE elevData AS 
                  SELECT ST_DumpAsPolygons(rast) AS geo 
                  FROM test.resultsshp AS a, svalbard.el as b 
                  WHERE ST_Intersects(b.extent,a.basin) 
                  AND a.station_name=%s','''' || station || '''');
  EXECUTE 'DROP INDEX IF EXISTS elevData_idx;';
  EXECUTE 'CREATE INDEX elevData_idx ON elevData USING GIST(((elevData.geo).geom));';
  
  EXECUTE FORMAT('DROP TABLE IF EXISTS %s;',table_name);
  EXECUTE FORMAT('CREATE TABLE %s(id SERIAL PRIMARY KEY, elev DOUBLE PRECISION, geom GEOMETRY(POLYGON,3035));', table_name);
  EXECUTE FORMAT('INSERT INTO %s(elev,geom) 
                  SELECT DISTINCT (a.geo).val, (a.geo).geom 
                  FROM elevData AS a, subdivided AS b 
                  WHERE ST_Intersects(b.geom,(a.geo).geom);', table_name);
  
  EXECUTE 'DROP TABLE IF EXISTS toRemove;';
  EXECUTE 'CREATE TEMP TABLE toRemove(id INTEGER, geom GEOMETRY(POLYGON,3035));';
  EXECUTE FORMAT('WITH myLine AS (SELECT ST_Boundary(basin) AS geom FROM test.resultsshp AS a WHERE a.station_name=%s) 
                  INSERT INTO toRemove(id,geom)
                  SELECT a.id,a.geom 
                  FROM %s AS a, myLine AS b
                  WHERE ST_Intersects(a.geom,b.geom);', '''' || station || '''', table_name);
  
  EXECUTE 'DROP TABLE IF EXISTS intersections;';
  EXECUTE 'CREATE TEMP TABLE intersections AS
           SELECT a.id, SUM(ST_Area(ST_Intersection(a.geom,b.geom))) AS suma
           FROM subdivided AS b, toRemove AS a
           WHERE ST_Intersects(a.geom,b.geom)
           GROUP by a.id;';
  
  EXECUTE FORMAT('DELETE FROM %s AS A USING intersections AS b WHERE a.id=b.id AND b.suma < 0.1;', table_name);
  
  RETURN;
END;
\$\$ LANGUAGE PLPGSQL;
EOM

echo $sql | psql -d geosvalbard
