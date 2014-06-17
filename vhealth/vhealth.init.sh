#!/bin/sh
#
# vhealth
#
# chkconfig:   - 90 10
# description:  HAProxy is a free, very fast and reliable solution \
#               offering high availability, load balancing, and \
#               proxying for TCP and  HTTP-based applications

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network


exec="/root/bin/vhealth.py"
param="5480 127.0.0.1"
prog="${exec} ${param}"
lockfile=/var/lock/subsys/vhealth

start() {
    echo -n $"Starting $prog: "
    # start it up here, usually something like "daemon $exec"
    daemon nohup $prog &> /var/log/vhealth.log &
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    # stop it here, often "killproc $prog"
    kill -9 $(sudo lsof -t -i:5480)
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
}

restart() {
    stop
    start
}

case "$1" in
    start|stop|restart|reload)
        $1
        ;;
    *)
        echo $"Usage: $0 {start|stop|status|restart|try-restart|reload|force-reload}"
        exit 2
esac

exit 0

