//
//  CBSynchronizedDate.h
//  CoBoard
//
//  Created by Dominik Hübner on 11/30/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The SynchronizedTimestamp is an utility class to compute a synchronized timestamp based on an offset. 
 **/

@interface SynchronizedTimestamp : NSObject

/**
 Returns an initialized SynchronizedTimestamp with an offset to the given timestamp
 @param timestamp The unix-timestamp to synchronize with
 **/
- (id) initWithTimestamp:(NSNumber *) timestamp;

/**
 Returns a timestamp computed using the synchronized timestamp and the local time
 @returns unix formatted timestamp
 **/
- (NSNumber *) getSynchronizedTimestamp;
/**
 Returns the local time
 @returns unix formatted timestamp
**/
- (NSNumber *) getLocalTimestamp;

+ (NSNumber *) trimTimestamp: (NSNumber *) timestamp;

@end
