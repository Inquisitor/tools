#!/usr/bin/env python
'''
    logsync.py  module for put log to remote location, using file mask and parameter body
                supports at now the following metomds to sync:
                    HTTP PUT - use class LogSyncHttpPUT
                        Example: lsync = logsync.LogSyncHttpPUT(...)
                        Arguments and others see in classes definitions
'''

__author__ = 'Andrew nox Yakovlev <a.yakovlev@gaijin.ru>'
__version__ = '0.0.11'
__copyright__ = 'Gaijin Entertainment @ 2014'

'''
    Requiments:
        - requests              http requests
            requests.auth.HTTPBasicAuth     http authorization
            requests.exceptions             exceptions definitions
        - os                    standard system library
        - fnmatch               matching file names
        - json                  parse JSON config
        - re                    regexp compiler
        - mmap                  for map file to string
        - multiprocessing.Pool  allow to call functions async in subprocess
'''

import os
import requests
import fnmatch
import json
import multiprocessing
import re
import mmap
from multiprocessing import Pool  # Should be loaded separately by design
from requests.auth import HTTPBasicAuth  # Should be loaded separately by design
import requests.exceptions  # Should be loaded separately by design

class LogSyncException(Exception):
    def __init__(self, message):
        self.message = message
        print("[LogSync] Exception: %s" % self.message)

class ConfigNotFound(LogSyncException):
    def __init__(self, configFile):
        super(LogSyncException).__init__("Cannot open config file: %s" % configFile)
        raise self

class FileNotFound(LogSyncException):
    def __init__(self, logFile):
        super(LogSyncException).__init__("Cannot open file: %s" % logFile)
        pass

class ErrorConfigParse(LogSyncException):
    def __init__(self, configFile):
        super(LogSyncException).__init__("Unable to parse JSON in config file: %s" % configFile)
        raise self

class noSyncError(LogSyncException):
    def __init__(self):
        super(LogSyncException).__init__("Cannot run LogSync iteration")

class httpPutError(LogSyncException):
    def __init__(self, error):
        super(LogSyncException).__init__("HTTP-Error: %s" % error)
        pass

class LogSync(object):
    def __init__(self, withSuffix=None, logDir=None, maxProc=multiprocessing.cpu_count(), configFile='./logsync.json'):
        """
        Inital method for base class LogSync

        :param withSuffix:      if is False - not use suffix in self.logDir
        :param logDir:          define self.logPath (without suffix, it will be added)
        :param maxProc:         max proccesses in pool of child proc for async calls
        :param configFile:      config file location (logsync.json)
        """

        try:
            with open(configFile, 'rb') as f:
                self.cfg = json.load(f)
        except IOError:
            raise ConfigNotFound(configFile)
        except ValueError:
            raise ErrorConfigParse(configFile)
        except Exception as e:
            raise e

        if logDir:
            self.logPath = logDir
        elif withSuffix:
            self.logPath = os.path.join(logDir, withSuffix)
        else:
            raise noSyncError

        self.procpool = Pool(processes = maxProc)
        self.fList=[]

    def handler(self, body):
        self.listLogs(body)
        self.syncWrapper()

    def syncWrapper(self):
        for logFile in self.fList:
            self.procpool.apply_acync(self.syncWrapper, args = logFile)

    def listLogs(self, body):
        fileMask = self.cfg['logger']['fmask']['prefix'] + str(body) + self.cfg['logger']['fmask']['suffix']
        for root, dirs, files in os.walk(self.logPath):
            for filename in fnmatch.filter(files, fileMask):
                self.listReplays(os.path.join(root, filename))
                self.fList.append = os.path.join(root, filename)

    def listReplays(self, logFile):
        if self.cfg['logger']['parseReplays']:
            try:
                with open(logFile, 'r+') as f:
                    fdata = mmap.mmap(f.fileno(), 0)
                    m = re.search(self.cfg['logger']['replayPattern'], fdata)
                    if m:
                        fmaskBody = m.groups()[0]
                        fmask = self.cfg['logger']['rmask']['prefix'] + fmaskBody + self.cfg['logger']['rmask'][
                            'suffix']
                        for root, dirs, files in os.walk(self.logPath):
                            for filename in fnmatch.filter(fmask):
                                self.fList.append = os.path.join(root, filename)
            except IOError:
                raise ConfigNotFound(logFile)
            except AttributeError:
                raise ErrorConfigParse

    def sync(self, logFile):
        """
        Abstract method just remove log file from query
        :param logFile: file to operate
        """
        self.fList.remove(logFile)

class httpPUT(LogSync):
    def __init__(self, withSuffix='', logDir='', maxProc=multiprocessing.cpu_count(), configFile='./logsync.json'):
        super(httpPUT, self).__init__(withSuffix, logDir, maxProc, configFile)
        self.authObj = None
        self.headers = {
            'User-Agent': 'logSyncer on ' + os.uname()[1],
            'Content-Type': 'application/octet-stream'
        }

    def sync(self, Logfile):
        """
        Main controller - upload provided file to remote http-server with PUT method
        :param file: logFile entry
        """
        opFile=logFile
        try:
            if self.cfg['http']['auth']['user']:
                self.authObj = HTTPBasicAuth(self.cfg['http']['auth']['user'], self.cfg['http']['auth']['pass'])
            else:
                self.authObj = None
            if self.cfg['logger']['addHostname']:
                baseName = os.uname[1] + os.path.basename(logFile)
                pathName = os.path.dirname(logFile)
                fileWithHostname = os.path.join(pathName, baseName)
                os.rename(logFile, fileWithHostname)
                opFile=fileWithHostname
        except IOError:
            raise FileNotFound(logFile)
        except ValueError:
            raise ErrorConfigParse
        except Exception as e:
            raise e
        else:
            with open(opFile, 'rb') as f:
                try:
                    putReq = requests.put(self.cfg['http']['url'], data=f, verify=False, auth=self.authObj,
                                      headers=self.headers)
                except requests.exceptions.HTTPError as e:
                    raise httpPutError(str(e))
                except requests.exceptions.Timeout:
                    raise httpPutError('Connection timeout during upload file %s' % opFile)
                except requests.exceptions.ConnectionError as e:
                    raise httpPutError('Connection error: %s!' % str(e))
                except requests.exceptions.TooManyRedirects:
                    raise httpPutError('Too many redirects!')
                except IOError:
                    raise FileNotFound(opFile)
                else:
                    print('[%s] File has been successfully uploaded! HTTP answer code: %d' % (opFile, putReq.status_code))
                    if self.cfg['logger']['mvafter']:
                        newName = os.path.join(opFile, self.cfg['logger']['mvsuffix'])
                        os.rename(opFile, newName)
                        print("[%s] File has been renamed to %s" % (opFile, newName))
                    self.fList.remove(logFile)
