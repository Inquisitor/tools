#!/usr/bin/env bash

/usr/bin/killall -0 haproxy && /usr/sbin/lsof -i:5480 >/dev/null 2>&1

