//
//  NTJsonStore.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>

#import "NTJsonStore+Private.h"


@interface NTJsonStore ()
{
    sqlite3 *_connection;
    NSMutableDictionary *_internalCollections;
}

@property (nonatomic,readonly) NSMutableDictionary *internalCollections;

@end


@implementation NTJsonStore


-(id)initWithName:(NSString *)storeName
{
    self = [super init];
    
    if ( self )
    {
        _storeName = storeName;
        _storePath = NSTemporaryDirectory();
    }
    
    return self;
}


-(NSString *)storeFilename
{
    return [NSString stringWithFormat:@"%@%@", self.storePath, self.storeName];
}


-(BOOL)exists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.storeFilename];
}


-(sqlite3 *)connection
{
    if ( !_connection )
    {
        int status = sqlite3_open_v2([self.storeFilename cStringUsingEncoding:NSUTF8StringEncoding], &_connection, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FULLMUTEX, NULL);
        
        if ( status == SQLITE_OK )
            LOG_DBG(@"Database opened");
        else
            LOG_ERROR(@"Failed to open database: %d", status);
    }
    
    return _connection;
}


-(sqlite3_stmt *)statementWithSql:(NSString *)sql args:(NSArray *)args
{
    sqlite3_stmt *statement = NULL;
    
    if ( !sql )
        sql = @"";
    
#ifdef DEBUG_SQL
    
    if ( [args count] )
    {
        //       NTLogDebug(@"    Args: %@", [args componentsJoinedByString:@", "]);
        
        NSMutableString *expSql = [NSMutableString stringWithString:sql];
        
        int offset = 0;
        
        for(id arg in args)
        {
            NSString *value;
            
            if ( arg == nil || arg == [NSNull null] )
                value = @"null";
            
            else if ( [arg isKindOfClass:[NSString class]] )
                value = [NSString stringWithFormat:@"\'%@\'", arg];
            
            else if ( [arg isKindOfClass:[NSNumber class]] )
                value = [arg stringValue];
            
            else if ( [arg isKindOfClass:[NSDate class]])
                value = [(NSDate *)arg stringWithFormat:@"[yyyy/MM/dd HH:mm:ss zzz]"];
            
            else if ( [arg isKindOfClass:[NSData class]] )
                value = [NSString stringWithFormat:@"[BLOB %d]", ((NSData *)arg).length];
            
            else
                value = [NSString stringWithFormat:@"[%@]", NSStringFromClass([arg class])];
            
            NSRange pos = [expSql rangeOfString:@"?" options:0 range:NSMakeRange(offset, expSql.length-offset)];
            
            if (pos.location == NSNotFound )
                break; // unlikely
            
            [expSql replaceCharactersInRange:pos withString:value];
            
            offset = pos.location + value.length;
        }
        
        NTLogDebug(@"%@", expSql);
    }
    
    else
        NTLogDebug(@"%@", sql);
    
#endif
    
    if ( ![sql hasSuffix:@";"] )
        sql = [sql stringByAppendingString:@";"];
    
    int status = sqlite3_prepare_v2(self.connection, [sql cStringUsingEncoding:NSUTF8StringEncoding], sql.length, &statement, NULL);
    
    if (status != SQLITE_OK )
    {
        LOG_ERROR(@" Failed to prepare statement %@ - %s", sql, sqlite3_errmsg(self.connection));
        return NULL;
    }
    
    if ( args )
    {
        // Add arguments...
        
        int index = 1;
        
        for(id arg in args)
        {
            if ( [arg isKindOfClass:[NSString class]] )
            {
                sqlite3_bind_text(statement, index, [(NSString *)arg cStringUsingEncoding:NSUTF8StringEncoding], -1, SQLITE_TRANSIENT);
            }
            
            else if ( [arg isKindOfClass:[NSNumber class]] )
            {
                const char *numType = [arg objCType];
                
                if ( strcmp(numType, @encode(int)) == 0 )
                    sqlite3_bind_int(statement, index, [arg intValue]);
                
                else if ( strcmp(numType, @encode(long long)) == 0 )
                    sqlite3_bind_int64(statement, index, [arg longLongValue]);
                
                else if ( strcmp(numType, @encode(double)) == 0 || strcmp(numType, @encode(float)) )
                    sqlite3_bind_double(statement, index, [arg doubleValue]);
                
                else
                {
                    LOG_ERROR(@"Unknown Numeric type %s", numType);
                    return NULL;
                }
            }
            
            else if ( [arg isKindOfClass:[NSDate class]] )
            {
                sqlite3_bind_int(statement, index, [arg timeIntervalSince1970]);
            }
            
            else if ( [arg isKindOfClass:[NSData class]] )
            {
                sqlite3_bind_blob(statement, index, [arg bytes], [arg length], SQLITE_TRANSIENT);
            }
            
            else if ( arg == [NSNull null] )
            {
                sqlite3_bind_null(statement, index);
            }
            
            else
            {
                LOG_ERROR(@"Unknown type: %@", NSStringFromClass([arg class]));
                return NULL;
            }
            
            ++index;
        }
    }
    
    return statement;
}


-(BOOL)execSql:(NSString *)sql args:(NSArray *)args
{
    sqlite3_stmt *statement = [self statementWithSql:sql args:args];
    
    if ( !statement )
        return NO;
    
    int status = sqlite3_step(statement);
    
    if ( status != SQLITE_DONE )
    {
        LOG_ERROR(@"Failed to execute statement - %s", sqlite3_errmsg(self.connection));
        sqlite3_finalize(statement);
        return NO;
    }
    
    sqlite3_finalize(statement);
    statement = NULL;
    
    return YES;
}


-(NSMutableDictionary *)internalCollections
{
    if ( !_internalCollections )
    {
        _internalCollections = [NSMutableDictionary dictionary];

        sqlite3_stmt *statement = [self statementWithSql:@"SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY 1;" args:nil];
        
        int status;
        
        while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
        {
            NSString *collectionName = [[NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)] lowercaseString];
            
            NTJsonCollection *collection = [[NTJsonCollection alloc] initWithStore:self name:collectionName];
            
            _internalCollections[collectionName] = collection;
        }
        
        sqlite3_finalize(statement);
    }
    
    return _internalCollections;
}


-(NSArray *)collections
{
    return [self.internalCollections allValues];
}


-(NTJsonCollection *)collectionWithName:(NSString *)collectionName
{
    collectionName = [collectionName lowercaseString];
    
    NTJsonCollection *collection = self.internalCollections[collectionName];
    
    if ( collection )
        return collection;
    
    // If collection was not found, create it...
    
    LOG(@"Creating collection: %@", collectionName);
    
    collection = [[NTJsonCollection alloc] initNewCollectionWithStore:self name:collectionName];
    
    self.internalCollections[collectionName] = collection;
    
    return collection;
}


-(BOOL)ensureSchema
{
    for(NTJsonCollection *collection in self.collections)
    {
        if ( ![collection ensureSchema] )
            return NO;
    }
    
    return YES;
}

@end
