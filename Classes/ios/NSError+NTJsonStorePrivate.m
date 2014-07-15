//
//  NSError+NTJsonStorePrivate.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 5/1/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonStore+Private.h"


NSString *NTJsonStoreErrorDomain = @"NTJsonStoreErrorDomain";
NSString *NTJsonStoreSqliteErrorDomain = @"NTJsonStoreSqliteErrorDomain";


@implementation NSError (NTJsonStorePrivate)


static NSString *descriptionForCode(NTJsonStoreErrorCode code)
{
    switch(code)
    {
        case NTJsonStoreErrorInvalidSqlArgument:
            return @"Invalid sqlite argument.";
            
        case NTJsonStoreErrorInvalidSqlResult:
            return @"Unexpected sqlite result type.";
            
        default:
            return [NSString stringWithFormat:@"NTJsonStore Error %d", (int)code];
    }
}


+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode message:(NSString *)message
{
    return [[NSError alloc] initWithDomain:NTJsonStoreErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: message}];
}


+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode
{
    return [self NTJsonStore_errorWithCode:errorCode message:descriptionForCode(errorCode)];
}


+(instancetype)NTJsonStore_errorWithCode:(NTJsonStoreErrorCode)errorCode format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    return [self NTJsonStore_errorWithCode:errorCode message:message];
}


+(instancetype)NTJsonStore_errorWithSqlite3:(sqlite3 *)db
{
    int errcode = sqlite3_errcode(db);
    NSString *errmsg = [[NSString alloc] initWithCString:sqlite3_errmsg(db) encoding:NSUTF8StringEncoding];
    
    return [[NSError alloc] initWithDomain:NTJsonStoreErrorDomain code:errcode userInfo:@{NSLocalizedDescriptionKey: errmsg}];
}


@end
