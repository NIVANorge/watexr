#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct 11 10:59:31 2018

@author: jose-luis
"""
import os
import sys
import glob
from time import sleep
from selenium.webdriver import Chrome
from selenium.webdriver.chrome import webdriver as chrome_webdriver
import feedparser
import shutil
import yaml


class DriverBuilder():
    def get_driver(self, download_location=None, headless=False):

        driver = self._get_chrome_driver(download_location, headless)

        driver.set_window_size(1400, 700)

        return driver

    def _get_chrome_driver(self, download_location, headless):
        chrome_options = chrome_webdriver.Options()
        if download_location:
            prefs = {'download.default_directory': download_location,
                     'download.prompt_for_download': False,
                     'download.directory_upgrade': True,
                     'safebrowsing.enabled': False,
                     'safebrowsing.disable_download_protection': True}

            chrome_options.add_experimental_option('prefs', prefs)

        if headless:
            chrome_options.add_argument("--headless")
        
        driver_path = os.path.abspath("./chromedriver")

        if sys.platform.startswith("win"):
            driver_path += ".exe"

        driver = Chrome(executable_path=driver_path, options=chrome_options)

        if headless:
            self.enable_download_in_headless_chrome(driver, download_location)

        return driver

    def enable_download_in_headless_chrome(self, driver, download_dir):
        """
        there is currently a "feature" in chrome where
        headless does not allow file download: https://bugs.chromium.org/p/chromium/issues/detail?id=696481
        This method is a hacky work-around until the official chromedriver support for this.
        Requires chrome version 62.0.3196.0 or above.
        """

        # add missing support for chrome "send_command"  to selenium webdriver
        driver.command_executor._commands["send_command"] = ("POST", '/session/$sessionId/chromium/send_command')

        params = {'cmd': 'Page.setDownloadBehavior', 'params': {'behavior': 'allow', 'downloadPath': download_dir}}
        command_result = driver.execute("send_command", params)
        print("response from browser:")
        for key in command_result:
            print("result:" + key + ":" + str(command_result[key]))



class Download:
    
    def __init__(self,credentials='geocredentials.yaml'):
        self.credentials=yaml.safe_load(open(credentials))
        
    def download(self,saveFolder = './'):
        self.saveFolder = saveFolder
        if self.saveFolder != './':
            if os.path.exists(self.saveFolder) and os.path.isdir(self.saveFolder):
                shutil.rmtree(self.saveFolder)
            os.mkdir(self.saveFolder)

        driver_builder = DriverBuilder()

        download_path = os.path.abspath(saveFolder)

        driver = driver_builder.get_driver(download_path, headless=True)

        driver.get('https://kartkatalog.geonorge.no/AuthServices/SignIn?')
        driver.find_element_by_id('password').send_keys(self.credentials['password'])
        driver.find_element_by_id('username').send_keys(self.credentials['username'])
        driver.find_element_by_id('regularsubmit').click()
        
        #urls = '/home/jose-luis/Envs/catchment/Catchment_delineation/urls_AR5.csv'
        with open(self.urls) as f:
           content = f.readlines()
        # you may also want to remove whitespace characters like `\n` at the end of each line
        links = [x.strip() for x in content]
        
        for file in links:
            driver.get(file)

#        self.wait_until_file_exists(download_path, 30)
        self.wait_until_downloads_complete(download_path, len(links), 36000)
        driver.close()

        #assert (os.path.isfile(download_path))

        print("done")
        
    def wait_until_downloads_complete(self,download_path,numLinks,wait_time_in_seconds=5):
        waits = 0
        while len(glob.glob1(self.saveFolder,'*.zip')) < numLinks and waits < wait_time_in_seconds:
            print("sleeping...." + str(waits))
            sleep(10)  # make sure file completes downloading
            waits += 10        
        

    def wait_until_file_exists(self, download_path, wait_time_in_seconds=5):
        waits = 0
        while not any(fname.endswith('.zip') for fname in os.listdir(download_path)) and waits < wait_time_in_seconds:
            print("sleeping...." + str(waits))
            sleep(.5)  # make sure file completes downloading
            waits += .5
            
    def getUrls(self,searchString='FKB-AR5',saveFolder='./'):
        self.saveFolder=saveFolder
        if (self.saveFolder != './'):
            if os.path.exists(self.saveFolder) and os.path.isdir(self.saveFolder):
                shutil.rmtree(self.saveFolder)
            os.mkdir(self.saveFolder)
        self.urls = os.path.join(saveFolder,'urls.txt')
        mainFeedKartverket = 'http://nedlasting.geonorge.no/geonorge/Tjenestefeed.xml'
        allFeeds = feedparser.parse(mainFeedKartverket)

        #Finding entry containing AR5 data
        titles = [i.title for i in allFeeds.entries]
        utmLinks = [s.link for s in allFeeds.entries if searchString in s.title and 'SOSI' in s.title]
        utmFeed=feedparser.parse(utmLinks[0])

        #Downloading all the files 
        allLinks = [i.links[0]['href'].strip() for i in utmFeed.entries]

        #Creating a list of urls to be download with parallel and wget
        out = open(self.urls,'w')
        for i in allLinks:
            out.write("%s\n" % i)
        out.close()
        



# dummy = Download()
# dummy.getUrls(saveFolder='./')
# dummy.download(saveFolder='/home/jose-luis/data_AR5')
