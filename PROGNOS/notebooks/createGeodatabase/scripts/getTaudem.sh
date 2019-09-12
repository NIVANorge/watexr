#!/bin/bash
mkdir -p taudem
git clone https://github.com/dtarb/TauDEM.git --branch master --single-branch ./taudem
cd taudem/src
mkdir build && cd build
cmake ..
make
sudo make install
cd ~

#Installing lsdtopotools
#git clone https://github.com/LSDtopotools/LSDTopoTools2.git
#cd LSDTopoTools2
#sh lsdtt2_setup.sh

#wget https://raw.githubusercontent.com/LSDtopotools/LSDAutomation/master/LSDTopoToolsSetup.py
#python LSDTopoToolsSetup.py -id 1 -CE True

