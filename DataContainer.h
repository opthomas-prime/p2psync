//
//  CBDataContainer.h
//  CoBoard
//
//  Created by Dominik Hübner on 11/14/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 DataContainers are wrappers for messages passed between nodes. They are used to mashall/de-marshall JSON formatted messages to regular NSDictionaries and vice versa.
 **/
@interface DataContainer : NSObject<NSCopying>

@property(strong, nonatomic) NSString *ID;
@property(nonatomic) NSNumber *timestamp;
@property(strong, nonatomic) NSString *type;
@property(strong, nonatomic) NSMutableDictionary *payload;
@property(strong, nonatomic) NSString *payloadHash;
@property(strong, nonatomic) NSString *sessionId;

/**
 Returns an initialized DataContainer with the given type and payload
 @param type NSString describing the type of the content
 @param payload NSDictionary storing the necessary data to represent the DataContainer
 **/
- (id) initWithType:(NSString*) type andPayload:(NSDictionary*) payload;

/**
 Returns an initialized DataContainer with the given identifier, timestamp, type and payload
 @param identifier NSString as unique identifier of the DataContainer
 @param timestamp Unix-formatted timestamp denoting when the container was created or updated
 @param type NSString describing the type of the content
 @param payload NSDictionary storing the necessary data to represent the DataContainer
 **/
- (id) initWithId:(NSString *)identifier timestamp:(NSNumber *)timestamp type:(NSString *) type payload:(NSDictionary *)payload;

- (NSString *) createUUID;

@end
