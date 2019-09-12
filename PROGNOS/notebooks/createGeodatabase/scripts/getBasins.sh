#!/bin/bash
#Initializing schema for basin processing
read -r -d '' SQL <<- EOM
SELECT procedures.initializeStations();
SELECT procedures.addStations(ARRAY[row('Adventelva',1,15.82857,78.20388,50000,4326,'')::station_info,row('Endalselva',2,15.816164,78.200545,50000,4326,'')::station_info,row('Todalselva',3,15.86485,78.17167,50000,4326,'')::station_info,row('Bolterelva',4,15.98027,78.16333,50000,4326,'')::station_info,row('Foxelva',5,16.20452,78.15919,50000,4326,'')::station_info,row('AdventelvaSea',6,15.7447349,78.2272992,50000,4326,'')::station_info,row('DeGeerelva',7,16.31238,78.33822,50000,4326,'')::station_info,row('Sassenelva',8,16.86129,78.33203,50000,4326,'')::station_info,row('Gipsdalselva',9,16.57706,78.44082,50000,4326,'')::station_info,row('Ebbaelva',10,16.599771,78.70824,50000,4326,'')::station_info]);
SELECT procedures.initializeResultsSchema('test');
SELECT procedures.createDataTable('test','dem');
SELECT procedures.createResultsTable('test','results');
EOM
echo $SQL | psql -d geosvalbard
# Processing basin for station with station_id id     
for id in 1 2 3 4 5 6 7 8 9 10
do
  echo $id
  rm -rf Trash${id}
  mkdir Trash${id}
  cd Trash${id}

  #Exporting outlets from database as a shapefile
  pgsql2shp -g outlet -f stations${id} geosvalbard "select station_name, station_id, outlet  from test.demshp where station_id=${id}"
  
  #Computing basing using TauDEM. This produces a boolean tif where true means the cell is upstream of the outlet (i.e. part of the basin)
  n=`nproc`
  mpiexec -n $n gagewatershed -p "PG:dbname=geosvalbard schema=test table=flow column=rast where='station_id=${id}' mode=2" -o stations${id}.shp -gw watershed${id}.tif

  #Transforming upstream pixels to shapefile
  gdal_polygonize.py -f "ESRI Shapefile" watershed${id}.tif basin${id}.shp

  #Uploading the basin shapefile to the database
  shp2pgsql -S -d -s 3035 basin${id}.shp test.dummy | psql -d geosvalbard   
  
  #Placing the basin shapefile in the results table    
  read -r -d '' SQL <<- EOM
      INSERT INTO test.resultsShp(station_id,station_name,basin)
      SELECT b.station_id, b.station_name, ST_MakeValid(ST_Multi(ST_Union(a.geom)))
      FROM test.stations AS b, test.dummy AS a
      WHERE b.station_id=${id}
      GROUP BY station_id, station_name;
EOM
  echo $SQL | psql -d geosvalbard

  cd $startDir
  rm -rf Trash${id}
done

echo "DROP TABLE IF EXISTS test.dummy;" | psql -d geosvalbard

#Getting extent of basin and saving it to a txt file on the server
IFS=$'\n' read -r -d '' SQL <<- EOM
    (SELECT station_name,Box2D(ST_Transform(St_Buffer(St_Envelope(basin),2000),4326)) FROM test.resultsShp)
EOM
echo "\COPY "$SQL" TO '/home/jose-luis/results.txt' DELIMITER ';';" | psql -d geosvalbard
