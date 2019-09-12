#!#!/bin/bash

#Creating store procedure that will create a dissolved polygon for every region uploaded in the previous step
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION nibio.get_all_shapes() RETURNS void AS \$\$ 
DECLARE
  dynamic_query text := '';
  r_row         record;
  counter integer := 0;
BEGIN
  DROP TABLE IF EXISTS nibio.all_shapes;
  CREATE TABLE nibio.all_shapes(area_name varchar, geom geometry);
  FOR r_row in SELECT table_schema || '.' || split_part(table_name,'_',1) || '_linestring' as qualified_table_name,
                      split_part(table_name,'_',1) || '_geom' as qualified_column_name,
                      split_part(table_name,'_',1) AS qualified_area_name
    FROM information_schema.tables
    WHERE table_schema = 'nibio'
    AND split_part(table_name,'_',2) = 'linestring'
      LOOP
        counter := counter + 1;
        dynamic_query := FORMAT('INSERT INTO nibio.all_shapes SELECT ''%s'', ST_CONVEXHULL(ST_UNION(%s)) FROM %s',
                                 r_row.qualified_area_name,
                                 r_row.qualified_column_name,
                                 r_row.qualified_table_name);
        RAISE NOTICE '%->%', counter,dynamic_query;
        EXECUTE dynamic_query;
      END LOOP;
  RETURN;
END;
\$\$ LANGUAGE PLPGSQL;
EOM

echo $sql | psql -d geonorway


#And actually finding out the boundaries of each region:
echo "SELECT nibio.get_all_shapes();" | psql -d geonorway
