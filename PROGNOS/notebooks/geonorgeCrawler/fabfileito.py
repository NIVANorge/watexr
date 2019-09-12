# -*- coding: utf-8 -*-

from fabric.api import *
import os

env.hosts=['35.246.9.179']
env.user='jose-luis'
env.key_filename='/home/jose-luis/.ssh/AR5-basins/jose-luis'
env.roledefs={'stage':['35.246.9.179'],
                'production': [''],  #                               
               }

def setup(file):
    script = os.path.basename(file)
    put(file,script)
    run('chmod +x {}'.format(script) )
    run('./{}'.format(script) )
#     run('rm {}'.format(script))
        
def upload(file):
    put(file,file)

def decrypt(encrypted_file,file):
    run('gcloud kms decrypt --location global --keyring jlg-keyring --key prognos-key --ciphertext-file {encrypted} --plaintext-file {plaintext}'.format(encrypted=encrypted_file,plaintext=file))
    
@task
def runScript(file):
    setup.roles=('stage',)
    execute(setup,file)
    
  
@task
def downloadFromGeonorge(searchString='FKB-AR5',encrypted_credentials='geocredentials.yaml.encrypted'):
    #Uploading files with credentials to geonorge
    setup.roles=('stage',)
    execute(upload,encrypted_credentials)
    credentials='.'.join(encrypted_credentials.split('.')[:-1])
    decrypt.roles=('stage',)
    execute(decrypt,encrypted_credentials,credentials)
    execute(upload,'geonorge_scraping.py')
    
