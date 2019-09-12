#!/bin/bash
startDir=$PWD
#Initializing schema for basin processing
read -r -d '' SQL <<- EOM
SELECT procedures.initializeStations();
SELECT procedures.addStations(ARRAY[row('Håelva',1,5.5497054,58.6703701,50000,4326,'')::station_info]);
SELECT procedures.initializeResultsSchema('metno');
SELECT procedures.createDataTable('metno','dem');
SELECT procedures.createResultsTable('metno','results');
EOM
echo $SQL | psql -d geonorway
# Processing basin for station with station_id id     
for id in 1
do
  echo $id
  rm -rf Trash${id}
  mkdir Trash${id}
  cd Trash${id}

  #Exporting outlets from database as a shapefile
  pgsql2shp -g outlet -f stations${id} geonorway "select station_name, station_id, outlet  from metno.demshp where station_id=${id}"
  
  #Computing basing using TauDEM. This produces a boolean tif where true means the cell is upstream of the outlet (i.e. part of the basin)
  n=`nproc`
  mpiexec -n $n gagewatershed -p "PG:dbname=geonorway schema=metno table=flow column=rast where='station_id=${id}' mode=2" -o stations${id}.shp -gw watershed${id}.tif

  #Transforming upstream pixels to shapefile
  gdal_polygonize.py -f "ESRI Shapefile" watershed${id}.tif basin${id}.shp

  #Uploading the basin shapefile to the database
  shp2pgsql -S -d -s 3035 basin${id}.shp metno.dummy | psql -d geonorway    
  
  #Placing the basin shapefile in the results table    
  read -r -d '' SQL <<- EOM
      INSERT INTO metno.resultsShp(station_id,station_name,basin)
      SELECT b.station_id, b.station_name, ST_MakeValid(ST_Multi(ST_Union(a.geom)))
      FROM metno.stations AS b, metno.dummy AS a
      WHERE b.station_id=${id}
      GROUP BY station_id, station_name;
EOM
  echo $SQL | psql -d geonorway 

  cd $startDir
  rm -rf Trash${id}
done

echo "DROP TABLE IF EXISTS metno.dummy;" | psql -d geonorway

#Getting extent of basin and saving it to a txt file on the server
IFS=$'\n' read -r -d '' SQL <<- EOM
    (SELECT station_name,Box2D(ST_Transform(St_Buffer(St_Envelope(basin),2000),4326)) FROM metno.resultsShp)
EOM
echo "\COPY "$SQL" TO '/home/jose-luis/results.txt' DELIMITER ';';" | psql -d geonorway
