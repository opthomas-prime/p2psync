//
//  NSData+JSON.h
//  CoBoard
//
//  Created by Dominik Hübner on 10/27/12.
//  Copyright (c) 2012 HdM. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (JSON)

- (NSDictionary*) jsonDictionaryValue;
+ (NSData*) jsonDataWithDictionary: (NSDictionary*) dictionary;

@end
