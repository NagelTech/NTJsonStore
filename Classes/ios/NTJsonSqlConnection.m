//
//  NTJsonSqlConnection.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 4/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import "NTJsonStore+Private.h"


static sqlite3 *CONNECTION_CLOSED = (sqlite3 *)(void *)1;


@interface NTJsonSqlConnection ()
{
    sqlite3 *_db; // nil = auto open, other = connection, CONNECTION_CLOSED = closed or failed to open
    NSString *_connectionName;
    NSString *_filename;
    NSString *_queueName;
    NSError *_lastError;
    int _nextTransactionId;
    
    dispatch_queue_t _queue;
}

@property (nonatomic,readonly) NSString *queueName;

@end


#ifdef NTJsonStore_SHOW_SQL
#   define LOG_SQL(format, ...) NSLog(@"Sql[%@]: " format, self.connectionName, ##__VA_ARGS__)
#else
#   define LOG_SQL(format, ...)
#endif


@implementation NTJsonSqlConnection


-(id)initWithFilename:(NSString *)filename connectionName:(NSString *)connectionName
{
    self = [super init];
    
    if ( self )
    {
        _filename = filename;
        _connectionName = connectionName;
        _queueName = [NSString stringWithFormat:@"com.nageltech.NTJsonStore:%@@%@", connectionName, filename];
        _queue = dispatch_queue_create(_queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}


-(void)dealloc
{
    [self close];
}


-(BOOL)open
{
    if ( _db == CONNECTION_CLOSED )
        _db = nil; // reset to auto open
    
    return (self.db) ? YES : NO;
}


-(void)close
{
    if ( _db )
    {
        if ( _db != CONNECTION_CLOSED )
            sqlite3_close(_db);
        
        _db = CONNECTION_CLOSED;    // explicitly closed not (no auto open)
    }
}


-(void)validateQueue
{
    // Make sure the connection is being accessed on the correct queue...
    // if this happens it means our code is broken...
    
#ifdef DEBUG
    
    const char *queueName = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    
    NSAssert(strcmp(queueName, _queueName.UTF8String) == 0, @"Attempt to access SQL connection from the wrong queue.");
    
#endif
    
}


-(BOOL)exists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.filename];
}


-(sqlite3 *)db
{
    [self validateQueue];
    
    if ( !_db ) // nil = auto open
    {
        BOOL newDatabase = ![self exists];
        
        int status = sqlite3_open_v2([self.filename cStringUsingEncoding:NSUTF8StringEncoding], &_db, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_NOMUTEX, NULL);
        
        if ( status != SQLITE_OK )
        {
            _lastError = [NSError NSJsonStore_errorWithSqlite3:_db];
            
            LOG_ERROR(@"Failed to open database: %@", _lastError.localizedDescription);
            
            _db = CONNECTION_CLOSED;

            return nil;
        }
        
        LOG_SQL(@"Database opened, location %@", self.filename);
        
        if ( newDatabase )
        {
            NSString *journalMode = [self execValueSql:@"PRAGMA journal_mode=wal;" args:nil];
            
            if ( ![journalMode isEqualToString:@"wal"] )
            {
                LOG_ERROR(@"Unable to enable WAL mode, current mode - %@", journalMode);
                // do not fail in this case.
            }
            else
                LOG_SQL(@"WAL mode enabled.");
        }
    }
    
    else if ( _db == CONNECTION_CLOSED )
    {
        _lastError = [NSError NSJsonStore_errorWithCode:NTJsonStoreErrorClosed];
    }
    
    return (_db == CONNECTION_CLOSED) ? nil : _db;
}


-(sqlite3_stmt *)statementWithSql:(NSString *)sql args:(NSArray *)args
{
    sqlite3_stmt *statement = NULL;
    
    if ( !sql )
        sql = @"";
    
    if ( ![sql hasSuffix:@";"] )
        sql = [sql stringByAppendingString:@";"];
    
    if ( !self.db )
        return NULL;    // avoid even calling prepare
    
#ifdef NTJsonStore_SHOW_SQL
    
    if ( [args count] )
    {
        //       NTLogDebug(@"    Args: %@", [args componentsJoinedByString:@", "]);
        
        NSMutableString *expSql = [NSMutableString stringWithString:sql];
        
        NSInteger offset = 0;
        
        for(id arg in args)
        {
            NSString *value;
            
            if ( arg == nil || arg == [NSNull null] )
                value = @"null";
            
            else if ( [arg isKindOfClass:[NSString class]] )
                value = [NSString stringWithFormat:@"\'%@\'", arg];
            
            else if ( [arg isKindOfClass:[NSNumber class]] )
                value = [arg stringValue];
            
            else if ( [arg isKindOfClass:[NSData class]] )
                value = [NSString stringWithFormat:@"[BLOB %d]", (int)((NSData *)arg).length];
            
            else
                value = [NSString stringWithFormat:@"[%@]", NSStringFromClass([arg class])];
            
            NSRange pos = [expSql rangeOfString:@"?" options:0 range:NSMakeRange(offset, expSql.length-offset)];
            
            if (pos.location == NSNotFound )
                break; // unlikely
            
            [expSql replaceCharactersInRange:pos withString:value];
            
            offset = pos.location + value.length;
        }
        
        LOG_SQL(@"%@", expSql);
    }
    
    else
        LOG_SQL(@"%@", sql);
    
#endif
    
    NSUInteger status = sqlite3_prepare_v2(self.db, [sql cStringUsingEncoding:NSUTF8StringEncoding], (int)sql.length, &statement, NULL);
    
    if (status != SQLITE_OK )
    {
        _lastError = [NSError NSJsonStore_errorWithSqlite3:_db];
        LOG_ERROR(@"Failed to prepare statement %@ - %@", sql, _lastError.localizedDescription);
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
                    _lastError = [NSError NSJsonStore_errorWithCode:NTJsonStoreErrorInvalidSqlArgument format:@"Invalid Sql Argument - unsupported numeric type %s", numType];
                    
                    LOG_ERROR(@"%@", _lastError);
                    
                    sqlite3_finalize(statement);
                    
                    return NULL;
                }
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
                _lastError = [NSError NSJsonStore_errorWithCode:NTJsonStoreErrorInvalidSqlArgument format:@"Invalid Sql Argument - unsupported type: %@", NSStringFromClass([arg class])];
                
                LOG_ERROR(@"%@", _lastError.localizedDescription);
                
                sqlite3_finalize(statement);
                
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
    
    if ( status != SQLITE_DONE && status != SQLITE_ROW )
    {
        _lastError = [NSError NSJsonStore_errorWithSqlite3:self.db];
        
        LOG_ERROR(@"Failed to execute statement - %@", _lastError.localizedDescription);
        
        sqlite3_finalize(statement);
        
        return NO;
    }
    
    sqlite3_finalize(statement);
    
    return YES;
}


-(id)execValueSql:(NSString *)sql args:(NSArray *)args
{
    sqlite3_stmt *statement = [self statementWithSql:sql args:args];
    
    if ( !statement )
        return nil;
    
    int status = sqlite3_step(statement);
    
    if ( status != SQLITE_ROW )
    {
        _lastError = [NSError NSJsonStore_errorWithSqlite3:self.db];
        
        LOG_ERROR(@"Failed to execute statement - %@", _lastError.localizedDescription);
        
        sqlite3_finalize(statement);
        
        return nil;
    }
    
    id value;
    
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
            value = [NSNull null];
            break;
            
        default:
        {
            _lastError = [NSError NSJsonStore_errorWithCode:NTJsonStoreErrorInvalidSqlArgument];
            value = nil;
            break;
        }
    }
    
    sqlite3_finalize(statement);
    
    LOG_SQL(@"    = %@", value ?: @"(null)");
    
    return value;
}


-(NSString *)beginTransaction
{
    [self validateQueue]; // do this before we access _nextTransactionId
    
    NSString *transactionId = [NSString stringWithFormat:@"%@_%04d", self.connectionName, _nextTransactionId++];
    
    BOOL success = [self execSql:[NSString stringWithFormat:@"SAVEPOINT %@;", transactionId] args:nil];
    
    return (success) ? transactionId : nil;
}


-(BOOL)commitTransation:(NSString *)transactionId
{
    return [self execSql:[NSString stringWithFormat:@"RELEASE SAVEPOINT %@;", transactionId] args:nil];
}


-(BOOL)rollbackTransation:(NSString *)transactionId
{
    return [self execSql:[NSString stringWithFormat:@"ROLLBACK TO SAVEPOINT %@; RELEASE SAVEPOINT %@;", transactionId, transactionId] args:nil];
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
