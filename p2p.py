from Node import Node
import sys
import threading
from twisted.python import log

def main():
    log.startLogging(sys.stdout)
    a = Node()
    a.createSession()
    b = Node()
    b.joinSession("localhost", a.port)

main()
