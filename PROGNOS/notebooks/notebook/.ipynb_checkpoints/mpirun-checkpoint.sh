#!/bin/bash

raster=$1
station=$2
watershed=$3
basin=$4

{
mpiexec -n 2 gagewatershed -p "$raster" -o $station.shp -gw $watershed.tif &> /dev/null
} || true

echo "Waiting"
while [ ! -f $watershed.tif ]
do
      sleep 1
done

echo "Still waiting!"

echo "Alive!"
gdal_polygonize.py -f "ESRI Shapefile" $watershed.tif $basin.shp #|| true
echo "Still alive!"


