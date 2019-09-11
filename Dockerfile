#Container with the required dependencies for the watexr project
ARG BASE_CONTAINER=jupyter/datascience-notebook:82d1d0bf0867
FROM $BASE_CONTAINER

LABEL maintainer="José-Luis guerrero <jlg@niva.no>"

RUN pip install --upgrade pip

USER root
RUN sudo apt-get update

USER $NB_UID
RUN pip install pandas
RUN pip install netCDF4
RUN pip install xarray
RUN pip install fabric2

RUN ls -lah
RUN echo $PWD
RUN rm -r work
RUN uname -a

COPY ~/Envs/watexr/notebooks/Notebooks /home/$NB_UID/Notebooks
