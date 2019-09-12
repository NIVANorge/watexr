#! /bin/bash
echo "\COPY (SELECT * FROM metno.coverage_percentage) TO '/home/jose-luis/dummy.txt' DELIMITER ',';" | psql -d geonorway
