#!/usr/bin/python

from threading import Timer
import time
import json
import sys
import subprocess

# Exceptions catcher class
class UpdaterException(Exception):
    def __init__(self, e):
        self.message = str(e)
        print("[hostsUpdater] Exception: %s" % self.message)

# Class for periodically schedule task (method/function) run in thread
class ThreadSchedule():
    def __init__(self, t):
        self.t = t
        self.thread = Timer(self.t, self.check_update_wrapper)

    def check_update_wrapper(self):
        self.thread = Timer(self.t, self.check_update_wrapper)
        self.thread.start()

    def start(self):
        self.thread.start()

    def cancel(self):
        self.thread.cancel()

#
# how to use:
#
#import hostsUpdater
#
#t = hostsUpdater.Updater('production', '/home/nox/src/yuNetwork/tools/dedicated/update.json')
#t.schedule_update()

# Main class for updater
class Updater(ThreadSchedule):
    def __init__(self, circuit, config_file="./update.json"):
        self.haveUpdate = False
        self.circuit = circuit
        self.configFile = config_file

        # Load config from JSON to dict
        try:
            with open(self.configFile, 'rb') as configSource:
                self.cfg = json.load(configSource)
        except (IOError, ValueError, KeyError, TypeError) as e:
            raise UpdaterException(e)

        try:
            # Add work class, defined from config, to main class
            self.getClass = getattr(sys.modules[self.__module__], self.cfg['update_class'])(self.cfg, self.circuit)
        except:
            raise

    # Schedule periodically update check
    def schedule_update(self):
        self.cron = ThreadSchedule.__init__(self, self.cfg["check_interval"])
        self.daemon = True
        self.start()

    # Wrapper for check_update task
    def check_update_wrapper(self):
        # In fact we call subclass method, in this case GitUpdater->check_update
        if self.getClass:
            self.haveUpdate = self.getClass.check_update()
            if not self.haveUpdate:
                self.thread = Timer(self.t, self.check_update_wrapper)
                self.thread.start()

    # Abstract method, never will be called
    def check_update(self):
        print "Abstract wrapper for check_update(), should be used only for test purposes!"
        return False


class GitUpdater(object):
    def __init__(self, config, circuit):
        # Get config and circuit from parent class
        self.cfg = config
        self.circuit = circuit

        # Define git command line arguments
        gitDirArg = '--git-dir=' + self.cfg['GitUpdater']['gitDir']
        workDirArg = '--work-tree=' + self.cfg['GitUpdater']['workDir'] + '/' + self.circuit
        self.git_args = ['/usr/bin/git',gitDirArg, workDirArg]

        # Determine current version of circuit code
        self.current_version = self.get_current_version()
        print self.current_version

    def check_update(self):
        print "test!", time.time(), self.current_version
        return False

    # Get current version (tag) and commit id from git working tree
    def get_current_version(self):
        ver_exec = subprocess.Popen(self.git_args + ['describe'], stdout=subprocess.PIPE).communicate()[0].rstrip()
        commit_exec = subprocess.Popen(self.git_args + ['rev-parse', ver_exec], stdout=subprocess.PIPE).communicate(

        )[0].rstrip()
        return [ver_exec, commit_exec]
