#!/bin/bash
startDir=$PWD
#Initializing schema for basin processing
read -r -d '' SQL <<- EOM
SELECT procedures.initializeStations();
SELECT procedures.addStations(ARRAY[row('Breidtjern',3555,310091,6558233,30000,32633,'')::station_info,row('Bæreia',4203,332507,6671439,30000,32633,'')::station_info,row('Flåte',110,183749,6561016,30000,32633,'')::station_info,row('Lyseren',137,282023,6621713,30000,32633,'')::station_info,row('Røysjø',5706,235553,6622350,30000,32633,'')::station_info,row('Store_Øyvannet',5742,224023,6620746,30000,32633,'')::station_info,row('Suluvatn',5755,234404,6617213,30000,32633,'')::station_info,row('Svanstulvatnet',6467,183396,6597009,30000,32633,'')::station_info,row('Tollreien',4076,350598,6686759,30000,32633,'')::station_info,row('Abborvatn',65082,1048961,7746229,30000,32633,'')::station_info,row('Ellentjørn',65124,1055026,7742086,30000,32633,'')::station_info,row('Gearddosjavri',54372,838700,7713886,30000,32633,'')::station_info,row('Gjøkvatn',65164,1056444,7735722,30000,32633,'')::station_info,row('Løken',65244,1082544,7777353,30000,32633,'')::station_info,row('Njukcajavri',55096,825856,7679839,30000,32633,'')::station_info,row('Vuorasjavri',2235,828110,7677330,30000,32633,'')::station_info]);
SELECT procedures.initializeResultsSchema('metno');
SELECT procedures.createDataTable('metno','dem');
SELECT procedures.createResultsTable('metno','results');
EOM
echo $SQL | psql -d geonorway
# Processing basin for station with station_id id     
for id in 3555 4203 110 137 5706 5742 5755 6467 4076 65082 65124 54372 65164 65244 55096 2235
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
