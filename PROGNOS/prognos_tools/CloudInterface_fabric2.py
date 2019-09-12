from subprocess import Popen, PIPE, CalledProcessError
import re
import platform
import shutil
import os.path
import fileinput
import time
from urllib.parse import urljoin
from IPython.display import clear_output, display
import collections

class CloudInterface(object):
        
    options = {'stdout': PIPE, 'stderr': PIPE, 'bufsize' : 1, 'universal_newlines' : True, 'shell' : False}
    system = 'Linux'
     
 
    def __init__(self,json_key,properties):
        #google cloud settings
        self.properties = properties
        self.pub  = ''
        self.credentials = service_account.Credentials.from_service_account_file(json_key)
        self.credentials_storage = service_account.Credentials.from_service_account_file('/home/jose-luis/Envs/gce_framework/code/keys/framework-storage.json')
        self.scoped_credentials = self.credentials.with_scopes(['https://www.googleapis.com/auth/cloud-platform'])
        self.storage_credentials = self.credentials_storage.with_scopes(['https://www.googleapis.com/auth/devstorage.full_control'])
        
        self.authed_session = AuthorizedSession(self.scoped_credentials)
        self.storage_session = AuthorizedSession(self.storage_credentials)
        os.environ['GOOGLE_APPLICATION_CREDENTIALS']='/home/jose-luis/Envs/gce_framework/code/keys/framework-storage.json'
        self.storage_client = storage.Client() #GOOGLE_APPLICATION_CREDENTIALS should have been set as an environment variable. This is shit but storage_client here can't seem to accept the path to the json file
        
    @staticmethod
    def callPopen(cmd,verbose=True,overwrite=False,additionalDisplay=''):
        with Popen(cmd.split(),**CloudInterface.options) as p:
            if verbose and not overwrite:
                for line in p.stdout:
                    print(line, end='')
            if verbose and overwrite:
                dq = collections.deque(maxlen=10)
                for line in p.stdout:
                    dq.append(line)
                    clear_output(wait=True)
                    print(additionalDisplay,''.join(list(dq)),sep='\n')
            for line in p.stderr:
                print(line, end='')
            if p.returncode != (0 or None):
                raise CalledProcessError(p.returncode, p.args)
                
    def isInstance(self):
        self.instanceExists=False
        self.ip=''
        with Popen('gcloud compute instances list'.split(),**CloudInterface.options) as p:
            for line in p.stdout:
                if re.match('^{instance}'.format(**self.machineInfo), line):
                    self.instanceExists=True
                    ip = line.strip().split()
                    self.ip = ip[-2]
            for line in p.stderr:
                print(line, end='')
            if p.returncode != (0 or None):
                raise CalledProcessError(p.returncode, p.args)
            return(self.instanceExists,self.ip)
    
    @staticmethod        
    def text_prepender(filename, text):
        with open(filename, 'r+') as f:
            content = f.read()
            f.seek(0, 0)
            f.write(text.rstrip('\r\n') + content)

    @staticmethod
    def replace(file,pattern,replace):
        fileinput.close()
        for line in fileinput.input(file, inplace=True):
            print( re.sub(pattern,
                          replace,
                          line.rstrip()
                          ) 
                 )

    def generateSSHKey(self):
        display('blabla')
#        p = Popen("echo 'yes' | ssh-keygen -t rsa -f {keyFile} -C {username} -N '' ".format(**self.properties),
#                      stdout=PIPE,
#                      shell=True,
#                      stderr=PIPE
#                       )
#        print(p.communicate())
        print(self.properties)    
#        with open (self.properties['pubKeyFile'],'r') as f:
#            self.pub = f.read().strip()
           
 
    @staticmethod   
    def is_number(s):
        try:
            float(s)
            return True
        except ValueError:
            return False     

    def instantiate(self,fabfile=''):
#         display(self.instantiationString)
        
        addSSHKeys = '''gcloud compute instances add-metadata {instance} --zone {region} --metadata-from-file ssh-keys={pubKeyFile}'''
        self.instanceExists,self.ip = self.isInstance()

        isStarted = False
        if self.instanceExists and self.ip == 'TERMINATED' :
            cmd = 'gcloud compute instances start {instance} --zone {region}'.format(**self.machineInfo)
            self.callPopen(cmd)
            self.instanceExists,self.ip = isInstance(instanceName)
            isStarted = True
            print("Instance already exists and was started")
            
        wasCreated=False
        if not self.instanceExists and not isStarted:
            print("Creating instance {instance}...".format(**self.machineInfo))
            self.callPopen(self.instantiationString)
            wasCreated=True
            if os.path.exists(self.machineInfo['keyDir']):
                shutil.rmtree(self.machineInfo['keyDir'])
            os.mkdir(self.machineInfo['keyDir'])
            self.generateSSHKey()
            self.text_prepender(self.machineInfo['pubKeyFile'], '{username}:'.format(**self.machineInfo) )
            cmd = addSSHKeys.format(**self.machineInfo)
            self.callPopen(cmd)
            self.replace(self.machineInfo['pubKeyFile'],"^{username}:".format(**self.machineInfo),"")
            self.ip=self.isInstance()[1]
#             self.callPopen('chmod +400 {}'.format(self.keyDir + '/' + self.username + '.pub'))
        if fabfile != '':
            self.fabfile = fabfile
        self.setFab()
        return self.ip


        
    def kill(self):
        cmd = '''gcloud beta compute instances delete {instance} --zone={region}'''.format(**self.machineInfo)
        Popen([cmd], shell=True,
             stdin=None, stdout=None, stderr=None, close_fds=True) #So we don't wait for output
    
    @staticmethod
    def isNumber(s):
        try:
            float(s)
            return True
        except ValueError:
            return False
