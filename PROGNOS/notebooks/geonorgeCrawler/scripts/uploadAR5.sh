#!/bin/bash
#Downloading shapefiles 
rm -rf dummy
mkdir dummy
gcsfuse jlg-bucket dummy
cp ./dummy/AR5-shapefiles.tar AR5.tar
fusermount -u ./dummy
tar -xf AR5.tar

#Uploading shapefile boundaries to database
echo "DROP SCHEMA IF EXISTS nibio CASCADE;" | psql -d geonorway
echo "CREATE SCHEMA nibio;" | psql -d geonorway
#echo "DROP TABLE nibio.boundaries;" | psql -d geonorway
echo "CREATE TABLE nibio.boundaries(geom geometry(Polygon, 3035),file varchar(128))" | psql -d geonorway
find ./shapefiles -type f -name "*KantUtsnitt*.shp" > shpList.txt
while IFS= read -r shape; do
  echo Processing $shape
  #Find projection from .prj file
  prjFile="${shape%.shp}.prj"  
  epsg=326$(grep -o 'UTM zone [0-9][0-9]' $prjFile | tail -c 3)
  landUseFile=`echo $shape | sed s/KantUtsnitt_KURVE/ArealressursFlate_FLATE/`

  #Actually putting the shapefile in the database. Changing projection to 3035
  shp2pgsql -s $epsg:3035 -I $shape nibio.dummy | psql -q -d geonorway 
  echo "INSERT INTO nibio.boundaries SELECT ST_MakeValid(ST_ConvexHull(ST_Union(geom))), '$landUseFile' FROM nibio.dummy;" | psql -d geonorway
  echo "DROP TABLE nibio.dummy;" | psql -d geonorway
done < shpList.txt   #<<<$(tail -n1 shpList.txt)
echo "CREATE INDEX nibio_boundaries_idx ON nibio.boundaries USING GIST (geom);" | psql -q -d geonorway 


#find ./data_AR5/ -type f -name '*.zip' | parallel --ungroup unzip {}
#rm -rf AR5-sos
#mkdir AR5-sos
#mv *.sos ./AR5-sos/

#cd AR5-sos
#wget https://github.com/espena/sosicon/blob/master/bin/cmd/linux64/sosicon?raw=true -O sosicon && chmod +x sosicon

#rm -rf shapefiles
#mkdir shapefiles
#find ./AR5-sos -type f -name "*.sos" | parallel ./AR5-sos/sosicon -2shp -d ./shapefiles  {}
#tar cfv -  ./shapefiles | gzip -9c > AR5-shapefiles.tar

#find ./ -type f -name "*.sos" | parallel --ungroup ./sosicon  -t KantUtsnitt -2psql -schema nibio \
#-table '{= s:\A[^\_]+\_[^\_]+\_::;s:\_[^\_]+\_[^\_]+\_[^\_]+\Z::;s:.*:\L$_:;s:[\_-]::g; =}' {} > /dev/null
#find ./ -type f -name "postgis_dump*.sql" -exec sed -i 's/CREATE SCHEMA nibio;/CREATE SCHEMA IF NOT EXISTS nibio;/g' {} \;
#rm *.sos
#find ./ -type f -name "postgis_dump*.sql" | parallel psql -d geonorway -f {}
#cd ..
#rm -r AR5-sos
