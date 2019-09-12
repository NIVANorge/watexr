# -*- coding: utf-8 -*-

from fabric.api import *
import os

#env.hosts = ['catchment.niva.no']
env.hosts=['35.246.195.89']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/prognosFimex/jose-luis'
env.roledefs={'stage':['35.246.195.89'],
             }

global path, file

#------------------------------------------------------------------------------------------------------------
#Setting up virtual machine with necessary dependencies to install fimex
    
def whoAmI():
    run('uname -a')
    run ('whoami')

def updateMachine():
    run('sudo apt-get update')

def installUtilities():
    run('yes | sudo apt-get install gcc g++ gfortran cmake make git libnetcdf-dev libnetcdff-dev netcdf-bin xmlstarlet tmux unzip python3-netcdf4 cdo parallel nco')
    
def installFimex():
    run('echo | sudo add-apt-repository ppa:met-norway/fimex && sudo apt-get update && yes | sudo apt-get install fimex-0.66-bin libfimex-dev fimex-0.66-dbg && sudo ln -s /usr/bin/fimex-0.66 /usr/bin/fimex')
        
def installGcsfuse():
    run('''export GCSFUSE_REPO=gcsfuse-`lsb_release -c -s` &&
           echo "deb http://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list &&
           curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - &&
           sudo apt-get update &&
           sudo apt-get install gcsfuse
        ''')   
#------------------------------------------------------------------------------------------------------------
#Getting netcdf files from metno openDAP server and processing them
def getFromList(fileList,cfg,path,outputFile,var):
    run('''rm -rf {}'''.format(path))
    run('''mkdir -p {}'''.format(path))
    put(fileList, path)
    put(cfg, path)
    put('getsubset.sh',path)
    run('''cd {} && chmod +x getsubset.sh && ./getsubset.sh '{}' '{}' '{}' '''.format(path,fileList,cfg,outputFile))
    run(''' cd {}/tmp && ncrcat *.nc ../../{}'''.format(path,outputFile))
    get(outputFile,'./DownloadedData/')
    

@task
def installDependencies():
    updateMachine.roles=('stage',)
    installUtilities.roles=('stage',)
    installFimex.roles=('stage',)
    installGcsfuse.roles=('stage',)
    execute(updateMachine)
    execute(installUtilities)
    execute(installFimex)

@task 
def getDataForCoordinates(fileList,cfg,path,outputFile,var):
    getFromList.roles=('stage',)
    execute(getFromList,fileList,cfg,path,outputFile,var)