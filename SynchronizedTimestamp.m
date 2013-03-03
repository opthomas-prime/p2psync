//
//  CBSynchronizedDate.m
//  CoBoard
//
//  Created by Dominik Hübner on 11/30/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import "SynchronizedTimestamp.h"

static double theOffset = 0;

@implementation SynchronizedTimestamp

- (id) initWithTimestamp:(NSNumber *) timestamp {
    if(self = [super init]) {
        theOffset = [[self getLocalTimestamp] doubleValue] - [timestamp doubleValue];
    }
    
    return self;
}

- (NSNumber *) getSynchronizedTimestamp {
    double timestamp = [[self getLocalTimestamp] doubleValue] - theOffset;
    return [NSNumber numberWithDouble: timestamp];
}

- (NSNumber *) getLocalTimestamp {
    NSNumber *timestamp = [NSNumber numberWithDouble: [[[NSDate alloc] init] timeIntervalSince1970]];

    return [SynchronizedTimestamp trimTimestamp: timestamp];
}

+ (NSNumber *) trimTimestamp: (NSNumber *) timestamp {
    //round to 3 decimal places
    return [NSNumber numberWithDouble: round( [timestamp doubleValue] * 1000) / 1000];
}

@end
