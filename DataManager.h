//
//  CBDataManager.h
//  CoBoard
//
//  Created by Dominik Hübner on 11/14/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DataContainer.h"

/**
 The DataManager is the central authority to control and version DataContainers. Furthermore, it ensures that stored DataContainers are persisted.
 **/
@interface DataManager : NSObject<NSCopying>

/**
Adds a DataContainer to the local storage
 @param dataContainer The DataContainer to be added
 @return YES if the DataContainer got stored or replaced/updated an old one. NO if skipped
 **/
- (BOOL) processContainer: (DataContainer *) dataContainer;

/**
 Updates the content hash using all currently stores DataContainers
 **/
- (void) rebuildHash;

/**
 Returns the state of all stored DataContainers by their ID and timestamp.
 @return NSDictionary with all IDs and timestamps 
 **/
- (NSDictionary *) sessionState;

/**
  Returns the state of all stored DataContainers by their ID and timestamp up to the provided timestamp.
 @param timestamp Timestamp of the latest DataContainer to be returned
 @return NSDictionary with all IDs and timestamps
 **/
- (NSDictionary *) getHashesUntilTimestamp: (NSNumber *)timestamp;

/**
 Returns the difference between the local session and a remoteSession for all DataContainers up to timestamp
 @param remoteSession A dictionary representing the state of the other session
 @param timestamp Timestamp of the latest DataContainer to be considered
 @return YES if the DataContainer got stored or replaced/updated an old one. NO if skipped
 **/
- (NSArray* ) diffSessionWithLocalSession: (NSDictionary *) remoteSession toTimestamp: (NSNumber *) timestamp;

@property (strong, nonatomic) NSMutableDictionary *cache;
@property (strong, nonatomic) NSString *contentHash;
@end
