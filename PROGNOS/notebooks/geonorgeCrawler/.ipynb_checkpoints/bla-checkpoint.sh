#!/bin/bash
rm -rf dummy
mkdir dummy
gcsfuse jlg-bucket dummy
cp ./dummy/AR5.tar AR5.tar
tar -xf AR5.tar
fusermount -u ./dummy

find ./data_AR5/ -type f -name '*.zip' | parallel unzip {}
rm -rf AR5-sos
mkdir AR5-sos
mv *.sos ./AR5-sos/

cd AR5-sos
wget https://github.com/espena/sosicon/blob/master/bin/cmd/linux64/sosicon?raw=true -O sosicon && chmod +x sosicon
find ./ -type f -name "*.sos" | parallel ./sosicon  -2psql -schema nibio -table '{= s:\A[^\_]+\_[^\_]+\_::;s:\_[^\_]+\
_[^\_]+\_[^\_]+\Z:: =}'

