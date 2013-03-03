//
//  CBDataContainer.m
//  CoBoard
//
//  Created by Dominik Hübner on 11/14/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import "DataContainer.h"
#import "NSString+SHA1.h"
#import "SynchronizedTimestamp.h"
#import "JSONKit.h"

@implementation DataContainer

- (id) initWithType:(NSString *)type andPayload:(NSDictionary *) payload {
    if(self = [super init]) {
        self.type = [NSString stringWithString: type];
        self.payload = [NSMutableDictionary dictionaryWithDictionary: payload];
        self.ID = [[self createUUID] sha1];
    }
    
    return self;
}

- (id) initWithId:(NSString *)identifier timestamp:(NSNumber *)timestamp type:(NSString *) type payload:(NSDictionary *)payload
{
    if(self = [super init]) {
        self.ID = [NSString stringWithString: identifier];
        self.timestamp = [SynchronizedTimestamp trimTimestamp: timestamp];
        self.payload = [NSMutableDictionary dictionaryWithDictionary: payload];
        self.type = [NSString stringWithString: type];
    }
    
    return self;
}

- (NSString *) createUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);

    return [NSString stringWithString: (__bridge_transfer NSString *)(string)];
}

- (void) setPayload:(NSMutableDictionary *)payload
{
    //write to _payload to omit setter loop
    _payload = payload;
    
    if(payload == nil) {
        _payloadHash = @"";
    } else {
        _payloadHash = [[payload JSONString] sha1];
    }
}

- (void) setTimestamp:(NSNumber *)timestamp {
    _timestamp = [NSNumber numberWithDouble: round([timestamp doubleValue] * 1000) / 1000];
}

- (NSString *) description
{
    return [NSString stringWithFormat: @"CBDataContainer: \n \t id: %@ \n \t type: %@ \n \t timestamp: %@ \n \t payload: %@ \n \t payload_hash: %@",
            self.ID, self.type, self.timestamp, self.payload, self.payloadHash];
}

-(id) copyWithZone:(NSZone *)zone {
    DataContainer *copyContainer = [[DataContainer alloc] initWithId: self.ID timestamp: self.timestamp type: self.type payload:self.payload];
    return copyContainer;
}


@end
