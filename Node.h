//
//  Node.h
//  P2PBenchmark
//
//  Created by Dominik Hübner on 1/26/13.
//  Copyright (c) 2013 Dominik Hübner. All rights reserved.
//

#define DEBUG_LOG
// Log levels: 1, 2, 3
// #define DEBUG_LOG_1

#define BENCHMARK
#define HOST_IP @"127.0.0.1"

#define NODE_SYNCBEAT 1
#define META_SYNCBEAT 2
#define CONTENT_SYNCBEAT 3
#define DATA 4

#define SYNCBEAT_INTERVAL 1.f
#define CONTENT_SYNCBEAT_INTERVAL 4.f

#define NODE_FULLY_CONNECTED_FACTOR 0.75

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "DataManager.h"
#import "DataContainer.h"

@class Node;


/**
 Instances implementing the NodeDelegate protocol will be notified if a new DataContainer was processed by the regarding Node instance
 **/
@protocol NodeDelegate <NSObject>

/**
 Signals when a new DataContainer was received from the provided Node
 @param node The Node instance sending the DataContainer
 @param container The received DataContainer
 **/
- (void) node:(Node *)node receivedDataContainer:(DataContainer *)container;
@end

#ifdef BENCHMARK
@protocol NodeBenchmarkDelegate <NSObject>
@optional
- (void) benchmarkNode:(Node *)node connectedToPort:(NSNumber *)port;
- (void) benchmarkNode:(Node *)node disconnectedFromPort:(NSNumber *)port;
- (void) benchmarkNode:(Node *)node syncsWithPort:(NSNumber *)port sendingNumberOfPackages:(unsigned long)number;
- (void) benchmarkNode:(Node *)node receivedDataContainer:(DataContainer *)container;
- (void) benchmarkNode:(Node *)node didNotProcessContainer:(DataContainer *)container;
@end
#endif

/**
 A Node is the central interface to communicate with the P2P network. Messages are submitted and received using the a Node instance. Connections and 
 construction of the mesh network are handled automatically as well.
 **/

@interface Node : NSObject<GCDAsyncSocketDelegate>
/**
 Initialize a Node instance with the provided name
 @param name The of the Node instance
 @returns Initialized instance of Node
 **/
- (id) initWithName:(NSString *)name;

/**
 Connect the Node instance with a remote Node instance listening on the provided hostname and port
 @param hostname The host name of the remote Node instance (may be the IP or a hostname to be resolved)
 @param port The port, the remote Node instance is listening on
 **/
- (void) connectToHost:(NSString *)hostname atPort:(NSNumber *)port;

/**
 Evaluates a NSData message received from remote Nodes
 @param data The NSData instance received
 @param socket The GCDAsyncSocket instance sending the NSData instance
 **/
- (void) evaluate:(NSData *)data fromSocket:(GCDAsyncSocket *)socket;

/**
 Handles received NodeSyncbeats
 @param message The NodeSyncbeat message
 @param socket The socket of the remote Node instance sending the NodeSyncbeat
 **/
- (void) receivedNodeSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket;

/**
 Handles received ContentSyncbeats
 @param message The ContentSyncbeat message
 @param socket The socket of the remote Node instance sending the ContentSyncbeat
 **/
- (void) receivedContentSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket;

/**
 Handles received MetaSyncbeats
 @param message The MetaSyncbeat message
 @param socket The socket of the remote Node instance sending the MetaSyncbeat
 **/
- (void) receivedMetaSyncbeat:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket;
/**
 Handles received DataContainers
 @param message The received DataContainer
 @param socket The socket of the remote Node instance sending the DataContainer
 **/
- (void) receivedDataContainer:(NSDictionary *)message fromSocket:(GCDAsyncSocket *)socket;

/**
 Sends a NodeSyncbeat to a random remote Node instance
 **/
- (void) sendNodeSyncbeat;

/**
 Sends a NodeSyncbeat to the provided socket of a remote Node instance
 @param socket The socket of the receiving remote Node instance
 **/
- (void) sendNodeSyncbeat:(GCDAsyncSocket *)socket;

/**
 Sends a ContentSyncbeat to a random remote Node instance
 **/
- (void) sendContentSyncbeat;

/**
 Sends a ContentSyncbeat to the provided socket of a remote Node instance
 @param socket The socket of the receiving remote Node instance
 **/
- (void) sendContentSyncbeat:(GCDAsyncSocket *)socket;

/**
 Sends a MetaSyncbeat to a random remote Node instance
 **/
- (void) sendMetaSyncbeat;

/**
 Sends a MetaSyncbeat to the provided socket of a remote Node instance
 @param socket The socket of the receiving remote Node instance
 **/
- (void) sendMetaSyncbeat:(GCDAsyncSocket *)socket;

/**
 Adds a DataContainer to the local storage and distributes it to all connected Nodes
 @param container The DataContainer to store and distribute
 **/
- (void) addDataContainer:(DataContainer *)container;

/**
 Distributes a DataContainer to all connected Nodes
 @param container The DataContainer to distribute
 **/
- (void) sendDataContainer:(DataContainer *)container;

/**
 Send a DataContainer to the Node at the provided socket
 @param container The DataContainer to send
 @param socket The receiving socket
 **/
- (void) sendDataContainer:(DataContainer *)container toSocket:(GCDAsyncSocket *)socket;

//helper
/**
 Helper method to send the provided message to the given socket
 @param message The NSDictionary message to send
 @param socket The receiving socket
 **/
- (void)sendMessage:(NSDictionary *)message toSocket:(GCDAsyncSocket *)socket;

/**
 Disconnect the local Node instance from the P2P network
 **/
- (void) disconnect;


- (NSString *)getIPAddress;

//Benchmarking
- (NSString *)statistics;
- (void) debugMessage: (NSString *) message;

@property(strong, nonatomic) NSNumber *port;
@property(strong, nonatomic) NSString *name;
@property(strong, nonatomic) NSMutableArray *knownHosts;
@property(strong, nonatomic) DataManager *dataManager;
@property(nonatomic) BOOL disconnected;
@property(assign, nonatomic) id<NodeDelegate> delegate;
@property(assign, nonatomic) NSString *ip;
#ifdef BENCHMARK
@property(assign, nonatomic) id<NodeBenchmarkDelegate> benchmarkDelegate;
#endif
@end