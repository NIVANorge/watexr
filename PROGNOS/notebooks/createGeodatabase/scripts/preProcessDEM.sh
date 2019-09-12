#!/bin/bash
n=`nproc`
rm fel.tif
rm flow_dir.tif
rm flow_acc.tif
rm streams.tif
rm river*
rm fa.tif

mpiexec -n $n pitremove -z svalbard20_3035_subset.tif -fel fel.tif
mpiexec -n $n d8flowdir -fel fel.tif -p flow_dir.tif
mpiexec -n $n aread8 -p flow_dir.tif -nc -ad8 flow_acc.tif
mpiexec -n $n threshold -ssa flow_acc.tif -thresh 800 -src streams.tif

cp flow_acc.tif fa.tif
gdal_edit.py fa.tif -unsetnodata
gdal_calc.py -A fa.tif --overwrite --outfile=river.tif --calc="A>2500 * logical_not(A==-9999)" --type Byte
gdal_translate -co "NBITS=1" river.tif bit_river.tif

rm fel.tif
rm flow_dir.tif
rm flow_acc.tif
rm streams.tif
rm river.tif
rm fa.tif
rm el.tif

gdal_calc.py -A svalbard20_3035_subset.tif -B bit_river.tif --outfile=el.tif --calc="A-B*10" 
mpiexec -n $n pitremove -z el.tif -fel fel.tif
mpiexec -n $n d8flowdir -fel fel.tif -p flow_dir.tif
mpiexec -n $n aread8 -p flow_dir.tif -nc -ad8 flow_acc.tif

rm bit_river.tif

cp flow_acc.tif fa.tif
gdal_edit.py fa.tif -unsetnodata
gdal_calc.py -A fa.tif --overwrite --outfile=river.tif --calc="A>2500 * logical_not(A==-9999)" --type Byte
gdal_translate -co "NBITS=1" river.tif bit_river.tif

saga_cmd imagery_segmentation "Grid Skeletonization" -INPUT bit_river.tif -METHOD 0 -INIT_METHOD 1 -INIT_THRESHOLD 0 -CONVERGENCE 0 -VECTOR "./river.shp"
