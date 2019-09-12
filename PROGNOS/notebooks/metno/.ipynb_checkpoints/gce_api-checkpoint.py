from google.oauth2 import service_account
from google.auth.transport.requests import AuthorizedSession
from google.cloud import storage
import time
import os
import json
from subprocess import Popen, PIPE, CalledProcessError



class gce_api:
    
    URI = 'https://www.googleapis.com'
    
    CommonCalls = {'machineTypeList': 'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/machineTypes',
                   'imagesList':      'https://www.googleapis.com/compute/v1/projects/{project}/global/images',
                   'projectInfo':     'https://www.googleapis.com/compute/v1/projects/{project}',
                   'firewallList':    'https://www.googleapis.com/compute/v1/projects/{project}/global/firewalls',
                   'firewallResource':'https://www.googleapis.com/compute/v1/projects/{project}/global/firewalls/{firewallName}', 
                   'instances':       'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances',
                   'serialPort':      'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{instanceName}/serialPort',
                   'instanceInfo':    'https://www.googleapis.com/compute/v1/projects/{project}/zones/{zone}/instances/{instanceName}'
    }
    
    def __init__(self,json_key,properties):
        self.properties = properties
        self.credentials = service_account.Credentials.from_service_account_file(json_key)
        self.credentials_storage = service_account.Credentials.from_service_account_file('/home/jose-luis/Envs/gce_framework/code/keys/framework-storage.json')
        self.scoped_credentials = self.credentials.with_scopes(['https://www.googleapis.com/auth/cloud-platform'])
        self.storage_credentials = self.credentials_storage.with_scopes(['https://www.googleapis.com/auth/devstorage.full_control'])
        
        self.authed_session = AuthorizedSession(self.scoped_credentials)
        self.storage_session = AuthorizedSession(self.storage_credentials)
        os.environ['GOOGLE_APPLICATION_CREDENTIALS']='/home/jose-luis/Envs/gce_framework/code/keys/framework-storage.json'
        self.storage_client = storage.Client() #GOOGLE_APPLICATION_CREDENTIALS should have been set as an environment variable. This is shit but storage_client here can't seem to accept the path to the json file
    
   
    def waitUntilDone(func):
        def wrapper(self,*args,**kwargs):
            response = func(self,*args,**kwargs)
            if 'status' in response.keys() and response != None:
                while True: #response['status'] != "DONE":
                    display(response)
                    time.sleep(0.5)
                    response = func(self,*args,**kwargs)
                    
#                     display(response)
            else :
                response = None
            return response
        return wrapper
    
    def get(self,*args,**kwargs):
        self.method = "get"
        return self.selectRunType(*args,**kwargs)

    def post(self,*args,**kwargs):
        self.method = "post"
        return self.selectRunType(*args,**kwargs)
    
    def delete(self,*args,**kwargs):
        self.method = "delete"
        return self.selectRunType(*args,**kwargs)
    
    def selectRunType(self,*args,**kwargs):
        wait = kwargs.get('wait',False)
        kwargs.pop('wait',None)
        if not wait:
            result = self.runRequest(*args,**kwargs)
        else: 
            result = self.persistent(*args,**kwargs)
        return result
        
       
    def runRequest(self,*args,**kwargs):
        properties = kwargs.get('properties',None)
        if properties != None:
            self.properties = properties
        kwargs.pop('properties',None)
        call=gce_api.CommonCalls[args[0]].format(**self.properties)
        display(kwargs)
        response = getattr(self.authed_session,self.method)(call,**kwargs)
#         display(call)
        if response.status_code == 200:
            return json.loads(response.text)
        else:
            display("Response code was {}. It might not have worked".format(response.status_code))
            return None
        
    def request_storage(self,url, payload='None', method='get'):
        if payload is 'None':
            return getattr(self.storage_session,method)(url)
        else:
            return getattr(self.storage_session,method)(url,json=payload)        
        
        
    @waitUntilDone
    def persistent(self,*args,**kwargs):
        return self.runRequest(*args,**kwargs)
    
    def create_bucket(self,name):
        return self.storage_client.create_bucket(name)
    
    
    def generateSSHKey(self):
        p = Popen("echo 'yes' | ssh-keygen -t rsa -f {keyFile} -C {username} -N '' ".format(**self.properties),
                          stdout=PIPE,
                          shell=True,
                          stderr=PIPE
                           )
        print(p.communicate())

    
    