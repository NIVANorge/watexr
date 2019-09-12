from subprocess import Popen, PIPE, CalledProcessError
import re
import platform
import shutil
import os.path
import fileinput
#import ipywidgets as widgets
import time
import psycopg2 as db
import psycopg2.extras
from psycopg2 import sql
from psycopg2.extensions import AsIs
import requests
from urllib.parse import urljoin
from IPython.display import clear_output, display

class basin:
        
    options = {'stdout': PIPE, 'stderr': PIPE, 'bufsize' : 1, 'universal_newlines' : True, 'shell' : False}
    system = 'Linux'
#     fabCatchment = 'fabfile_catchment.py'
    
   
    def __init__(self,instance,username,region,keyDir,machineType):
        self.instance = instance
        self.username = username
        self.region = region
        self.keyDir = keyDir
        self.instanceExists = False
        self.machineType = machineType
        self.fabfile = 'fabfile.py'
        basin.system = platform.system()
        if (basin.system == 'Windows'):
            basin.options['shell'] = True
            #Packages required to generate ssh keys in windows
            from cryptography.hazmat.primitives import serialization as crypto_serialization
            from cryptography.hazmat.primitives.asymmetric import rsa
            from cryptography.hazmat.backends import default_backend as crypto_default_backend
            

    def callPopen(self,verbose=True,overwrite=False):
        cmd = self.cmd
        with Popen(cmd.split(),**basin.options) as p:
            if verbose and not overwrite:
                for line in p.stdout:
                    print(line, end='')
            if verbose and overwrite:
                for line in p.stdout:
                    clear_output(wait=True)
                    display(line)
            for line in p.stderr:
                print(line, end='')
            if p.returncode != (0 or None):
                raise CalledProcessError(p.returncode, p.args)


    def isInstance(self):
        self.instanceExists=False
        self.ip=''
        with Popen('gcloud compute instances list'.split(),**basin.options) as p:
            for line in p.stdout:
                if re.match('^{}'.format(self.instance), line):
                    self.instanceExists=True
                    ip = line.strip().split()
                    self.ip = ip[4]
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
        if basin.system == 'Windows':
            key = rsa.generate_private_key(
                        backend=crypto_default_backend(),
                        public_exponent=65537,
                        key_size=2048
                        )
            private_key = key.private_bytes(
                        crypto_serialization.Encoding.PEM,
                        crypto_serialization.PrivateFormat.TraditionalOpenSSL,
                        crypto_serialization.NoEncryption()
                        )
            public_key = key.public_key().public_bytes(
                        crypto_serialization.Encoding.OpenSSH,
                        crypto_serialization.PublicFormat.OpenSSH
                        )
            public_file = os.path.join(savePath,self.username + '.pub')
            private_file = os.path.join(savePath,self.username)
            text_file = open(public_file, "w")
            text_file.write(public_key.decode('utf-8') + ' ' + self.username)
            text_file.close()
            text_file = open(private_file, "w")
            text_file.write(private_key.decode('utf-8'))
            text_file.close()
            print('Successfully created key pair')
        if basin.system == 'Linux':
            p = Popen("echo 'yes' | ssh-keygen -t rsa -f {0}/{1} -C {1} -N '' ".format(self.keyDir,self.username),
                      stdout=PIPE,
                      shell=True,
                      stderr=PIPE
                       )
            print(p.communicate())  
           
 
    @staticmethod   
    def is_number(s):
        try:
            float(s)
            return True
        except ValueError:
            return False

    

    def instantiate(self,fabfile=''):
        instanceCmd = '''
        gcloud beta compute --project=nivacatchment instances create {0}
        --zone={1} 
        --machine-type={2} 
        --image=geonorway 
        --image-project=nivacatchment 
        --boot-disk-size=50GB 
        --boot-disk-type=pd-ssd 
        --boot-disk-device-name={0}
        --tags=http-server,https-server,postgres
        '''.format(self.instance,self.region,self.machineType)
        

        listInstances = '''gcloud compute instances list'''

        addSSHKeys = '''gcloud compute instances add-metadata {} --zone {} --metadata-from-file ssh-keys={}'''

        if (basin.system == 'Linux'):
            self.keyDir = ('/home/jose-luis/.ssh/{}'.format(self.keyDir))

        if (basin.system == 'Windows'):
            self.keyDir = ('c:/Users/jose_luis_guerrero/{}'.format(self.keyDir))

       
        self.instanceExists,self.ip = self.isInstance()

#         if self.instanceExists:
#             print('The ip of {} is {}'.format(self.instance,self.ip) )

        isStarted = False
        if self.instanceExists and self.ip == 'TERMINATED' :
            self.cmd = 'gcloud compute instances start {} --zone {}'.format(self.instance,self.region)
            self.callPopen()
            self.instanceExists,self.ip = isInstance(instanceName)
            isStarted = True
            print("Instance already exists and was started")
            
        wasCreated=False
        if not self.instanceExists and not isStarted:
            print("Creating instance {}...".format(self.instance))
            self.cmd = instanceCmd
            self.callPopen()
            wasCreated=True
            if os.path.exists(self.keyDir):
                shutil.rmtree(self.keyDir)
            os.mkdir(self.keyDir)
            self.generateSSHKey()
            keyFile = os.path.join(self.keyDir,self.username + '.pub')
            self.text_prepender('{}/{}.pub'.format(self.keyDir,self.username), '{}:'.format(self.username) )
            self.cmd = addSSHKeys.format(self.instance,self.region,self.keyDir + '/{}.pub'.format(self.username))
            self.callPopen()
            #callPopen('sed -i s/^{0}:// {1}/{0}.pub'.format(username,keyDir))
            self.replace(keyFile,"^{}:".format(self.username),"")
            self.ip=self.isInstance()[1]
                #callPopen('chmod 400 {}'.format(keyDir))
        
        if fabfile != '':
            self.fabfile = fabfile
        
        self.setFab()
        return self.ip

    def setFab(self):
        if basin.system == 'Linux':
            self.cmd = "sed -i s/^env\.hosts.*/env.hosts=\['{}']/ {}".format(self.ip,self.fabfile)
            self.callPopen()
            self.cmd = "sed -i s/^env\.user.*/env.user=\'{}\'/ {}".format(self.username,self.fabfile)
            self.callPopen()
            self.cmd = "sed -i s$^env\.key_filename.*$env\.key_filename='{}'$ {}".format(self.keyDir + '/' + self.username,self.fabfile)
            self.callPopen()
            self.cmd = "sed -i s/^env\.roledefs.*/env.roledefs={{\\'{}\\':[\\'{}\\'],/ {}".format('stage',self.ip,self.fabfile)
            self.callPopen()
            
        ### NEED TO SPECIFY PATH TO FAB FILE IN WINDOWS 
        #fab = os.path.join("C:\\Users\\jose_luis_guerrero\\Envs\\mylai\\prognos_calibration",fabfile)
        if basin.system == 'Windows':
            replace(fab, "^env\.hosts.*",         "env.hosts=['{}']".format(ip))
            replace(fab, "^env\.user.*",          "env.user='{}'".format(username))
            replace(fab, "^env\.key_filename.*",  "env.key_filename='{}'".format(os.path.join(keyDir,username)))
            replace(fab, "^env\.roledefs.*",      "env.roledefs={{'{}':['{}'],".format('ncquery',ip))
            

    def setCommand(self,cmd):
        if not '-f' in cmd:
            cmd =   (' -f {}'.format(self.fabfile.split('.')[0]) + " " ).join(cmd.split(" ", 1))
        self.cmd = cmd
            
    def setFabfile(self,fab):
        self.fabfile = fab
        self.setFab()
        
        
            
            
        
