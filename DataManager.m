//
//  CBDataManager.m
//  CoBoard
//
//  Created by Dominik Hübner on 11/14/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import "DataManager.h"
#import "DataContainer.h"
#import "NSString+SHA1.h"

@implementation DataManager

- (id) init
{
    if (self = [super init]) {
        self.cache = [[NSMutableDictionary alloc] init];        
        self.contentHash = [@"" sha1];
    }
    
    return self;
}

- (BOOL) processContainer:(DataContainer *)dataContainer {
    BOOL didStoreContainer = NO;
    
    //We know this container
    if([self.cache objectForKey: dataContainer.ID]) {
        DataContainer *cachedContainer = [self.cache objectForKey: dataContainer.ID];

        if([cachedContainer.timestamp compare: dataContainer.timestamp] == NSOrderedAscending) {
            [self.cache setObject: [dataContainer copy] forKey: dataContainer.ID];
            didStoreContainer = YES;
        }
    }
    //Nope, new container
    else {
        [self.cache setObject: [dataContainer copy] forKey: dataContainer.ID];
        didStoreContainer = YES;
    }
    
    [self rebuildHash];
    
    return didStoreContainer;
}

- (void) rebuildHash
{
    @synchronized(self.cache) {
        NSArray* curContent = [self.cache allValues];
        
        //sort items using their ID to keep order on all nodes consistent
        curContent = [curContent sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            DataContainer *first = (DataContainer *) a;
            DataContainer *second = (DataContainer *) b;
            
            return [first.ID compare: second.ID options:  NSNumericSearch];
        }];
        
        NSMutableString *tmpHash = [[NSMutableString alloc] init];
        
        for(DataContainer* container in curContent) {
            [tmpHash appendString: [container payloadHash]];
        }
        
        NSString *contentHash = [[NSString stringWithString: tmpHash] sha1];
        self.contentHash = contentHash;
    }
}


- (NSDictionary *) sessionState {
    NSMutableDictionary *tmpDict = [[NSMutableDictionary alloc] init];
    
    for(NSString *containerKey in [self.cache allKeys]) {
        DataContainer *container = [self.cache objectForKey: containerKey];
        [tmpDict setObject: container.timestamp forKey: [NSString stringWithString: container.ID ]];
    }
    
    return [NSDictionary dictionaryWithDictionary: tmpDict];
}


- (NSDictionary *) getHashesUntilTimestamp: (NSNumber *)timestamp {
    NSDictionary *fullSessionState = [self sessionState];
    NSMutableDictionary *stateUptoTimestamp = [[NSMutableDictionary alloc] init];
    
    for(NSString *key in [fullSessionState allKeys]) {
        NSNumber *known = [fullSessionState objectForKey: key];
        if([timestamp doubleValue] == -1.f || [known doubleValue] <= [timestamp doubleValue]) {
            [stateUptoTimestamp setObject: [fullSessionState objectForKey: key] forKey: key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary: stateUptoTimestamp];
}

- (NSArray* ) diffSessionWithLocalSession: (NSDictionary *) remoteSession toTimestamp: (NSNumber *) timestamp
{
    NSMutableSet *localSet = [NSMutableSet setWithArray: [[self getHashesUntilTimestamp: timestamp] allKeys]];
    NSMutableSet *remoteSet = [NSMutableSet setWithArray: [remoteSession allKeys]];
    
    [localSet intersectSet: remoteSet];
    
    NSMutableArray *toSync = [[NSMutableArray alloc] initWithArray: [[self getHashesUntilTimestamp: timestamp] allKeys]];
    [toSync removeObjectsInArray: [localSet allObjects]];
    
    
    //TODO: check if this works, maybe only containers to the timestamp parameter should be checked
    for(NSString *remoteKey in [remoteSession allKeys]) {
        DataContainer *localContainer = (DataContainer *)[self.cache objectForKey: remoteKey];
        NSNumber *remoteTimestamp = [NSNumber numberWithDouble: [[remoteSession objectForKey: remoteKey] doubleValue]];

        /*
        unsigned long long localT = (unsigned long long)(floor([localContainer.timestamp doubleValue] * 100));
        unsigned long long remoteT = (unsigned long long)(floor([remoteTimestamp doubleValue] * 100));
        */
        
        if([[NSString stringWithFormat: @"%f", [localContainer.timestamp doubleValue]] compare:[NSString stringWithFormat: @"%f", [remoteTimestamp doubleValue]] options: NSNumericSearch] > 0) {
            [toSync addObject: remoteKey];
        }
    }
    
    return toSync;
}

-(id) copyWithZone:(NSZone *)zone {
    DataManager *newManager = [[DataManager alloc] init];
    for(DataContainer *container in self.cache) {
        [newManager processContainer: [container copy]];
    }
    
    return newManager;
}

@end
