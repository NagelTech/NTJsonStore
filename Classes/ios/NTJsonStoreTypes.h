//
//  NTJsonStoreTypes.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/31/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import <Foundation/Foundation.h>

typedef int64_t NTJsonRowId;

extern NSString *NTJsonStoreErrorDomain;        // code = NTJsonStoreErrorCode
extern NSString *NTJsonStoreSqliteErrorDomain;  // code = SQLITE_??? error


typedef enum
{
    NTJsonStoreErrorInvalidSqlArgument = 1,
    NTJsonStoreErrorInvalidSqlResult = 2,
    NTJsonStoreErrorClosed = 3,     // connection or store closed
} NTJsonStoreErrorCode;



