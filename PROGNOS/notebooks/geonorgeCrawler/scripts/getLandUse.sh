#!/bin/bash
#Getting land use on basin at a time
read -r -d '' sql <<-EOM
DROP TABLE IF EXISTS metno.landuse;
CREATE TABLE metno.landuse AS 
SELECT DISTINCT a.station_name, b.artype, b.argrunnf, b.arskogbon, b.artreslag, ST_Intersection(a.basin,b.geom) AS geom
FROM metno.resultsshp AS a
JOIN nibio.landuse as b ON ST_Intersects(a.basin,b.geom);

ALTER TABLE metno.landuse ADD area double precision;
UPDATE metno.landuse SET area = ST_Area(geom);

DROP TABLE IF EXISTS metno.coverage;
CREATE TABLE metno.coverage AS 
SELECT a.station_name, SUM(area) AS landuseArea
FROM metno.landuse as a 
GROUP BY a.station_name;

DROP TABLE IF EXISTS metno.coverage_percentage;
CREATE TABLE  metno.coverage_percentage AS
SELECT a.*, ST_Area(b.basin) as basinArea FROM metno.coverage AS a
JOIN metno.resultsshp AS b ON a.station_name = b.station_name;

ALTER TABLE metno.coverage_percentage ADD coverPercentage double precision;
UPDATE metno.coverage_percentage SET coverPercentage = landuseArea/basinArea*100.0;

DROP TABLE IF EXISTS nibio.codes;
CREATE TABLE nibio.codes(code varchar(2),type_name text, criteria text);
INSERT INTO nibio.codes (code, type_name, criteria) VALUES ('21', 'Fulldyrka jord','artype'), 
                               ('22', 'Overflardyrka jord','artype'),
                               ('23', 'Innmarksbeite','artype'), 
                               ('30', 'Skog','artype'), 
                               ('50', 'Åpen fastmark','artype'), 
                               ('60', 'Myr','artype'), 
                               ('70', 'Snøisbre','artype'), 
                               ('81', 'Ferskvann','artype'), 
                               ('82', 'Hav','artype'),                                ('12', 'Samferdsel','artype'), 
                               ('11', 'Bebygd','artype'), 
                               ('99', 'Ikke kartlagt','artype'), 
                               ('31', 'Barskog','artreslag'), 
                               ('32', 'Lauvskog','artreslag'), 
                               ('33', 'Blandingsskog','artreslag'), 
                               ('39', 'Ikke tresatt','artreslag'), 
                               ('98', 'Ikke relevant','artreslag'), 
                               ('99', 'Ikke registrert','artreslag'), 
                               ('15', 'Særs høy','arskogbon'), 
                               ('14', 'Høy','arskogbon'), 
                               ('13', 'Middels','arskogbon'), 
                               ('12', 'Lav','arskogbon'),                                ('11', 'Impediment','arskogbon'), 
                               ('98', 'Ikke relevant','arskogbon'), 
                               ('99', 'Ikke registrert','arskogbon'), 
                               ('44', 'Jorddekt','argrunnf'),                                ('45', 'Organiske jordlag','argrunnf'), 
                               ('43', 'Grunnlendt','argrunnf'), 
                               ('42', 'Fjell I dagen','argrunnf'), 
                               ('41', 'Blokkmark','argrunnf'), 
                               ('46', 'Konstruert','argrunnf'), 
                               ('98', 'Ikke relevant','argrunnf'), 
                               ('99', 'Ikke registrert','argrunnf');
                              
EOM

echo $sql | psql -q -d geonorway

