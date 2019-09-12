#!/bin/bash
#Getting 20m DEM
#wget http://publicdatasets.data.npolar.no/kartdata/NP_S0_DTM20.zip 
#unzip *.zip
#rm *.zip
#find ./ -name *.tif -exec mv {} svalbard20.tif \;

#gdalwarp -s_srs EPSG:32633 -t_srs EPSG:3035 -r cubicspline -overwrite -srcnodata 0.0 -dstnodata -9999 svalbard20.tif svalbard20_3035.tif
#gdalwarp -s_srs EPSG:32633 -t_srs EPSG:4326 -r cubicspline -overwrite -srcnodata 0.0 -dstnodata -9999 svalbard20.tif svalbard20_4326.tif

rm -f svalbard20_3035_subset.tif
gdal_translate -projwin 4357221.184288694 6211145.126214671 4557221.184288694 6011145.126214671 svalbard20_3035.tif svalbard20_3035_subset.tif
#gdalwarp -s_srs EPSG:3035 -t_srs EPSG:4326 -r cubicspline -overwrite -srcnodata -3.4028234663852886e+38 -dstnodata -9999 svalbard20_3035_subset.tif svalbard20_4326_subset.tif
#gdal_translate -of "Envi" svalbard20_4326_subset.tif ./LSDTopoTools/Git_projects/LSDTopoTools_ChannelExtraction/driver_functions_ChannelExtraction/svalbard.bil
#gdal_translate -of "AAIGrid" svalbard20_4326_subset.tif ./LSDTopoTools/Git_projects/LSDTopoTools_ChannelExtraction/driver_functions_ChannelExtraction/svalbard.ascii

#Getting rivers
#wget https://nedlasting.geonorge.no/api/download/order/a867cb2b-c1bb-43dc-9939-6f7365754d29/224b3a20-4572-4f79-ad77-440509dabae5-O svalbard.zip
#unzip svalbard.zip #&& mv NP_S100_SOS svalbard

#Getting sosicon
#wget https://github.com/espena/sosicon/blob/master/bin/cmd/linux64/sosicon?raw=true -O sosicon && chmod +x sosicon && mv sosicon ./svalbard/
