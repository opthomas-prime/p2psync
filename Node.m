//
//  Node.m
//  P2PBenchmark
//
//  Created by Dominik Hübner on 1/26/13.
//  Copyright (c) 2013 Dominik Hübner. All rights reserved.
//

#import "Node.h"
#import "GCDAsyncSocket.h"
#import "NSData+JSON.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#import "JSONKit.h"
#import "SynchronizedTimestamp.h"
#import "DataManager.h"
#import "DataContainer.h"

@implementation Node {
    GCDAsyncSocket *_listenSocket;
    NSMutableArray *_remoteSockets;
    NSTimer *_contentSyncBeatTimer;
    NSTimer *_nodeSyncBeatTimer;
    SynchronizedTimestamp *_timestamp;
}

#pragma mark - Init

- (id) initWithName:(NSString *)name {
    if(self = [super init]) {
        self.name = name;
        self.dataManager = [[DataManager alloc] init];
        
        //we need to store the sockets and some meta data (port, ip and socket (socket to identify the dictionary))
        _remoteSockets = [[NSMutableArray alloc] init];
        _knownHosts = [[NSMutableArray alloc] init];
        
        //alloc socket
        _listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        _listenSocket.delegate = self;
        //try to listen on socket, let OS choose a free port
        NSError *err;
        if([_listenSocket acceptOnPort: 0 error: &err]) {
#ifdef DEBGUG_LOG_3
            [self debugMessage: [NSString stringWithFormat:@"listening on port: %d", [_listenSocket localPort]]];
#endif
            self.port = [NSNumber numberWithInt: [_listenSocket localPort]];
            [_knownHosts addObject: @{@"host": [self getIPAddress], @"port": self.port, @"socket": _listenSocket}];
            self.ip = [self getIPAddress];
            //int freq = arc4random()%SYNCBEAT_FREQ;
            _nodeSyncBeatTimer = [NSTimer scheduledTimerWithTimeInterval: SYNCBEAT_INTERVAL target: self selector: @selector(sendNodeSyncbeat) userInfo: nil repeats: YES];
            
        } else {
#ifdef DEBGUG_LOG_2
            [self debugMessage: @"creating host failed." ];
#endif
            return nil;
        }
    }
    
    return self;
}

- (void) connectToHost:(NSString *)hostname atPort:(NSNumber *)port {
    //alloc socket
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    socket.delegate = self;
    NSError *err;
    
    //try to connect to host
    if([socket connectToHost: hostname onPort: [port intValue] error: &err]) {
#ifdef DEBGUG_LOG_2
        [self debugMessage: [NSString stringWithFormat: @"connecting to %@ %d", hostname, [port intValue]]];
#endif
#ifdef BENCHMARK
        [self.benchmarkDelegate benchmarkNode:self connectedToPort:port];
#endif
        //add socket (required due to arc)
        [_remoteSockets addObject: socket];
        //add new node's metadata
        [_knownHosts addObject: @{@"host": hostname, @"port": port, @"socket": socket}];
        [socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
        
        if(_contentSyncBeatTimer == nil) {
            _contentSyncBeatTimer = [NSTimer scheduledTimerWithTimeInterval: CONTENT_SYNCBEAT_INTERVAL target: self selector: @selector(sendContentSyncbeat) userInfo: nil repeats: YES];
        }

    } else {
#ifdef DEBGUG_LOG_2
        [self debugMessage: @"connecting to host failed."];
#endif
    }
}

#pragma mark - Protocol

- (void) evaluate:(NSData *)data fromSocket:(GCDAsyncSocket *)socket {
    NSDictionary* message = [data jsonDictionaryValue];
    int messageType = [[message objectForKey: @"type"] intValue];
    
    switch (messageType) {
        case NODE_SYNCBEAT:
            [self receivedNodeSyncbeat:message fromSocket:socket];
            break;
            
        case META_SYNCBEAT:
            [self receivedMetaSyncbeat:message fromSocket:socket];
            break;
            
        case CONTENT_SYNCBEAT:
            [self receivedContentSyncbeat:message fromSocket:socket];
            break;
            
        case DATA:
            [self receivedDataContainer:message fromSocket:socket];
            break;
            
        default:
            break;
    }
}

#pragma mark Receive

- (void) receivedNodeSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket {
#ifdef DEBGUG_LOG_2
    [self debugMessage: @"received syncbeat"];
#endif
    //the syncbeat also contains the sender ip and port. we need this port since we have no other chance to get the port it is listening on
    BOOL known = NO;
    
    for(NSDictionary *host in _knownHosts) {
        BOOL remoteHostKnown = [[message objectForKey:@"host"] isEqualToString: [host objectForKey:@"host"]];
        BOOL remotePortKnown = [[message objectForKey:@"port"] intValue] == [[host objectForKey:@"port"] intValue];
        
        BOOL remoteKnown = remoteHostKnown && remotePortKnown;
        
        if(remoteKnown) {
            known = YES;
            break;
        }
    }
    
    if(!known) {
        [_knownHosts addObject: @{@"host": [message objectForKey:@"host"], @"port": [message objectForKey:@"port"], @"socket": socket}];
        return;
    }
    
    //now we need to check if the sender knows nodes we do not know yet
    for(NSDictionary *h in [message objectForKey:@"hosts"]) {
        BOOL known = NO;
        
        for(NSDictionary *host in _knownHosts) {
            BOOL remoteHostKnown = [[h objectForKey:@"host"] isEqualToString: [host objectForKey:@"host"]];
            BOOL remotePortKnown = [[h objectForKey:@"port"] intValue] == [[host objectForKey:@"port"] intValue];
            
            BOOL remoteKnown = remoteHostKnown && remotePortKnown;
            
            if(remoteKnown) {
                known = YES;
                break;
            }
        }
        
        if(!known) {
#ifdef DEBUG_LOG_3
            [self debugMessage: [NSString stringWithFormat:@"connecting to new host %@:%d", [h objectForKey:@"host"],[[h objectForKey:@"port"] intValue]]];
#endif
            [self connectToHost:[h objectForKey:@"host"] atPort:[h objectForKey:@"port"]];
        }
    }
}

- (void) receivedContentSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket {
    NSDictionary *remoteState = [message objectForKey: @"state"];
    NSNumber *remoteTimestamp = [NSNumber numberWithDouble: [[message objectForKey: @"timestamp"] doubleValue]];
    
    
    NSArray* toSync = [_dataManager diffSessionWithLocalSession: remoteState toTimestamp: remoteTimestamp];
    
#ifdef DEBUG_LOG_1 
    if([toSync count] > 0){
        [self debugMessage: @"requesting node requires sync"];
    }
#endif
    
#ifdef BENCHMARK
    if([toSync count] > 0){
        NSNumber *port;
        for(NSDictionary *node in _knownHosts) {
            if([node objectForKey:@"socket"] == socket) {
                port = [node objectForKey:@"port"];
                break;
            }
        }
        
        [self.benchmarkDelegate benchmarkNode:self syncsWithPort:port sendingNumberOfPackages: [toSync count]];
    }
#endif
    
    for(NSString *keyToSend in toSync) {
        [self sendDataContainer: [_dataManager.cache objectForKey: keyToSend] toSocket: socket];
    }
    
}

- (void) receivedMetaSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket {
    if(_timestamp == nil) {
        _timestamp = [[SynchronizedTimestamp alloc] initWithTimestamp: [message objectForKey: @"timestamp"]];
#ifdef DEBUG_LOG_3
        [self debugMessage: @"synchronized time"];
#endif
    }
}

- (void) receivedDataContainer:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket {

    DataContainer *container = [[DataContainer alloc] initWithId: [message objectForKey:@"id"]
                                                           timestamp:[message objectForKey:@"timestamp"]
                                                                type:[message objectForKey:@"subtype"]
                                                             payload:[[message objectForKey: @"payload"] objectFromJSONString]];
#ifdef BENCHMARK
    [self.benchmarkDelegate benchmarkNode: self receivedDataContainer: container];
#endif
    
    if (![self.dataManager processContainer: container]) {
        [self.benchmarkDelegate benchmarkNode:self didNotProcessContainer:container];
    } else {
        [self.delegate node: self receivedDataContainer: container];
    }
    
#ifdef DEBUG_LOG_1 
    [self debugMessage: @"received data container"];
#endif
}

#pragma mark Send

- (void) sendNodeSyncbeat {
    if([_remoteSockets count] > 0) {
        int randomNodeIndex = arc4random()%[_remoteSockets count];
        GCDAsyncSocket* rndNode = [_remoteSockets objectAtIndex: randomNodeIndex];
        [self sendNodeSyncbeat:rndNode];
    }
}

- (void) sendNodeSyncbeat:(GCDAsyncSocket *)socket {
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    NSMutableArray* hosts = [[NSMutableArray alloc] init];
    
    for(NSDictionary *host in _knownHosts) {
        [hosts addObject: @{@"host": [host objectForKey: @"host"], @"port": [host objectForKey: @"port"]}];
    }
    
    [message setObject: hosts forKey: @"hosts"];
    [message setObject: [NSNumber numberWithInt: NODE_SYNCBEAT] forKey: @"type"];
    [message setObject: self.name forKey: @"name"];
    [message setObject: [NSNumber numberWithInt: [_listenSocket localPort]] forKey: @"port"];
    [message setObject: [self getIPAddress] forKey: @"host"];
    
    [self sendMessage: message toSocket: socket];
#ifdef DEBUG_LOG_3
    [self debugMessage: [NSString stringWithFormat: @"sent node syncbeat to port: %d", [socket connectedPort]]];
#endif
}

- (void) sendContentSyncbeat {
    if([_remoteSockets count] > 0) {
        int randomNodeIndex = arc4random()%[_remoteSockets count];
        GCDAsyncSocket* rndNode = [_remoteSockets objectAtIndex: randomNodeIndex];
        
        [self sendContentSyncbeat:rndNode];
    }
}

- (void) sendContentSyncbeat:(GCDAsyncSocket *)socket {
    NSNumber *timestamp = [_timestamp getSynchronizedTimestamp];
    
    NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
    [message setObject:[NSNumber numberWithInt:CONTENT_SYNCBEAT] forKey: @"type"];
    
    if(_timestamp) {
        [message setObject: timestamp forKey: @"timestamp"];
        [message setObject: [_dataManager getHashesUntilTimestamp: timestamp] forKey: @"state"];
    } else {
        [message setObject: [NSNumber numberWithDouble: -1.f] forKey: @"timestamp"];
        [message setObject: @{} forKey: @"state"];
    }
    
    
    
    [self sendMessage: message toSocket: socket];
#ifdef DEBUG_LOG
    //[self postDebugMessage: [NSString stringWithFormat:@"Sent SYNCBEAT"]];
#endif
}

- (void) sendMetaSyncbeat {
    int randomNodeIndex = arc4random()%[_remoteSockets count];
    GCDAsyncSocket* rndNode = [_remoteSockets objectAtIndex: randomNodeIndex];
    
    [self sendMetaSyncbeat:rndNode];
}

- (void) sendMetaSyncbeat:(GCDAsyncSocket *)socket {
    if(_timestamp == nil) {
        NSNumber *currentTime = [NSNumber numberWithInt: [NSDate timeIntervalSinceReferenceDate]];
        _timestamp = [[SynchronizedTimestamp alloc] initWithTimestamp: currentTime];
    }
    
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    [message setObject: [_timestamp getSynchronizedTimestamp] forKey: @"timestamp"];
    [message setObject: [NSNumber numberWithInt: META_SYNCBEAT] forKey: @"type"];
    [self sendMessage: message toSocket: socket];
}

- (void) addDataContainer:(DataContainer *)container {
    container.timestamp = [_timestamp getSynchronizedTimestamp];
    [self.dataManager processContainer: container];
    
    [self sendDataContainer: container];
}

- (void) sendDataContainer:(DataContainer *) container {
    for(GCDAsyncSocket *sock in _remoteSockets) {
        [self sendDataContainer: container toSocket: sock];
    }
}

- (void) sendDataContainer:(DataContainer *) container toSocket:(GCDAsyncSocket *) socket {
    NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
    [message setObject: [NSNumber numberWithInt: DATA] forKey: @"type"];
    [message setObject: [container type] forKey: @"subtype"];
    [message setObject: [container timestamp] forKey: @"timestamp"];
    [message setObject: [[container payload] JSONString] forKey: @"payload"];
    [message setObject: [container ID] forKey: @"id"];
    
    [self sendMessage: message toSocket: socket];
}

#pragma mark - Termination

- (void) disconnect {
    //remove own listening socket from known hosts
    NSArray *hosts = [_knownHosts filteredArrayUsingPredicate: [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSDictionary *dict = (NSDictionary *) evaluatedObject;
        
        if([dict objectForKey: @"socket"] == _listenSocket) {
            return true;
        } else {
            return false;
        }
    }]];
    
    [_knownHosts removeObject: [hosts objectAtIndex: 0]];
    
    //disconnect all nodes which connected TO us
    [_listenSocket disconnect];
    
    //disconnect all nodes we established connections WITH
    for(NSDictionary *sock in _knownHosts) {
        [[sock objectForKey: @"socket"] disconnect];
#ifdef BENCHMARK
        [self.benchmarkDelegate benchmarkNode:self disconnectedFromPort: [sock objectForKey:@"port"]];
#endif
    }
    
    [_contentSyncBeatTimer invalidate];
    _contentSyncBeatTimer = nil;
    [_nodeSyncBeatTimer invalidate];
    _nodeSyncBeatTimer = nil;
    
    [self setDisconnected: YES];
}

#pragma mark - Socket delegate

- (void) socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    //add the new socket
    [_remoteSockets addObject: newSocket];
    [newSocket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    [self sendMetaSyncbeat: newSocket];
    
    if(_contentSyncBeatTimer == nil) {
        _contentSyncBeatTimer = [NSTimer scheduledTimerWithTimeInterval: CONTENT_SYNCBEAT_INTERVAL target: self selector: @selector(sendContentSyncbeat) userInfo: nil repeats: YES];
    }
}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
#ifdef DEBUG_LOG_3
    [self debugMessage: [NSString stringWithFormat: @"did connect with port: %d", [sock localPort]]];
#endif
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    [self sendNodeSyncbeat: sock];
    [self sendContentSyncbeat: sock];
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    //find the socket's metadata
    NSArray *hosts = [_knownHosts filteredArrayUsingPredicate: [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSDictionary *dict = (NSDictionary *) evaluatedObject;
        
        if([dict objectForKey: @"socket"] == sock) {
            return true;
        } else {
            return false;
        }
    }]];
    
    //remove it's metadata (ip, port ...)
    if([hosts count] > 0) {
        NSDictionary *host = [hosts objectAtIndex: 0];
        [_knownHosts removeObject: host];
#ifdef DEBUG_LOG_3
        [self debugMessage: [NSString stringWithFormat: @"%@: closed connection", self.name]];
#endif
    }
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    //process the received data
    [self evaluate:data fromSocket:sock];
    
    //continue reading future incomming data
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
}

#pragma mark - Helper
- (void)sendMessage:(NSDictionary *)message toSocket:(GCDAsyncSocket *)socket {
    NSData *dat = [NSData jsonDataWithDictionary:message];
    [socket writeData: dat withTimeout:-1 tag:0];
}

- (void) debugMessage: (NSString *) message {
#ifdef DEBUG_LOG
    NSLog(@"%@: %@", self.name, message);
#endif
}

- (NSString *)getIPAddress {
    /*
     NSString *address = @"error";
     struct ifaddrs *interfaces = NULL;
     struct ifaddrs *temp_addr = NULL;
     int success = 0;
     
     // retrieve the current interfaces - returns 0 on success
     success = getifaddrs(&interfaces);
     if (success == 0) {
     // Loop through linked list of interfaces
     temp_addr = interfaces;
     while (temp_addr != NULL) {
     if( temp_addr->ifa_addr->sa_family == AF_INET) {
     // Check if interface is en0 which is the wifi connection on the iPhone
     #if(TARGET_IPHONE_SIMULATOR)
     if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en1"]) {
     #else
     if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
     #endif
     // Get NSString from C String
     address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
     }
     }
     
     temp_addr = temp_addr->ifa_next;
     }
     }
     
     // Free memory
     freeifaddrs(interfaces);
     */
    //return address;
    return HOST_IP;
}


#pragma mark - Benchmarking

- (NSString *)statistics {
    NSMutableString *stats = [[NSMutableString alloc] init];
    
    [stats appendFormat: @"\nNode %@ (%@:%d):\n", self.name, [_listenSocket localHost], [_listenSocket localPort]];
    [stats appendFormat: @"\t #connections:\t %ld\n", [_remoteSockets count]];
    for (GCDAsyncSocket* sock in _remoteSockets) {
        [stats appendFormat: @"\t\t%@:%d\n", [sock connectedHost], [sock connectedPort]];
    }
    
    [stats appendFormat: @"\t #metadata:\t %ld\n", [_remoteSockets count]];
    
    return stats;
}

@end
