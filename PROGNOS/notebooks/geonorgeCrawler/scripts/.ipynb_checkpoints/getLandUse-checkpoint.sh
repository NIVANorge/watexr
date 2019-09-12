#!/bin/bash
#Getting land use on basin at a time
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION metno.get_land_use() RETURNS void AS \$\$ 
DECLARE
  r_row record;
  dynamic_query text := '';
BEGIN
  EXECUTE 'DROP TABLE IF NOT EXISTS metno.landuse;';
  EXECUTE 'CREATE TABLE metno.landuse(argrunnf varchar(2), arskogbon varchar(2), artreslag varchar(2),
                                      artype varchar(2), geom geometry(multipolygon,3035));'
  FOR r_row in SELECT * from metno.resultsshp
   LOOP
     EXECUTE 'INSERT INTO metno.landuse SELECT r_row.station_name,b.argrunnf,b.arskogsbon,b.artreslag,
                                               b.artype, ST_Intersection(r_row.basin.b) 
     dynamic_query := FORMAT(INSERT INTO metno.landuse 
                            SELECT %,b.argrunnf,b.arskogsbon,b.artreslag,
                                   b.artype, ST_Intersection(%,b.geom)
                            FROM nibio.landuse as b                   
                            WHERE ST_Intersects(%,b,geom);', r_row.station_name,r_row.basin,r_row.basin);
     RAISE NOTICE '%', dynamic_query;
     
   END LOOP;  
  RETURN;
END;
\$\$ LANGUAGE PLPGSQL;
EOM

y

echo "SELECT metno.get_land_use();" | psql -d geonorway;
