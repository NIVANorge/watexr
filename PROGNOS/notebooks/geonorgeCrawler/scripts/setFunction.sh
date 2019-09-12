
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION nibio.getLandUse(_table text) RETURNS void AS \$\$ 
DECLARE
  r_row record;
  dynamic_query text := '';
  table_name text := _table;
BEGIN
  EXECUTE FORMAT('DROP TABLE IF EXISTS metno.%s;', table_name);
  EXECUTE FORMAT ('CREATE TABLE metno.%s AS SELECT a.station_name,a.%s,sum(a.area) as landcover,ST_Area(b.basin) as perc                    FROM metno.landuse AS a                    JOIN metno.resultsshp AS b ON a.station_name=b.station_name                    GROUP BY a.station_name,a.%s,b.basin                    ORDER BY station_name;', table_name, table_name,table_name);
  EXECUTE FORMAT ('UPDATE metno.%s SET perc = landcover/perc*100;', table_name);
  EXECUTE FORMAT ('ALTER TABLE metno.%s ADD COLUMN use text;', table_name);
  EXECUTE FORMAT ('UPDATE metno.%s SET use=(SELECT type_name FROM nibio.codes AS a  WHERE code=%s AND criteria=''%s'')', table_name,table_name,table_name);  
  RETURN;
END;
\$\$ LANGUAGE PLPGSQL;
EOM

echo $sql | psql -d geonorway
