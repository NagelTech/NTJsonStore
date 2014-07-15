//
//  NSError+NTJsonStorePrivate.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 5/1/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>
#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"


@interface NSError (NTJsonStorePrivate)

+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode;
+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode message:(NSString *)message;
+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode format:(NSString *)format, ...;

+(instancetype)NTJsonStore_errorWithSqlite3:(sqlite3 *)db;

@end
