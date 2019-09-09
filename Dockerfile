#Container with the required dependencies for the watexr project
ARG BASE_CONTAINER=jupyter/datascience_notebook:82d1d0bf0867
FROM $BASE_CONTAINER

LABEL maintainer="José-Luis guerrero <jlg@niva.no>"

USER root

RUN apt-get update
RUN pip install --upgrade pip
RUN pip install pandas
RUN pip install netCDF4

USER $NB_UID

