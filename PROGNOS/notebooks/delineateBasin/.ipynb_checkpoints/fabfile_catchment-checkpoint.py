# -*- coding: utf-8 -*-

from fabric.api import *
import os

#env.hosts = ['catchment.niva.no']
env.hosts=['35.246.18.90']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/threddsBasin/jose-luis'
env.roledefs={'stage':['35.246.18.90'],
                'production': [''],  #                               
               }

#------------------------------------------------------------------------------------------------------------


def runScript(file,out):
#     output = os.path.basename(out)
    script = os.path.basename(file)
#     path = os.path.dirname(file)
    put(file,script)
    run('chmod +x {}'.format(script))
    run('./{}'.format(script))
    run('rm {}'.format(script))
    get('results.txt',out)
    run('rm results.txt') #The assumption is that the output of the script will always be saved to a file called results.txt
  
#------------------------------------------------------------------------------------------------------------

@task 
def processScript(file,out='results.txt'):
    runScript.roles=('stage',)
    runScript(file,out)
    
