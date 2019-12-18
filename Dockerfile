# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="José-Luis Guerrero <jlg@niva.com>"

# Set when building on Travis so that certain long-running build steps can
# be skipped to shorten build time.
ARG TEST_ONLY_BUILD

USER root

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    software-properties-common \
    libudunits2-dev \
    fonts-dejavu \
    gfortran \
    gcc \
    curl \
    libnetcdf-dev \
    libnetcdff-dev \
    netcdf-bin \
    python3-netcdf4 \  
    git \
    rsync \
    keychain \
    nco \  
    proj-bin \
    proj-data \
    gdal-bin \
    libproj-dev \
    libgdal-dev && \
    rm -rf /var/lib/apt/lists/*

USER $NB_UID

# R packages including IRKernel which gets installed globally.
RUN conda install --quiet --yes \
    'r-base=3.6.1' \
    'r-core' \
    'r-recommended' \
    'r-rjava' \
    'r-udunits2' \
    'r-tcltk2' \
    'r-caret=6.0*' \
    'r-crayon=1.3*' \
    'r-devtools=2.1*' \
    'r-forecast=8.7*' \
    'r-hexbin=1.27*' \
    'r-htmltools=0.3*' \
    'r-htmlwidgets=1.3*' \
    'r-irkernel=1.0*' \
    'r-nycflights13=1.0*' \
    'r-plyr=1.8*' \
    'r-randomforest=4.6*' \
    'r-rcurl=1.95*' \
    'r-reshape2=1.4*' \
    'r-rmarkdown=1.14*' \
    'r-rsqlite=2.1*' \
    'r-shiny=1.3*' \
    'r-sparklyr=1.0*' \
    'r-tidyverse=1.2*' \
    'rpy2=2.9*' \
    'r-rlist' \
    'r-bnlearn' \
    'r-corrplot' \
    'r-dismo' \
    'r-essentials' \
    'r-formatr' \
    'r-misctools' \
    'r-mumin' \
    'r-raster' \
    'r-rgdal' \
    'r-reticulate' \
    'r-sp' \
    'r-visnetwork' \
#    'xlrd' \
#    'cdsapi' \
#    'lxml' \
#    'psycopg2' \
#    'shapely[vectorized]' \
#    'pyyaml' \
#    'parse' \
#    'netCDF4' \
#    'xarray' \
#    'gmaps' \
#    'geopandas' \
#    'nbgitpuller' \
#    'dask_labextension' \
#    'jupyterlab_code_formatter' \
#    'jupyterlab-git' \
#    'ipyleaflet' \
#    'ipympl' \
#    'pyproj' \
#    'geopy' \
    && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN jupyter serverextension enable --py jupyterlab_git --sys-prefix && \
    jupyter serverextension enable --py jupyterlab_code_formatter && \
    jupyter serverextension enable --py --sys-prefix dask_labextension && \
    jupyter nbextension enable --py --sys-prefix ipyleaflet
    
    
RUN jupyter labextension install @jupyterlab/vega3-extension --no-build && \
   # jupyter labextension install @jupyterlab/git --no-build && \
    jupyter labextension install @jupyterlab/hub-extension --no-build && \
    jupyter labextension install jupyter-matplotlib --no-build && \
    jupyter labextension install jupyter-leaflet --no-build && \
    jupyter labextension install qgrid --no-build && \
    jupyter labextension install @jupyterlab/geojson-extension --no-build && \
    jupyter labextension install @pyviz/jupyterlab_pyviz --no-build && \
    jupyter labextension install jupyterlab-spreadsheet --no-build && \
    jupyter labextension install @jupyterlab/shortcutui --no-build && \
    jupyter labextension install dask-labextension --no-build && \
    jupyter labextension install @ryantam626/jupyterlab_code_formatter --no-build && \
    jupyter labextension install jupyterlab-drawio --no-build && \
    jupyter lab clean && \
    jupyter lab build && \
    jupyter lab clean
        
USER root

RUN rm -rf /tmp/*

RUN yes | sudo add-apt-repository ppa:met-norway/fimex

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fimex-1.3
    
USER $NB_UID

RUN pip install fabric2

RUN pip install google.api.core

RUN pip install google.cloud.storage

RUN pip install google.cloud


# Visual Studio Code ==============================================================================
# Based on https://github.com/radiant-rstats/docker
USER root
ENV CODE_SERVER="2.1692-vsc1.39.2"

RUN mkdir /opt/code-server && \
    cd /opt/code-server && \
    wget -qO- https://github.com/cdr/code-server/releases/download/${CODE_SERVER}/code-server${CODE_SERVER}-linux-x64.tar.gz | tar zxvf - --strip-components=1

# Locations to store vscode / code-server settings
ARG CODE_WORKINGDIR="/home/$NB_USER" 
ENV CODE_WORKINGDIR="${CODE_WORKINGDIR}" \
    CODE_USER_DATA_DIR="/home/$NB_USER/.niva_dst/share/code-server" \
    CODE_EXTENSIONS_DIR="/home/$NB_USER/.niva_dst/share/code-server/extensions" \
    CODE_BUILTIN_EXTENSIONS_DIR="/opt/code-server/extensions" \
    PATH=/opt/code-server:$PATH

# Make environment variable available from Rstudio
RUN echo "CODE_EXTENSIONS_DIR=${CODE_EXTENSIONS_DIR}" >> /etc/R/Renviron.site

# Setup for code-server
COPY jupyter_notebook_config.py /etc/jupyter/
COPY images/vscode.svg /opt/code-server/vscode.svg
COPY settings.json /opt/code-server/settings.json
COPY vsix/*.vsix /opt/code-server/extensions/

# Required for coenraads.bracket-pair-colorizer
# RUN npm i -g prismjs vscode vscode-uri escape-html

# Install VSCode extensions
RUN cd /opt/code-server/extensions/ && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "vscode-icons-team.vscode-icons" > /dev/null 2>&1 && \
#    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "coenraads.bracket-pair-colorizers" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "christian-kohler.path-intellisense-1.4.2.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "eamodio.gitlens-9.8.5.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "Ikuyadeu.r-1.0.9.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "ms-python.python-2019.6.24221.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "REditorSupport.r-lsp-0.1.0.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "VisualStudioExptTeam.vscodeintellicode-1.1.6.vsix" > /dev/null 2>&1 && \
    code-server --extensions-dir  $CODE_EXTENSIONS_DIR --install-extension "language-julia-0.12.3.vsix" > /dev/null 2>&1 && \
    cd $HOME    

# Watexr R packages ==============================================================================

RUN R CMD javareconf

RUN R -e 'devtools::install_github(c("SantanderMetGroup/loadeR.java", "SantanderMetGroup/loadeR"))'

RUN R -e 'devtools::install_github("SantanderMetGroup/loadeR.ECOMS")'

RUN R -e 'devtools::install_github("SantanderMetGroup/transformeR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/downscaleR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/convertR")'

RUN R -e 'install.packages("vioplot",repos="http://cran.us.r-project.org")'

RUN R -e 'devtools::install_github("SantanderMetGroup/visualizeR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/drought4R")'


user $NB_UID