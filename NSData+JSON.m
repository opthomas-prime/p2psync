//
//  NSData+JSON.m
//  CoBoard
//
//  Created by Dominik Hübner on 10/27/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import "NSData+JSON.h"
#import "JSONKit.h"
#import "GCDAsyncSocket.h"

@implementation NSData (JSON)

- (NSDictionary*) jsonDictionaryValue
{
    NSString* result = [[NSString alloc] initWithData: self encoding:NSUTF8StringEncoding];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    return (NSDictionary *)[result objectFromJSONString];
}

+ (NSData*) jsonDataWithDictionary: (NSDictionary*) dictionary
{
    NSString *message = [NSString stringWithFormat: @"%@%@", [dictionary JSONString] , @"\r\n"];
    return [message dataUsingEncoding: NSUTF8StringEncoding];
}
@end
