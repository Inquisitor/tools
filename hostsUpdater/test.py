#!/usr/bin/python
import sys, time

sys.path.append('/home/nox/src/yuNetwork/tools/dedicated')

import hostsUpdater

t = hostsUpdater.Updater('production', '/home/nox/src/yuNetwork/tools/dedicated/update.json')
t.schedule_update()

while True:
    print "main() -> while loop", time.time()
    time.sleep(10)



