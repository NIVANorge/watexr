##############################################################################################
# Modified from the jupyter/datascience-notebook Dockerfile here:
#
# https://github.com/jupyter/docker-stacks
#
# Extends the jupyter/scipy-notebook here:
#
# https://github.com/jupyter/docker-stacks/tree/master/scipy-notebook
#
# Includes the Oracle Instant Client 11.2R2 from here:
#
# https://github.com/sergeymakinen/docker-oracle-instant-client/blob/master/11.2/Dockerfile
#
# Plus additional Python modules customised for NIVA research.
##############################################################################################

ARG BASE_CONTAINER=jupyter/minimal-notebook:2ce7c06a61a1
FROM $BASE_CONTAINER

LABEL maintainer="James Sample <james.sample@niva.no>"

USER root

# Install the Oracle 11.2 Instant Client
ENV DEBIAN_FRONTEND noninteractive

ENV ORACLE_INSTANTCLIENT_MAJOR 11.2
ENV ORACLE_INSTANTCLIENT_VERSION 11.2.0.4.0
ENV ORACLE /usr/local/oracle
ENV ORACLE_HOME $ORACLE/lib/oracle/$ORACLE_INSTANTCLIENT_MAJOR/client64
ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:$ORACLE_HOME/lib
ENV C_INCLUDE_PATH $C_INCLUDE_PATH:$ORACLE/include/oracle/$ORACLE_INSTANTCLIENT_MAJOR/client64

RUN apt-get update && apt-get install -y libaio1 \
    curl rpm2cpio cpio \
    && mkdir $ORACLE && TMP_DIR="$(mktemp -d)" && cd "$TMP_DIR" \
    && curl -L https://github.com/sergeymakinen/docker-oracle-instant-client/raw/assets/oracle-instantclient$ORACLE_INSTANTCLIENT_MAJOR-basic-$ORACLE_INSTANTCLIENT_VERSION-1.x86_64.rpm -o basic.rpm \
    && rpm2cpio basic.rpm | cpio -i -d -v && cp -r usr/* $ORACLE && rm -rf ./* \
    && ln -s libclntsh.so.11.1 $ORACLE/lib/oracle/$ORACLE_INSTANTCLIENT_MAJOR/client64/lib/libclntsh.so.$ORACLE_INSTANTCLIENT_MAJOR \
    && ln -s libocci.so.11.1 $ORACLE/lib/oracle/$ORACLE_INSTANTCLIENT_MAJOR/client64/lib/libocci.so.$ORACLE_INSTANTCLIENT_MAJOR \
    && curl -L https://github.com/sergeymakinen/docker-oracle-instant-client/raw/assets/oracle-instantclient$ORACLE_INSTANTCLIENT_MAJOR-devel-$ORACLE_INSTANTCLIENT_VERSION-1.x86_64.rpm -o devel.rpm \
    && rpm2cpio devel.rpm | cpio -i -d -v && cp -r usr/* $ORACLE && rm -rf "$TMP_DIR" \
    && echo "$ORACLE_HOME/lib" > /etc/ld.so.conf.d/oracle.conf && chmod o+r /etc/ld.so.conf.d/oracle.conf && ldconfig \
    && rm -rf /var/lib/apt/lists/* && apt-get purge -y --auto-remove curl rpm2cpio cpio
   
# Install PostGIS
RUN apt-get update && \
    apt-get install -y --no-install-recommends postgis && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ffmpeg for matplotlib animation
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Rsync
RUN apt-get update && \
    apt-get install -y --no-install-recommends rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Tesseract, ImageMagick and Poppler for OCR
RUN apt-get update && \
    apt-get install -y tesseract-ocr imagemagick poppler-utils && \
    apt-get clean

RUN mv /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xmlout

# Install zip utils 
RUN apt-get update && \
    apt-get install -y zip gzip tar && \
    apt-get clean
    
# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    tzdata \
    gfortran \
    gcc && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_DEPOT_PATH=/opt/julia
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.1.1

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "f0a83a139a89a2ccf2316814e5ee1c0c809fca02cbaf4baf3c1fd8eb71594f06 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

USER $NB_UID

# Add Julia packages
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir
RUN julia -e 'import Pkg; Pkg.update()' && \
    julia -e "using Pkg; pkg\"add HDF5 Gadfly RDatasets IJulia InstantiateFromURL\"; pkg\"precompile\"" && \ 
    julia -e "using Pkg; pkg\"add LsqFit Distributions Plots Statistics Dierckx InstantiateFromURL\"; pkg\"precompile\"" && \ 
    # Use the same syntax as above to add additional Julia packages
    # Move kernelspec out of home
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter
   
# Update conda and set channel priorities
RUN conda update conda --quiet --yes && \
    conda config --system --remove channels defaults && \
    conda config --system --remove channels conda-forge && \
    conda config --system --prepend channels r && \
    conda config --system --prepend channels defaults

# R packages including IRKernel which gets installed globally.
RUN conda install -c r --quiet --yes \
    'r-base' \
    'r-bcp' \
    'r-essentials' \
    'r-visnetwork' \
    'rpy2' && \
    conda clean -ay && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER
    
# Some R packages are not available via conda's R channel
RUN R -e 'install.packages("bnlearn", repos="https://cran.uib.no/")' && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER
    
# Install Python 3 packages
RUN conda install -c defaults --quiet --yes \
    'cartopy' \
    'cx_Oracle' \
    'dask' \
    'fiona' \
    'flask' \
    'gdal' \
    'geopandas' \
    'geoviews' \
    'graphviz' \
    'h5py' \
    'holoviews' \
    'ipyparallel' \
    'ipython' \
    'ipywidgets' \
    'jupyter' \           
    'jupyterhub' \       
    'jupyterlab' \       
    'libgdal' \
    'matplotlib' \
    'netcdf4' \
    'networkx' \
    'nodejs' \
    'notebook' \
    'numpy' \
    'openpyxl' \
    'pandas' \
    'patsy' \
    'pillow' \
    'pomegranate ' \
    'proj4' \
    'psycopg2' \
    'pycryptodome' \
    'pygraphviz' \
    'pymc3' \
    'pyproj' \
    'pysal' \
    'python' \
    'qgrid' \
    'rasterio' \
    'scikit-image' \
    'scikit-learn' \
    'scipy' \
    'seaborn' \
    'simplegeneric' \
    'sqlalchemy' \
    'sqlite' \
    'statsmodels' \
    'tzlocal' \
    'xarray' \
    'xlrd' && \
    conda clean -ay

# Some packages are only available via conda-forge
# WARNING: mixing conda-forge with defaults can cause weird errors - use with caution!
# https://conda-forge.readthedocs.io/en/latest/conda-forge_gotchas.html
RUN conda install -c conda-forge --quiet --yes \
    'fbprophet' \
    'george' \
    'gitdb' \
    'plotnine' \
    'pyzmq' \
    'tornado' \
    'zeromq' && \
    conda clean -ay

# Some packages installed using PIP to avoid conflicts with packages already installed
RUN python -m pip install pip --upgrade
RUN python -m pip install \
    'altair' \
    'blackcellmagic' \
    'cmocean' \
    'corner' \
    'edward' \
    'emcee' \
    'folium' \
    'git+https://github.com/metno/pyromsobs.git' \
    'git+https://github.com/bjornaa/roppy.git@0aac255c20664621c65699ba716c70812637334d#egg=roppy' \
    'git+https://github.com/bjornaa/xroms.git' \
    'ipyleaflet' \
    'ipympl' \
    'jupyterlab-git' \
    'lmfit' \
    'nxpd' \
    'pyresample' \
    'python-docx' \
    'salem' \
    'utm' \
    'pdfminer.six' \
    'vega_datasets'
    
# Notebook extensions for JupyterLab
RUN jupyter labextension install jupyterlab_bokeh --no-build && \
    jupyter labextension install @jupyterlab/hub-extension --no-build && \
    jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build && \
    jupyter labextension install @jupyterlab/geojson-extension --no-build && \
    jupyter labextension install qgrid --no-build && \
    jupyter labextension install @pyviz/jupyterlab_pyviz --no-build && \
    jupyter labextension install @jupyterlab/vega3-extension --no-build && \
#    jupyter labextension install @jupyterlab/google-drive --no-build && \
    jupyter labextension install jupyterlab_voyager --no-build && \
    jupyter labextension install @jupyterlab/git --no-build && \
    jupyter labextension install jupyter-matplotlib --no-build && \
    jupyter labextension install jupyter-leaflet --no-build && \
    jupyter labextension install jupyterlab-spreadsheet --no-build && \
#    jupyter labextension install @jupyterlab/shortcutui --no-build && \
    jupyter lab clean && jupyter lab build && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER
    
RUN jupyter serverextension enable --py jupyterlab_git --sys-prefix && \
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter nbextension enable --py --sys-prefix ipyleaflet

# Install facets which does not have a pip or conda package at the moment
RUN cd /tmp && \
    git clone https://github.com/PAIR-code/facets.git && \
    cd facets && \
    jupyter nbextension install facets-dist/ --sys-prefix && \
    cd && \
    rm -rf /tmp/facets && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

# Download data packages for cartopy and salem
RUN python -c "import salem"
RUN python -c "import cartopy; shp = cartopy.io.shapereader.natural_earth(resolution='50m', category='cultural', name='admin_0_countries')"

USER root
   
EXPOSE 1521

# Install NivaPy3
WORKDIR /nivapy3
ADD . /nivapy3
RUN python setup.py install

WORKDIR $HOME

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_UID
