#!/bin/bash

yes | sudo apt-get install postgresql postgresql-contrib postgis

sudo createuser jose-luis
sudo createdb geosvalbard
sudo -u postgres echo "grant all privileges on database geosvalbard to jose-luis;" | psql

export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s`
echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

yes | sudo apt-get update
yes | sudo apt-get install gcsfuse
