# -*- coding: utf-8 -*-

from fabric.api import *
import os

env.hosts=['35.189.88.29']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/threddsBasin/jose-luis'
env.roledefs={'stage':['35.189.88.29'],
                'production': [''],  #                               
               }

def setup(file):
    script = os.path.basename(file)
    put(file,script)
    run('chmod +x {}'.format(script) )
    run('./{}'.format(script) )
#     run('rm {}'.format(script))

def getFile(out):
    get('results.txt',out)

def getSingleFile(file,out):
    get(file,out)
        
def upload(file):
    put(file,file)

def decrypt(encrypted_file,file):
    run('gcloud kms decrypt --location global --keyring jlg-keyring --key prognos-key --ciphertext-file {encrypted} --plaintext-file {plaintext}'.format(encrypted=encrypted_file,plaintext=file))
    
@task
def runScript(file,getResults=False,out='results.txt'):
    setup.roles=('stage',)
    execute(setup,file)
    if getResults:
        getFile.roles=('stage',)
        getFile(out)
    
  
@task
def downloadFromGeonorge(searchString='FKB-AR5',encrypted_credentials='geocredentials.yaml.encrypted'):
    #Uploading files with credentials to geonorge
    setup.roles=('stage',)
    execute(upload,encrypted_credentials)
    credentials='.'.join(encrypted_credentials.split('.')[:-1])
    decrypt.roles=('stage',)
    execute(decrypt,encrypted_credentials,credentials)
    execute(upload,'geonorge_scraping.py')
    
@task
def downloadFile(file,out):
    getSingleFile.roles=('stage',)
    getSingleFile(file,out)
    
    
