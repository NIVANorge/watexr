# -*- coding: utf-8 -*-

from fabric.api import *
import os

#env.hosts = ['catchment.niva.no']
env.hosts=['35.246.173.27']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/vansjoBasin/jose-luis'
env.roledefs={'stage':['35.246.173.27'],
                'production': [''],  #                               
               }


#------------------------------------------------------------------------------------------------------------
def createTmpDir(path):
    run('rm -rf {0} && mkdir {0} && cd {0} && chmod a+w {0}'.format(path))


def generateSingleShp( user, password, db, schema, table, columnOutlet, path, fid ):
    print(path)
    put('getShp.sh', path  + 'getShp.sh') 
    run('chmod +x {}getShp.sh'.format(path))
    put('mpirun.sh', path  + 'mpirun.sh') 
    run('chmod +x {}mpirun.sh'.format(path))
    run('cd {0} && ./getShp.sh {0} {1} {2} {3} {4} {5} {6} {7}'.format(path, ' stations.csv ', "'" + user + "'", schema, table, columnOutlet, password,fid)) 
    
def pg2shp(user,password,db,schema,table,folder):
    run('rm -rf {0} && mkdir {0}'.format(folder))
    run('pgsql2shp -f {0}/{1} -h localhost -u {2} -P {3} {4} "select station_name,basin,st_area(basin) from {1}.{5}" '.format(folder,schema,user,password,db,table))


def getFile(folder):
    run('tar -cvf {0}.tar.gz {0}'.format(folder))
    get('{}.tar.gz'.format(folder), './{}.tar.gz'.format(folder))
    run('rm -r {}*'.format(folder))
  
#------------------------------------------------------------------------------------------------------------

    
@task 
def processSingleBasin(user, password, db, schema,table,columnRast,columnOutlet,path,fid):
    createTmpDir.roles=('stage',)
    generateSingleShp.roles=('stage',)
    execute(createTmpDir,path)
    execute(generateSingleShp, user, password, db, schema, table, columnOutlet, path,fid)
    
@task
def getShape(user,password,db,schema,table,folder):
    pg2shp.roles = ('stage',)
    getFile.roles = ('stage',)
    execute(pg2shp,user,password,db,schema,table,folder)
    execute(getFile,folder)
    