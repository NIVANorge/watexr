#!/bin/bash

sudo apt-get update

yes | sudo apt-get install postgresql postgresql-contrib postgis unzip git cmake g++ gcc libopenmpi-dev gdal-bin libgdal-dev python-gdal libfftw3-dev htop grass grass-dev libgdal-grass saga

export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

yes | sudo apt-get update
yes | sudo apt-get install gcsfuse

#Allowing ssh connection to server
sudo find /etc -name postgresql.conf -exec sudo sed -i s/.*listen_addresses.*/listen_addresses\ =\ \'*\'/g {} \;
sudo find /etc -name pg_hba.conf -exec sh -c "echo host all all 151.157.0.0/16 md5>> {}" \;
sudo service postgresql restart

#Creating user and geosvalbard database
sudo -u postgres createuser jose-luis
sudo -u postgres createdb geosvalbard
a=\\\"jose-luis\\\"
sudo su -c "psql -d geosvalbard -c \"grant all privileges on database geosvalbard to $a;\"" postgres
sudo su -c "psql -d geosvalbard -c \"alter user $a with superuser;\"" postgres
sudo su -c "psql -d geosvalbard -c \"alter user $a with password 'kakaroto';\"" postgres

#enable postgis on database
echo "ALTER DATABASE geosvalbard SET search_path=public, postgis, contrib, topology;" | psql -d geosvalbard
echo "ALTER DATABASE geosvalbard SET postgis.gdal_enabled_drivers = ENABLE_ALL;" | psql -d geosvalbard
echo "CREATE EXTENSION postgis CASCADE;" | psql -d geosvalbard
echo "CREATE EXTENSION postgis_topology CASCADE;" | psql -d geosvalbard
echo "ALTER DATABASE geosvalbard SET search_path=public, postgis, contrib, topology;" | psql -d geosvalbard
echo "ALTER DATABASE geosvalbard SET postgis.gdal_enabled_drivers = ENABLE_ALL;" | psql -d geosvalbard
echo "SELECT pg_reload_conf();" | psql -d geosvalbard
echo "SET postgis.enable_outdb_rasters TO True;" | psql -d geosvalbard
