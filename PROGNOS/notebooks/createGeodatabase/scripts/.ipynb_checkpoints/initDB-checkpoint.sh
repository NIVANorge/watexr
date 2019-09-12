#!/bin/bash
read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.initializeStations() RETURNS void AS \$\$
BEGIN
    DROP TABLE IF EXISTS procedures.stations;                       
    CREATE TABLE procedures.stations( 
                                     sid SERIAL PRIMARY KEY,
                                     station_name varchar(80) UNIQUE,
                                     station_id INTEGER UNIQUE,
                                     longitude DOUBLE PRECISION,
                                     latitude DOUBLE PRECISION,
                                     geom geometry(POINT,3035),
                                     mask geometry(POLYGON,3035)
                                    );                       
  RETURN;
END; 
\$\$ LANGUAGE PLPGSQL;
EOM
echo $sql | psql -d geosvalbard

read -r -d '' sql <<-EOM
 CREATE OR REPLACE FUNCTION procedures.initializeSchema( _schema text  ) RETURNS void AS \$\$
BEGIN
    EXECUTE 'DROP SCHEMA IF EXISTS ' || _schema || ' CASCADE';
    EXECUTE 'CREATE SCHEMA ' || _schema;
RETURN;
END; 
\$\$ LANGUAGE PLPGSQL;  
EOM
echo $sql | psql -d geosvalbard

read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.initializeResultsSchema( _schema text  ) RETURNS void AS \$\$
BEGIN
    EXECUTE 'DROP SCHEMA IF EXISTS ' || _schema || ' CASCADE';
    EXECUTE 'CREATE SCHEMA ' || _schema;
    EXECUTE 'ALTER TABLE procedures.stations
    SET SCHEMA ' || _schema;
RETURN;
END; 
\$\$ LANGUAGE PLPGSQL;
EOM
echo $sql | psql -d geosvalbard

read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.addStations( _station_array station_info[] ) RETURNS void AS \$\$
DECLARE 
    element station_info;
BEGIN
    FOREACH element IN ARRAY _station_array
    LOOP
        IF element.mask = '' THEN
            INSERT INTO procedures.stations(station_name, station_id, longitude, latitude, mask) 
            VALUES( element.station_name,
                    element.station_id,
                    element.longitude,
                    element.latitude,
                    ST_Buffer(ST_Transform(ST_SetSRID( ST_MakePoint(
                    element.longitude,element.latitude) , element.epsg ), 3035), element.buffer)
            );
        ELSE
            INSERT INTO procedures.stations(station_name, station_id, longitude, latitude, mask) 
            VALUES( element.station_name,
                    element.station_id,
                    element.longitude,
                    element.latitude,
                    ST_Transform(ST_GeomFromText( element.mask, element.epsg), 3035));
        END IF;

    END LOOP;
    UPDATE procedures.stations
    SET geom=ST_Transform(ST_SetSRID(ST_MakePoint(longitude,latitude),element.epsg),3035);
    CREATE INDEX stations_idx ON procedures.stations USING GIST(geom);

RETURN;
END; 
\$\$ LANGUAGE PLPGSQL;
EOM
echo $sql | psql -d geosvalbard

read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.setExtentTable( _schema text, _table text ) RETURNS void AS \$\$
BEGIN
    EXECUTE 'ALTER TABLE ' || _schema || '.' || _table ||
             ' ADD COLUMN extent geometry(POLYGON, 3035);'; 

    EXECUTE 'UPDATE ' ||_schema || '.' || _table ||
            ' SET extent = St_Envelope(rast);';

    EXECUTE 'CREATE INDEX extent_'|| _table ||'_idx ON ' ||_schema || '.' || _table ||' USING GIST(extent);';        

RETURN;
END; 
\$\$ LANGUAGE PLPGSQL; 
EOM
echo $sql | psql -d geosvalbard

read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.generateBaseData(_schema text, st_rast text, st_shp text) RETURNS void AS \$\$
DECLARE
   resultsTableRast text = st_rast;
   resultsTableShp text = st_shp;
BEGIN
   EXECUTE 'DROP TABLE IF EXISTS bufferTable;';

   EXECUTE 'CREATE TEMP TABLE bufferTable AS 
            SELECT a.station_id,
                   a.station_name,
                   a.mask as limits,
                   a.geom as outlet 
            FROM ' || _schema || '.stations AS a;';

   EXECUTE 'CREATE INDEX buffer_idx ON bufferTable USING GIST(limits);';

   EXECUTE 'INSERT INTO ' || resultsTableRast || '(station_id, 
                                                   station_name, 
                                                   idx 
                                                   ) 
            SELECT buffer.station_id, 
                   buffer.station_name,
                   raster.rid 
                   FROM norway.flow_dir AS raster, bufferTable as buffer 
                   WHERE ST_Intersects(raster.extent, buffer.limits) ;'; 

   EXECUTE 'INSERT INTO ' || resultsTableShp || '(station_id, 
                                                  station_name, 
                                                  limits, 
                                                  outlet 
                                                  ) 
            SELECT buffer.station_id, 
                   buffer.station_name,
                   buffer.limits,
                   buffer.outlet
                   FROM bufferTable as buffer;';                                 

   EXECUTE 'CREATE VIEW basins.flow AS
                SELECT b.station_id,a.rast FROM norway.flow_dir as a
                INNER JOIN ' || resultsTableRast ||' AS b
                ON a.rid=b.idx;';

   EXECUTE 'CREATE VIEW basins.elevation AS
                SELECT b.station_id,a.rast FROM norway.el as a
                INNER JOIN ' || resultsTableRast ||' AS b
                ON a.rid=b.idx;';  

   EXECUTE ' WITH buffer AS (SELECT ST_Buffer(outlet,500) AS around FROM ' || resultsTableShp || ')
             UPDATE ' || resultsTableShp ||
           ' SET rivers = (SELECT ST_Union(ST_Intersection(b.around,a.geom)) 
             FROM norway.rivers AS a , buffer AS b
             WHERE ST_Intersects(b.around,a.geom));';

   EXECUTE 'UPDATE ' || resultsTableShp || 'SET outlet = ST_ClosestPoint(rivers,outlet);';
RETURN;
END;
\$\$ LANGUAGE PLPGSQL;   
EOM 
echo $sql | psql -d geosvalbard


read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.createDataTable( _schema text, _table text ) RETURNS void AS \$\$
DECLARE 
    st_rast text = _schema || '.' || _table || 'Rast';
    st_shp text = _schema || '.' || _table  || 'Shp';
    st text = _schema || '.' || _table ;
    stations text = _schema || '.stations';
    s text = _schema;
    t text = _table;
BEGIN
    EXECUTE 'CREATE TABLE ' || st_rast || '(sid SERIAL PRIMARY KEY, 
                                            station_id INTEGER REFERENCES ' || stations || '(station_id), 
                                            station_name varchar(80) REFERENCES ' || stations || '(station_name),
                                            idx INTEGER
                                            );'; 

     EXECUTE 'CREATE TABLE ' || st_shp || '(sid SERIAL PRIMARY KEY, 
                                            station_id INTEGER REFERENCES ' || stations || '(station_id), 
                                            station_name varchar(80) REFERENCES ' || stations || '(station_name),
                                            rivers geometry(MULTILINESTRINGZ, 3035 ), 
                                            limits geometry(POLYGON, 3035), 
                                            outlet geometry(POINT, 3035));';      


    EXECUTE 'SELECT procedures.generateBaseData('' '|| s ||' '','' '|| st_rast ||' '', '' '|| st_shp ||' '');';     
RETURN;
END; 
\$\$ LANGUAGE PLPGSQL;
EOM 
echo $sql | psql -d geosvalbard




read -r -d '' sql <<-EOM
CREATE OR REPLACE FUNCTION procedures.createResultsTable( _schema text, _table text) RETURNS void AS \$\$
 DECLARE 
     st_rast text = _schema || '.' || _table || 'Rast';
     st_shp text = _schema || '.' || _table || 'Shp';
     stations text = _schema || '.stations';
 BEGIN
     EXECUTE 'CREATE TABLE ' || st_rast || '(sid SERIAL PRIMARY KEY, station_id INTEGER, 
     station_name varchar(80),
     rast raster);';
     EXECUTE 'CREATE TABLE ' || st_shp || '(sid SERIAL PRIMARY KEY, station_id INTEGER, 
     station_name varchar(80),
     basin geometry(MULTIPOLYGON, 3035));';
 RETURN;
 END; 
\$\$ LANGUAGE PLPGSQL; 
EOM 
echo $sql | psql -d geosvalbard
