from twisted.internet import protocol, reactor
from twisted.protocols import basic
from twisted.python import log

node_syncbeat = "NODE_SYNCBEAT"
content_syncbeat = "CONTENT_SYNCBEAT"
meta_syncbeat = "META_SYNCBEAT"
data_container = "DATACONTAINER"
debug_data = "DEBUG"

class Evaluator:
    def __init__(self):
        log.msg("Evaluator init")

    def evaluate(self, message):
        if message == node_syncbeat:
            self.receivedNodeSyncbeat(self, message)
        elif message == content_syncbeat:
            self.receivedContentSyncbeat(self, message)
        elif message == meta_syncbeat:
            self.receivedMetaSyncbeat(self, message)
        elif message == data_container:
            self.receievedData(self, message)
        elif message == debug_data:
            self.receivedDebugData(self, message)

    def receivedNodeSyncbeat(self, message):
        print message

    def sendNodeSyncbeat(self):
        print "sending node syncbeat"

    def receivedContentSyncbeat(self, message):
        print message

    def sendContentSyncbeat(self):
        print "sending content syncbeat"

    def receivedMetaSyncbeat(self, message):
        print message

    def sendMetaSyncbeat(self):
        print "sending meta syncbeat"

    def receievedData(self, message):
        print message

    def sendData(self):
        print "sending datacontainer"

    def receivedDebugData(self, message):
        print message

    def hostConnected(self):
        log.msg("host connected")

    def hostDisconnected(self):
        log.msg("host disconnected")


class Protocol(basic.LineReceiver):
    def __init__(self, eval):
        self.evaluator = eval

    def connectionMade(self):
        self.evaluator.hostConnected()

    def connectionLost(self, reason):
        self.evaluator.hostDisconnected()

    def lineReceived(self, line):
        self.evaluator.evaluate(line)

class Node:
    def __init__(self):
        self.evaluator = Evaluator()
        self.port = 0

    def createSession(self):
        self.initLocalNetwork()

    def joinSession(self, host, port):
        self.connectToHost(host, port)
        self.initLocalNetwork()

    def initLocalNetwork(self):
        factory = protocol.ServerFactory()
        factory.protocol = Protocol(self.evaluator)
        react = reactor.listenTCP(0, factory)
        self.port = react.getHost().port
        reactor.run()

    def connectToHost(self, host, port):
        factory = protocol.ClientFactory()
        factory.protocol = Protocol(self.evaluator)
        reactor.connectTCP(host, port, factory)
        reactor.run()