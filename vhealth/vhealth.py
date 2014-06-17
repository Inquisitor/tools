#!/usr/bin/env python
# coding: utf8

import BaseHTTPServer
from BaseHTTPServer import BaseHTTPRequestHandler,HTTPServer
from SocketServer import ThreadingMixIn
import threading
import argparse
import re
import cgi
import sys
import os
import time
from pprint import pprint
import subprocess

class LocalData(object):
 records = {}
 
class HTTPRequestHandler(BaseHTTPRequestHandler):
	def do_GET(self):
		vnodes = {'vdb04': '10.10.0.30', 'vdb05': '10.10.0.31', 'vdb06': '10.10.0.32', 'vdb07': '10.20.0.1', 'vdb08': '10.20.0.2', 'vdb09': '10.20.0.3' }
		ha_status = self.headers.get('X-Haproxy-Server-State')
		xstr = re.findall(ur"name=[a-z0-9]*/([a-z0-9]*)", ha_status)
		vserver = xstr[0]
		vip = vnodes[vserver]
		vcmd = ["/root/bin/vchk.sh", vserver, vip]
		vp = subprocess.Popen(args=vcmd, stdout=subprocess.PIPE)
		vstatus = vp.communicate()[0]
		pstatus = vp.wait()

		message = vserver + "(" + vip + ")" + " vsql response is '" + vstatus + "'"
	
		if vstatus.rstrip() == "UP":
			try:
				self.send_response(200)
				self.send_header('Content-Type', 'text/html')
				self.end_headers()
				self.wfile.write(message)
				self.wfile.write('\n')
			except Exception as e:
				pass
		else:
			try:
				self.send_response(503)
				self.send_header('Content-Type', 'text/html')
				self.end_headers()
				self.wfile.write(message)
				self.wfile.write("Service unavailable")
				self.wfile.write('\n')
			except Exception as	e:
				pass
		return
 
class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
	allow_reuse_address = True
 
	def shutdown(self):
		self.socket.close()
		HTTPServer.shutdown(self)
 
class SimpleHttpServer():
	def __init__(self, ip, port):
		self.server = ThreadedHTTPServer((ip,port), HTTPRequestHandler)
 
	def start(self):
		self.server_thread = threading.Thread(target=self.server.serve_forever)
		self.server_thread.daemon_threads = True
		self.server_thread.start()
 
	def waitForThread(self):
		self.server_thread.join()

 
	def stop(self):
		self.server.shutdown()
		self.waitForThread()
 
if __name__=='__main__':
	parser = argparse.ArgumentParser(description='HTTP Server')
	parser.add_argument('port', type=int, help='Listening port for HTTP Server')
	parser.add_argument('ip', help='HTTP Server IP')
	args = parser.parse_args()
 
	server = SimpleHttpServer(args.ip, args.port)
	print 'HTTP Server Running...........'
	server.start()
	server.waitForThread()

