#! /bin/bash
echo "SELECT procedures.getElevation('EbbaelvaElev','Ebbaelva');" | psql -d geosvalbard
echo "\COPY (SELECT elev from test.EbbaelvaElev) TO '/home/jose-luis/dummy.txt' DELIMITER ',';" | psql -d geosvalbard
