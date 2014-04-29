//
//  NTJsonStore+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>

#import "NSArray+NTJsonStore.h"
#import "NSDictionary+NTJsonStore.h"

#import "NTJsonStore.h"

#import "NTJsonCollection+Private.h"
#import "NTJsonColumn+Private.h"
#import "NTJsonIndex+Private.h"
#import "NTJsonObjectCache+Private.h"
#import "NTJsonSqlConnection+Private.h"


#define LOG(format, ...)            NSLog(format, ##__VA_ARGS__)
#define LOG_ERROR(format, ...)      NSLog(@"Error: " format, ##__VA_ARGS__)
#define LOG_DBG(format, ...)      NSLog(@"Debug: " format, ##__VA_ARGS__)


@interface NTJsonStore (Private)

@property (nonatomic,readonly) NTJsonSqlConnection *connection;

@end

