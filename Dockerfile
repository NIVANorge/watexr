# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

# Set when building on Travis so that certain long-running build steps can
# be skipped to shorten build time.
ARG TEST_ONLY_BUILD

USER root

# R pre-requisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    fonts-dejavu \
    gfortran \
    gcc \
    g++ \
    gfortran \
    curl \
    libnetcdf-dev \
    libnetcdff-dev \
    netcdf-bin \
    libxml2 \
    proj-bin \
    udunits-bin \
    git \
    && \
    rm -rf /var/lib/apt/lists/*
    
RUN git clone https://github.com/metno/mi-cpptest.git

RUN git clone https://github.com/metno/mi-programoptions.git

RUN git clone https://github.com/pybind/pybind11.git

RUN git clone https://github.com/HowardHinnant/date.git

