#!/bin/bash

#Querying and organizing daily netcdf gridded data from metno

LIST="$1"      #List of opendap files to query
CFG="$2"       #Configuration file 
SAVEFILE="$2"  #Name of the file that will store all data

NUMPROCESSORS=16

#Parallel queries to metno using OpenDAP and fimex
ulimit -n 50 && cat $LIST | parallel --wait --eta --jobs 0 -u --no-notice "fimex -c $CFG --input.file={} --output.file={/}"

#Concatenating all daily netcdf files to a single file. Getting rid of lat lon in degrees.
mkdir -p ./tmp/
mv *.nc ./tmp/
cd tmp #&& ls | parallel -u --jobs 0 --no-notice "fimex --extract.removeVariable=lat --extract.removeVariable=lon --input.file={} --output.file={}"
ncrcat *.nc $SAVEFILE
mv $SAVEFILE ../..
#cd tmp && cat $(eval "cdo cat {$LAST..1}.nc4 $SAVEFILE") && mv $SAVEFILE ..
#cd tmp && cdo cat -selname,Y,X,time,$VAR *.nc4 $SAVEFILE && mv $SAVEFILE ..

cd ..
#rm -r tmp