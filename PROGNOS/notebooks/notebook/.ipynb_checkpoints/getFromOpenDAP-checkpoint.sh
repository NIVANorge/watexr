#!/bin/bash

#Querying and organizing daily netcdf gridded data from metno

LIST="$1"      #opendap file to query
COORD="$2"     #Extent to query as a postgis BOX
SAVEFILE="$3"  #Name of the file that will store all data
VARS="$4"       #Variable to extract from the daily files: not needed right now. Stores all variables be default

echo $LIST and $COORD and $SAVEFILE

#Extracting boundaries from BOX
echo $COORD
while read w s e n; do WEST="$w";SOUTH="$s"; EAST="$e";NORTH="$n"; done < <(echo $COORD | sed -e 's/[^0-9 ,.]//g' | awk -F '[ ,]' '{print  $1 " " $2 " " $3 " " $4}')

echo 'The boundaries are:'
echo $WEST
echo $SOUTH
echo $EAST
echo $NORTH

EXTRACT=""
while IFS=',' read -ra ADDR; do
     for i in "${ADDR[@]}"; do
         EXTRACT="$EXTRACT --extract.selectVariables=$i"
     done
done <<< $VARS

echo $EXTRACT

fimex --extract.reduceToBoundingBox.south=$SOUTH --extract.reduceToBoundingBox.north=$NORTH --extract.reduceToBoundingBox.west=$WEST --extract.reduceToBoundingBox.east=$EAST  --input.file=$LIST --output.file=$SAVEFILE $EXTRACT


