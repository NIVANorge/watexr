#!/bin/bash
#Getting all basins as geojson
IFS=$'\n' read -r -d '' SQL <<- EOM
   (SELECT json_build_object(
                        'type', 'FeatureCollection',
                        'features', json_agg(
                            json_build_object(
                                'type',       'Feature',
                                'label',      station_name,
                                'geometry',   ST_AsGeoJSON(ST_ForceRHR(St_Transform(basin,4326)))::json,
                                'properties', jsonb_set(row_to_json(resultsShp)::jsonb,'{basin}','0',false)
                                )
                            )
                       )
                        FROM metno.resultsShp)
EOM
echo "\COPY "$SQL" TO '/home/jose-luis/results.txt';" | psql -d geonorway

IFS=$'\n' read -r -d '' SQL <<-EOM
   (SELECT a.station_name, st_x(st_transform(a.outlet,4326)),
    st_y(st_transform(a.outlet,4326)), st_area(b.basin)/1000000
    FROM metno.demShp AS a
    INNER JOIN metno.resultsShp AS b 
    ON a.station_id = b.station_id)
EOM

echo "\COPY "$SQL" TO '/home/jose-luis/dummy.txt' DELIMITER ';';" | psql -d geonorway
echo "" >> results.txt
cat dummy.txt >> results.txt
rm dummy.txt
