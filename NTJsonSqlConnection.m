//
//  NTJsonSqlConnection.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 4/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import "NTJsonStore+Private.h"


@interface NTJsonSqlConnection ()
{
    sqlite3 *_connection;
    NSString *_connectionName;
    NSString *_filename;
    NSString *_queueName;
    
    dispatch_queue_t _queue;
}

@property (nonatomic,readonly) NSString *queueName;

@end


@implementation NTJsonSqlConnection


-(id)initWithFilename:(NSString *)filename connectionName:(NSString *)connectionName
{
    self = [super init];
    
    if ( self )
    {
        _filename = filename;
        _connectionName = connectionName;
        _queueName = [NSString stringWithFormat:@"com.nageltech.NTJsonStore.%@", connectionName];
        _queue = dispatch_queue_create(_queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}


-(sqlite3 *)connection
{
    @synchronized(self)
    {
        // Make sure the connection is being accessed on the correct queue...
        
        const char *queueName = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        
        if ( strcmp(queueName, _queueName.UTF8String) != 0 )
            @throw [NSException exceptionWithName:@"WrongQueue" reason:@"Attempt to access SQL connection from the wrong queue." userInfo:nil];
        
        if ( !_connection )
        {
            int status = sqlite3_open_v2([self.filename cStringUsingEncoding:NSUTF8StringEncoding], &_connection, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_NOMUTEX, NULL);
            
            if ( status != SQLITE_OK )
            {
                LOG_ERROR(@"Failed to open database: %d", status);
                _connection = nil;  // throw execption???
                return nil;
            }
            
            LOG_DBG(@"Database opened, version = %s", sqlite3_version);
            
            NSString *journalMode = [self execValueSql:@"PRAGMA journal_mode=wal;" args:nil];
            
            if ( ![journalMode isEqualToString:@"wal"] )
            {
                LOG_ERROR(@"Unable to enable WAL mode, current mode - %@", journalMode);
            }
        }
        
        return _connection;
    }
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
    
    NSUInteger status = sqlite3_prepare_v2(self.connection, [sql cStringUsingEncoding:NSUTF8StringEncoding], (int)sql.length, &statement, NULL);
    
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
                sqlite3_bind_blob(statement, index, [arg bytes], (int)[arg length], SQLITE_TRANSIENT);
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


-(id)execValueSql:(NSString *)sql args:(NSArray *)args
{
    sqlite3_stmt *statement = [self statementWithSql:sql args:args];
    
    if ( !statement )
        return NO;
    
    int status = sqlite3_step(statement);
    
    if ( status != SQLITE_ROW )
    {
        LOG_ERROR(@"Failed to execute statement - %s", sqlite3_errmsg(self.connection));
        sqlite3_finalize(statement);
        return nil;
    }
    
    id value = nil;
    
    switch(sqlite3_column_type(statement, 0))
    {
        case SQLITE_INTEGER:
            value = [NSNumber numberWithLongLong:sqlite3_column_int64(statement, 0)];
            break;
            
        case SQLITE_FLOAT:
            value = [NSNumber numberWithDouble:sqlite3_column_double(statement, 0)];
            break;
            
        case SQLITE_TEXT:
            value = [NSString stringWithCString:(const char *)sqlite3_column_text(statement, 0) encoding:NSUTF8StringEncoding];
            break;
            
        case SQLITE_BLOB:
            value = [NSData dataWithBytes:sqlite3_column_blob(statement, 0) length:sqlite3_column_bytes(statement, 0)];
            break;
            
        case SQLITE_NULL:
            value = nil;
            
        default:
            @throw [NSException exceptionWithName:@"UnexpectedValue" reason:@"Unexpected SQLITE type" userInfo:nil];
    }

    
    sqlite3_finalize(statement);
    statement = NULL;
    
    return value;
}


-(void)dispatchAsync:(void (^)())block
{
    dispatch_async(self.queue, block);
}


-(void)dispatchSync:(void (^)())block
{
    const char *queueName = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    
    if ( strcmp(queueName, _queueName.UTF8String) == 0 )
    {
        block();
    }
    
    else
    {
        dispatch_sync(self.queue, block);
    }
}



@end
