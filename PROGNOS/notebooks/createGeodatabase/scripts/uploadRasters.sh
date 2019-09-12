#!/bin/bash
echo "DROP SCHEMA svalbard CASCADE;" | psql -d geosvalbard
echo "CREATE SCHEMA svalbard;" | psql -d geosvalbard
#Putting rivers in database
shp2pgsql -I -d -s 3035 river.shp svalbard.rivers | psql -q -d geosvalbard
#Putting rasters in database
raster2pgsql -I -M -F -b 1 -r -s 3035 -d -t auto flow_dir.tif  svalbard.flow_dir | psql -q -d geosvalbard
raster2pgsql -I -M -F -b 1 -r -s 3035 -d -t auto svalbard20_3035_subset.tif  svalbard.el | psql -q -d geosvalbard

echo "SELECT procedures.setExtentTable('svalbard','flow_dir');" | psql -d geosvalbard
echo "SELECT procedures.setExtentTable('svalbard','el');" | psql -d geosvalbard

