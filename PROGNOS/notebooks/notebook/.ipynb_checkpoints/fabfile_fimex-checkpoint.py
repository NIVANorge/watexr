# -*- coding: utf-8 -*-

from fabric.api import *
import os

#env.hosts = ['catchment.niva.no']
env.hosts=['35.234.74.34']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/prognosFimex/jose-luis'
env.roledefs={'ncquery':['35.234.74.34'],
                'basin': ['catchment.niva.no'],  #                               
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
def getFromList(fileList,box,path,outputFile,var):
    run('''rm -rf {}'''.format(path))
    run('''mkdir -p {}'''.format(path))
    put(fileList, path)
    put('getsubset.sh',path)
    run('''cd {} && chmod +x getsubset.sh && ./getsubset.sh '{}' '{}' '{}' '{}' '''.format(path,fileList,box,outputFile,var))
    

#Getting netcdf files from metno openDAP server and processing them
def getFromOpenDAP(DAPLink,box,outputFile,var):
    run('''rm -rf {}'''.format('future'))
    run('''mkdir -p {}'''.format('future'))
    put('getFromOpenDAP.sh','future')
    run('''cd future && chmod +x getFromOpenDAP.sh && ./getFromOpenDAP.sh '{}' '{}' '{}' '{}'          
        '''.format(DAPLink,box,outputFile,var)
       )
    get('./future/future.nc','./future.nc')

@task
def installDependencies():
    updateMachine.roles=('ncquery',)
    installUtilities.roles=('ncquery',)
    installFimex.roles=('ncquery',)
    installGcsfuse.roles=('ncquery',)
    execute(updateMachine)
    execute(installUtilities)
    execute(installFimex)

@task 
def getDataForBasin(fileList,box,path,outputFile,var):
    getFromList.roles=('ncquery',)
    execute(getFromList,fileList,box,path,outputFile,var)
    
@task 
def getFuture(OpenDAPFile,box,outputFile,var):
    getFromOpenDAP.roles=('ncquery',)
    execute(getFromOpenDAP,OpenDAPFile,box,outputFile,var)