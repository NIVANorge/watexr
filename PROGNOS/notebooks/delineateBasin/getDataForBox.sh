#!/bin/bash
n=$((`nproc` * 2))
rm -rf ./tmp
mkdir ./tmp
ulimit -n 1024
cat RR_type1_mini.txt | parallel --eta --jobs $n -u --no-notice "fimex -c box.cfg --input.file={} --output.file=./tmp/{/} > /dev/null 2>&1"
ncrcat ./tmp/*.nc RR_Langtjern.nc
rm -rf ./tmp
