#!/bin/bash

#Creating store procedure that will create a dissolved polygon for every region uploaded in the previous step
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION nibio.get_all_shapes() RETURNS void AS
$$
DECLARE
  dynamic_query text = '';
  r_row         record;
BEGIN
  SET work_mem=10000000;
  DROP TABLE IF EXISTS nibio.all_shapes;
  CREATE TABLE nibio.all_shapes(station_name varchar, geom geometry);
  
  FOR r_row IN SELECT table_schema || '.' || split_part(table_name,'_',1) || '_polygon' as qualified_table_name,  
                      split_part(table_name,'_',1) || '_geom' as qualified_column_name,
                      split_part(table_name,'_',1 ) as  qualified_area_name
               FROM information_schema.tables
               WHERE table_schema = 'nibio'
                 AND split_part(table_name,'_',2)='polygon'
    LOOP
      dynamic_query := FORMAT('INSERT INTO nibio.all_shapes SELECT ''%s'', ST_UNION(ST_MakeValid(%s)) FROM %s;', 
                      r_row.qualified_area_name,
                      r_row.qualified_column_name,
                      r_row.qualified_table_name);
      RAISE NOTICE '%', dynamic_query;
      EXECUTE dynamic_query;
    END LOOP;
EOM

echo $sql

