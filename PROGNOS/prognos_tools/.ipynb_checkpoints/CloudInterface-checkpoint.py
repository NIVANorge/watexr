from subprocess import Popen, PIPE, CalledProcessError
import re
import platform
import shutil
import os.path
import fileinput
from urllib.parse import urljoin
from IPython.display import clear_output, display
import collections

class CloudInterface(object):
        
    options = {'stdout': PIPE, 'stderr': PIPE, 'bufsize' : 1, 'universal_newlines' : True, 'shell' : False}
    system = 'Linux'
     
 
    def __init__(self,machineInfo):

        self.storageFolder=''
        self.machineInfo = machineInfo
        self.out = ''
        self.instantiationString = ''
        self.instanceExists = False
        
        CloudInterface.system = platform.system()
        if (CloudInterface.system == 'Windows'):
            CloudInterface.options['shell'] = True
            #Packages required to generate ssh keys in windows
            from cryptography.hazmat.primitives import serialization as crypto_serialization
            from cryptography.hazmat.primitives.asymmetric import rsa
            from cryptography.hazmat.backends import default_backend as crypto_default_backend
#             self.machineInfo['keyDir'] = 'c:/Users/jose_luis_guerrero/{}'.format(self.machineInfo['keyDir'])
#         if (CloudInterface.system == 'Linux'):
#             self.machineInfo['keyDir'] = '/home/jose-luis/.ssh/{}'.format(self.machineInfo['keyDir'])
            
            
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
        if CloudInterface.system == 'Windows':
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
        if CloudInterface.system == 'Linux':
            p = Popen("echo 'yes' | ssh-keygen -t rsa -f {keyFile} -C {username} -N '' ".format(**self.machineInfo),
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

    def setFab(self):
        if CloudInterface.system == 'Linux':
#             display(self.fabfile,os.getcwd())
            cmd = "sed -i s/^env\.hosts.*/env.hosts=\['{}']/ {}".format(self.ip,self.fabfile)
            self.callPopen(cmd)
            cmd = "sed -i s/^env\.user.*/env.user=\'{}\'/ {}".format(self.machineInfo['username'],self.fabfile)
            self.callPopen(cmd)
            cmd = "sed -i s$^env\.key_filename.*$env\.key_filename='{}'$ {}".format(self.machineInfo['keyFile'],self.fabfile)
            self.callPopen(cmd)
            cmd = "sed -i s/^env\.roledefs.*/env.roledefs={{\\'{}\\':[\\'{}\\'],/ {}".format('stage',self.ip,self.fabfile)
            self.callPopen(cmd)
            
        ### NEED TO SPECIFY PATH TO FAB FILE IN WINDOWS 
        #fab = os.path.join("C:\\Users\\jose_luis_guerrero\\Envs\\mylai\\prognos_calibration",fabfile)
        if CloudInterface.system == 'Windows':
            replace(fab, "^env\.hosts.*",         "env.hosts=['{}']".format(ip))
            replace(fab, "^env\.user.*",          "env.user='{}'".format(username))
            replace(fab, "^env\.key_filename.*",  "env.key_filename='{}'".format(os.path.join(keyDir,username)))
            replace(fab, "^env\.roledefs.*",      "env.roledefs={{'{}':['{}'],".format('stage',ip))
            
            
    def setFabfile(self,fab):
        self.fabfile = fab
        self.setFab()
        
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
