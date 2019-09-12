#!/bin/bash
#Getting 20m DEM
wget http://publicdatasets.data.npolar.no/kartdata/NP_S0_DTM20.zip 
unzip *
rm *.zip
find ./ -name *.tif -exec mv {} svalbard20.tif \;

#Getting rivers
wget https://nedlasting.geonorge.no/api/download/order/a867cb2b-c1bb-43dc-9939-6f7365754d29/224b3a20-4572-4f79-ad77-440509dabae5-O svalbard.zip
unzip svalbard.zip && mv NP_S100_SOS svalbard

#Getting sosicon
wget https://github.com/espena/sosicon/blob/master/bin/cmd/linux64/sosicon?raw=true -O sosicon && chmod +x sosicon && mv sosicon ./svalbard/
