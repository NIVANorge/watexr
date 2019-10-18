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
    keychain \
    nco \  
    proj-bin \
    proj-data \
    libproj-dev \
    libgdal-dev && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.2.0

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

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
    'rlist' \
    && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN R CMD javareconf

RUN R -e 'devtools::install_github(c("SantanderMetGroup/loadeR.java", "SantanderMetGroup/loadeR"))'

RUN R -e 'devtools::install_github("SantanderMetGroup/loadeR.ECOMS")'

RUN R -e 'devtools::install_github("SantanderMetGroup/transformeR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/downscaleR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/convertR")'

RUN R -e 'install.packages("vioplot",repos="http://cran.us.r-project.org")'

RUN R -e 'devtools::install_github("SantanderMetGroup/visualizeR")'

RUN R -e 'devtools::install_github("SantanderMetGroup/drought4R")'

# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    (test $TEST_ONLY_BUILD || julia -e 'import Pkg; Pkg.add("HDF5")') && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \ 
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter
    
    
RUN conda install --quiet --yes \
    'xlrd' \
    'cdsapi' \
    'lxml' \
    'psycopg2' \
    'shapely[vectorized]' \
    'pyyaml' \
    'parse' \
    'netCDF4' \
    'xarray' \
    'gmaps' \
    'nbgitpuller' \
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
    'dask_labextension' \
    'jupyterlab_code_formatter' \
    'jupyterlab-git' \
    'ipyleaflet' \
    'ipympl' \
    'pyproj' \
    'geopy' \
    'geopandas' \
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


# R-specific ======================================================================================
# Jupyter IR kernel and core R packages
USER root
RUN R -e "install.packages('IRkernel')" && \
    R --quiet -e "IRkernel::installspec(user=FALSE)"

RUN Rscript -e 'install.packages(c("littler", "docopt"))' && \ 
    ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r && \
    ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r && \
    ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r && \
    install2.r --error --ncpus 4 --deps TRUE devtools shiny rmarkdown formatR
 
# Install RStudio and Shiny Server
ENV RSTUDIO_VERSION 1.2.1335

RUN wget --quiet https://download2.rstudio.org/server/bionic/amd64/rstudio-server-${RSTUDIO_VERSION}-amd64.deb  && \
    gdebi -n rstudio-server-${RSTUDIO_VERSION}-amd64.deb && \ 
    rm rstudio-server-${RSTUDIO_VERSION}-amd64.deb && \
    wget -q "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.9.923-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f ss-latest.deb 

# Permissions
RUN mkdir -p /var/log/shiny-server && \
    mkdir -p /srv/shiny-server/apps && \
    chown shiny:shiny /var/log/shiny-server && \
    chmod -R ug+s /var/log/shiny-server && \
    chown -R shiny:shiny /srv/shiny-server && \
    chmod -R ug+s /srv/shiny-server && \
    adduser ${NB_USER} shiny && \
    mkdir -p /var/log/supervisor && \
    chown ${NB_USER} /var/log/supervisor

COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
RUN sed -i -e "s/\:HOME_USER\:/${NB_USER}/" /etc/shiny-server/shiny-server.conf

RUN chown ${NB_USER}:shiny -R /var/lib/shiny-server && \
    chown ${NB_USER}:shiny -R /var/log/shiny-server

# R environment vars  
ENV PATH="${PATH}:/usr/lib/rstudio-server/bin"
ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/server"
ENV R_LIBS_USER=/opt/R

RUN mkdir $R_LIBS_USER && \
    chown $NB_USER $R_LIBS_USER && \
    fix-permissions $R_LIBS_USER
    
# Make R-Studio server use the same directory
RUN echo "r-libs-user=/opt/R" >> /etc/rstudio/rsession.conf

# Java config
RUN R CMD javareconf


user $NB_UID