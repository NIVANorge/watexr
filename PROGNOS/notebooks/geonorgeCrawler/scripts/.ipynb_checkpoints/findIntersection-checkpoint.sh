#!/bin/bash
echo "\COPY (SELECT DISTINCT a.file FROM metno.resultsshp as b, nibio.boundaries as a WHERE ST_INTERSECTS(geom,b.basin) ) TO '/home/jose-luis/upload.txt';" | psql -d geonorway
        
#Uploading the necessary files to the database
echo "DROP TABLE IF EXISTS nibio.landuse;" | psql -d geonorway
echo "DROP TABLE IF EXISTS nibio.landuse;" | psql -d geonorway
echo "CREATE TABLE nibio.landuse(argrunnf varchar(2), arskogbon varchar(2), artreslag varchar(2),artype varchar(2), geom geometry(multipolygon,3035));" | psql -q -d geonorway
while IFS= read -r shape; do
  echo Processing $shape
  #Find projection from .prj file
  prjFile="${shape%.shp}.prj"  
  epsg=326$(grep -o 'UTM zone [0-9][0-9]' $prjFile | tail -c 3)
  #Actually putting the shapefile in the database. Changing projection to 3035
  shp2pgsql -d -s $epsg:3035 $shape nibio.dummy | psql -q -d geonorway 
  echo "INSERT INTO nibio.landuse SELECT a.\"argrunnf  \",a.\"arskogbon \" ,a.\"artreslag \",a.\"artype    \",   ST_MakeValid(a.geom) FROM nibio.dummy as a;" | psql -q -d geonorway
done< upload.txt 

echo "DROP TABLE nibio.dummy;" | psql -q -d geonorway   
#echo "UPDATE nibio.landuse SET geom = ST_MakeValid(a.geom) FROM nibio.landuse AS a;" | psql -q -d geonorway
echo "CREATE INDEX nibio_landuse_idx ON nibio.landuse USING GIST (geom);" | psql -q -d geonorway 

echo "DROP TABLE IF exists metno.landuse;" | psql -q -d geonorway
echo "CREATE TABLE metno.landuse AS SELECT stations.station_name, lu.argrunnf, lu.arskogbon, lu.artreslag, lu.artype,st_intersection(stations.basin,lu.geom) as geom FROM metno.resultsshp AS stations, nibio.landuse AS lu WHERE ST_Intersects(stations.basin,lu.geom);" | psql -q -d geonorway

echo "ALTER TABLE metno.landuse ADD area double precision;" | psql -q -d geonorway
echo "UPDATE metno.landuse SET area = ST_Area(geom);" | psql -q -d geonorway
