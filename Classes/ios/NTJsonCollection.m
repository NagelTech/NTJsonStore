//
//  NTJsonCollection.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonStore+Private.h"


@interface NTJsonCollection ()
{
    NTJsonStore __weak *_store;
    NTJsonSqlConnection *_connection;

    BOOL _isNewCollection;
    NSString *_name;
    NSArray *_columns;
    NSArray *_indexes;
    NTJsonObjectCache *_objectCache;
    NSDictionary *_defaultJson;
    NSError *_lastError;
    
    BOOL _isClosing;
    BOOL _isClosed;
    
    NSMutableDictionary *_metadata;
    
    NSMutableArray *_pendingColumns;
    NSMutableArray *_pendingIndexes;
}

@property (nonatomic,readonly) NTJsonSqlConnection *connection;

@end


@implementation NTJsonCollection


#pragma mark - constructors


-(id)initWithStore:(NTJsonStore *)store name:(NSString *)name
{
    self = [super init];
    
    if ( self )
    {
        _store = store;
        _name = name;
        _objectCache = [[NTJsonObjectCache alloc] init];
        _columns = nil; // these are lazy loaded
        _indexes = nil; // lazy load
        _defaultJson = nil;
        
        _pendingColumns = [NSMutableArray array];
        _pendingIndexes = [NSMutableArray array];
        _connection = [[NTJsonSqlConnection alloc] initWithFilename:store.storeFilename connectionName:self.name];
    }
    
    return self;
}


-(id)initNewCollectionWithStore:(NTJsonStore *)store name:(NSString *)name
{
    self = [self initWithStore:store name:name];
    
    if ( self )
    {
        _isNewCollection = YES;
        _columns = [NSArray array];
        _indexes = [NSArray array];
        _defaultJson = nil;
    }
    
    return self;
}


-(void)dealloc
{
    [self close];   // just to be sure
}


#pragma mark - misc


-(NSString *)description
{
    return self.name;
}


-(dispatch_queue_t)getCompletionQueue:(dispatch_queue_t)completionQueue
{
    if ( (id)completionQueue == (id)NTJsonStoreSerialQueue )
        return self.connection.queue;   // a little magic here
    
    if ( completionQueue )
        return completionQueue;
    
    if ( [NSThread isMainThread] )
        return dispatch_get_main_queue();
    
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}


-(void)dispatchCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler
{
    if ( !completionQueue )
        return ;
    
    if ( completionQueue == self.connection.queue )
        completionHandler();
    
    else
        dispatch_async(completionQueue, completionHandler);
}


+(NSMutableDictionary *)flattenDictionary:(NSDictionary *)dictionary
{
    NSMutableDictionary *flat = [NSMutableDictionary dictionary];
    
    for(NSString *key in dictionary.allKeys)
    {
        id value = dictionary[key];
        
        if ( [value isKindOfClass:[NSDictionary class]] )
        {
            NSDictionary *flatChildren = [self flattenDictionary:value];
            
            for(NSString *childKey in flatChildren.allKeys)
            {
                NSString *keyPath = [NSString stringWithFormat:@"%@.%@", key, childKey];
                
                flat[keyPath] = flatChildren[childKey];
            }
        }
        else
            flat[key] = value;
    }
    
    return flat;
}


-(BOOL)validateEnvironment
{
    if ( _isClosed || _isClosing )
    {
        _lastError = [NSError NTJsonStore_errorWithCode:NTJsonStoreErrorClosed];
        return NO;
    }
    
    if ( !_store )
    {
        // The store has been deallocated and things are now a mess.
        
        _lastError = [NSError NTJsonStore_errorWithCode:NTJsonStoreErrorClosed];
        return NO;
    }
    
    return YES;
}


-(int)cacheSize
{
    return (_objectCache) ? _objectCache.cacheSize : -1;
}


-(void)setCacheSize:(int)cacheSize
{
    if ( (cacheSize < 0 && !_objectCache) || (_objectCache.cacheSize == cacheSize) )
        return;
    
    if ( cacheSize < 0 )
        _objectCache = nil; // no cache
    
    else
    {
        if ( !_objectCache )
            _objectCache = [[NTJsonObjectCache alloc] initWithCacheSize:cacheSize];
        
        else
            _objectCache.cacheSize = cacheSize;
    }
}


-(void)flushCache
{
    [_objectCache flush];
}


#pragma mark - config


-(void)applyConfig:(NSDictionary *)config
{
    NSNumber *cacheSize = config[@"cacheSize"];
    NSDictionary *defaultJson = config[@"defaultJson"];
    NSArray *indexes = config[@"indexes"];
    NSArray *uniqueIndexes = config[@"uniqueIndexes"];
    NSArray *queryableFields = config[@"queryableFields"];
    
    if ( [cacheSize isKindOfClass:[NSNumber class]] )
    {
        self.cacheSize = [cacheSize intValue];
    }
    
    if ( [defaultJson isKindOfClass:[NSDictionary class]] )
    {
        self.defaultJson = defaultJson;
    }
    
    // We allow either a single string or an array of strings for indexes, uniqueIndexes and queryableFields. detect single string case
    // and wrap them in an array to make things consistent...
    
    if ( [indexes isKindOfClass:[NSString class]] )
        indexes = @[indexes];
    
    if( [uniqueIndexes isKindOfClass:[NSString class]] )
        uniqueIndexes = @[uniqueIndexes];
    
    if ( [queryableFields isKindOfClass:[NSString class]] )
        queryableFields = @[queryableFields];
    
    if ( [indexes isKindOfClass:[NSArray class]] )
    {
        for (NSString *index in indexes)
        {
            if ( [index isKindOfClass:[NSString class]] )
                [self addIndexWithKeys:index];
        }
    }
    
    if ( [uniqueIndexes isKindOfClass:[NSArray class]] )
    {
        for (NSString *uniqueIndex in uniqueIndexes)
        {
            if ( [uniqueIndex isKindOfClass:[NSString class]] )
                [self addUniqueIndexWithKeys:uniqueIndex];
        }
    }
    
    if ( [queryableFields isKindOfClass:[NSArray class]] )
    {
        for (NSString *queryableField in queryableFields)
        {
            if ( [queryableField isKindOfClass:[NSString class]] )
                [self addQueryableFields:queryableField];
        }

    }
}


-(BOOL)applyConfigFile:(NSString *)filename
{
    NSDictionary *config = [NTJsonStore loadConfigFile:filename];
    
    if ( !config )
        return NO;
    
    [self applyConfig:config];
    
    return YES;
}


#pragma mark - close


-(void)close
{
    if ( _isClosing || _isClosed )
        return ; // already in the process of closing or we are closed...
    
    _isClosing = YES; // do not accept new requests.
    
    // by doing this on our queue, we can be sure that any items that were already queued have completed...
    
    [self.connection dispatchSync:^
    {
        [self.connection close];
        
        // release all memory associated with this connection
        
        _store = nil;
        _connection = nil;
        _columns = nil;
        _indexes = nil;
        _objectCache = nil;
        _defaultJson = nil;
        _pendingColumns = nil;
        _pendingIndexes = nil;
        
        _isClosed = YES;
        _isClosing = NO;
    }];
    
    return ;
}


#pragma mark - defaultJson


-(NSString *)defaultJsonMetadataKey
{
    return [NSString stringWithFormat:@"%@/defaultJson", self.name];
}


-(NSDictionary *)defaultJson
{
    __block NSDictionary *defaultJson;
    
    [self.connection dispatchSync:^{
        if ( !_defaultJson )
        {
            _defaultJson = [self.store metadataWithKey:[self defaultJsonMetadataKey]] ?: [NSDictionary dictionary];
        }
        
        defaultJson = _defaultJson;
    }];
    
    return defaultJson;
}


-(NSArray *)detectChangedColumnsInDefaultJson:(NSDictionary *)defaultJson
{
    NSMutableDictionary *newDefaults = [self.class flattenDictionary:defaultJson];
    NSMutableDictionary *oldDefaults = [self.class flattenDictionary:self.defaultJson];
    NSMutableSet *changedKeyPaths = [NSMutableSet set];
    
    // find updates/deletes...
    
    for(NSString *keyPath in oldDefaults.allKeys)
    {
        id oldValue = oldDefaults[keyPath];
        id newValue = newDefaults[keyPath];
        
        if ( ![oldValue isEqual:newValue] )
            [changedKeyPaths addObject:keyPath];
        
        [newDefaults removeObjectForKey:keyPath];
    }
    
    // add inserts...
    
    [changedKeyPaths addObjectsFromArray:newDefaults.allKeys];
    
    // figure out if any of our columns are changed as a result...
    
    NSMutableArray *changedColumns = [NSMutableArray array];
    
    for(NTJsonColumn *column in self.columns)
    {
        if ( [changedKeyPaths containsObject:column.name] )
            [changedColumns addObject:column];
    }
    
    return [changedColumns copy];
}


-(void)setDefaultJson:(NSDictionary *)defaultJson
{
    [self.connection dispatchAsync:^{
        if ( [self.defaultJson isEqualToDictionary:defaultJson] )
            return ; // no changes, skip all this craziness
        
        // If defaults have chaged for any existing columns, we need to add them to our pending columns list
        // so they can be re-generated...
        
        NSArray *changedColumns = [self detectChangedColumnsInDefaultJson:defaultJson];
        
        for(NTJsonColumn *column in changedColumns)
        {
            if ( ![_pendingColumns NTJsonStore_find:^BOOL(NTJsonColumn *item) { return [item.name isEqualToString:column.name]; }] )
                [_pendingColumns addObject:column];
        }
        
        // Update our internal variables...
        
        _defaultJson = [defaultJson copy];
        
        // save our metadata...

        [self.store saveMetadataWithKey:[self defaultJsonMetadataKey] value:_defaultJson];
    }];
}


#pragma mark - Schema Management


-(BOOL)schema_createCollection
{
    if ( !_isNewCollection )
        return YES;
    
    LOG_DBG(@"Adding table: %@", self.name);
    
    _isNewCollection = NO;
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([%@] INTEGER PRIMARY KEY AUTOINCREMENT, [__json__] BLOB);", self.name, NTJsonRowIdKey];
    
    _columns = [NSArray array];
    _indexes = [NSArray array];
    
    __block BOOL success = YES;
    
    [self.store.connection dispatchSync:^{
        if ( ![self.store.connection execSql:sql args:nil] )
        {
            _lastError = self.store.connection.lastError;
            success = NO;
        }
    }];
    
    return success;
}


-(BOOL)schema_addOrUpdatePendingColumns
{
    if ( !_pendingColumns.count )
        return YES;
    
    // First, we need to add the columns to the table...
    // (SQLITE only allows you to add one at a time)
    
    NSMutableArray *newColumns = [NSMutableArray arrayWithArray:_columns];
    
    for(NTJsonColumn *column in _pendingColumns)
    {

        if ( [_columns NTJsonStore_find:^BOOL(NTJsonColumn *existing) { return [existing.name isEqualToString:column.name]; }] )
        {
            LOG_DBG(@"Updating column: %@.%@", self.name, column.name);
            continue; // don't re-add columns that already exist
        }
        
        [newColumns addObject:column];
        
        LOG_DBG(@"Adding column: %@.%@", self.name, column.name);

        NSString *alterSql = [NSString stringWithFormat:@"ALTER TABLE [%@] ADD COLUMN [%@];", self.name, column.name];
        
        __block BOOL success = YES;
        
        [self.store.connection dispatchSync:^{
            if ( ![self.store.connection execSql:alterSql args:nil] )
            {
                _lastError = self.store.connection.lastError;
                LOG_ERROR(@"Failed to add column %@.%@ - %@", self.name, column.name, _lastError.localizedDescription);
                success = NO;
            }
        }];
        
        if ( !success )
            return NO;
    }
    
    // Now we need to populate the data...
    
    sqlite3_stmt *selectStatement = [self.connection statementWithSql:[NSString stringWithFormat:@"SELECT [%@], [__json__] FROM [%@]", NTJsonRowIdKey, self.name] args:nil];
    
    if ( !selectStatement )
    {
        _lastError = self.connection.lastError;
        return NO;  // todo: cleanup here somehow? transaction?
    }
    
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE [%@] = ?;",
                           self.name,
                           [[_pendingColumns NTJsonStore_transform:^id(NTJsonColumn *column) { return [NSString stringWithFormat:@"[%@] = ?", column.name]; }] componentsJoinedByString:@", "],
                           NTJsonRowIdKey];
    int status;
    
    while ( (status=sqlite3_step(selectStatement)) == SQLITE_ROW )
    {
        int rowid = sqlite3_column_int(selectStatement, 0);
        
        // todo: take advantage of any cached JSON... cache it to???
        
        NSData *jsonData = [NSData dataWithBytes:sqlite3_column_blob(selectStatement, 1) length:sqlite3_column_bytes(selectStatement, 1)];
        
        NSError *error;
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:&error];
        
        if ( !json )
        {
            LOG_ERROR(@"Unable to parse JSON for %@:%d - %@", self.name, rowid, error.localizedDescription);
            continue; // forge on ahead, do not consider this fatal.
        }
        
        // Extract our data...
        
        NSMutableArray *values = [NSMutableArray array];
        
        [self extractValuesInColumns:_pendingColumns fromJson:json intoArray:values];
        [values addObject:@(rowid)];
        
        // Perform our update...
        
        BOOL success = [self.connection execSql:updateSql args:values];
        
        if ( !success )
        {
            LOG_ERROR(@"sql update failed for %@:%d - %@", self.name, rowid, self.connection.lastError.localizedDescription);
            // continue on here, do our best.
        }
    }
    
    sqlite3_finalize(selectStatement);
    
    // update to our new column list...
    
    _columns = [newColumns copy];
    
    [_pendingColumns removeAllObjects];
    
    return YES;
}


-(BOOL)schema_addPendingIndexes
{
    if ( !_pendingIndexes.count )
        return YES;
    
    for(NTJsonIndex *index in _pendingIndexes)
    {
        LOG_DBG(@"Adding index: %@.%@ (%@)", self.name, index.name, index.keys);
        
        __block BOOL success = YES;
        [self.store.connection dispatchSync:^{
            if ( ![self.store.connection execSql:[index sqlWithTableName:self.name] args:nil])
            {
                _lastError = self.store.connection.lastError;
                LOG_ERROR(@"Failed to create index: %@.%@ (%@) - %@", self.name, index.name, index.keys, _lastError.localizedDescription);
                success = NO;
            }
        }];
        
        if ( !success )
            return NO;
    }
    
    _indexes = [self.indexes arrayByAddingObjectsFromArray:_pendingIndexes];

    [_pendingIndexes removeAllObjects];
    
    return YES;
}


-(BOOL)_ensureSchema
{
    if ( ![self validateEnvironment] )
        return NO;
    
    if ( !_isNewCollection
        && !_pendingColumns.count
        && !_pendingIndexes.count )
        return YES; // no schema changes, so we can just return
    
    if ( ![self schema_createCollection] )
        return NO;
    
    if ( ![self schema_addOrUpdatePendingColumns] )
        return NO;
    
    if ( ![self schema_addPendingIndexes] )
        return NO;
    
    return YES;
}


-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _ensureSchema];
        NSError *error = (success) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(error);
        }];
    }];
}


-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSError *error))completionHandler
{
    [self beginEnsureSchemaWithCompletionQueue:nil completionHandler:completionHandler];
}


-(BOOL)ensureSchemaWithError:(NSError **)error
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _ensureSchema];
    }];
    
    if ( error )
        *error = (success) ? nil : _lastError;
    
    return success;
}


-(BOOL)ensureSchema
{
    return [self ensureSchemaWithError:nil];
}


#pragma mark - Column Support


-(NSArray *)columns
{
    __block NSArray *columns;

    [self.connection dispatchSync:^{
        
        // if we don't have our list of columns, let's extract them...
        
        if ( !_columns )
        {
            if ( [self validateEnvironment] )
            {
                NSMutableArray *columns = [NSMutableArray array];
                sqlite3_stmt *statement = [self.connection statementWithSql:[NSString stringWithFormat:@"PRAGMA table_info(%@);", self.name] args:nil];
                
                if ( !statement )
                {
                    _lastError = self.connection.lastError;
                    columns = nil;
                    return ;
                }
                
                int status;
                
                while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
                {
                    NSString *columnName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
                    
                    if ( [columnName isEqualToString:NTJsonRowIdKey] || [columnName isEqualToString:@"__json__"] )
                        continue;
                    
                    [columns addObject:[NTJsonColumn columnWithName:columnName]];
                }
                
                _columns = [columns copy];
                
                sqlite3_finalize(statement);
                
            } // if validateEnv
            
        } // if !columns
        
        columns = _columns;
    }];
    
    return columns;
}


-(void)extractValuesInColumns:(NSArray *)columns fromJson:(NSDictionary *)json intoArray:(NSMutableArray *)values
{
    for(NTJsonColumn *column in columns)
    {
        id value = [json NTJsonStore_objectForKeyPath:column.name];
        
        if ( !value )
            value = [_defaultJson NTJsonStore_objectForKeyPath:column.name];
        
        if ( !value )
            value = [NSNull null];
        
        [values addObject:value];
    }
}


-(BOOL)scanSqlForNewColumns:(NSString *)sql     // returns YES if new columns were found
{
    if ( !sql )
        return NO; // nothing to parse
    
    __block BOOL newColumnsAdded = NO;
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[.+?\\]" options:0 error:nil];
    
    [regex enumerateMatchesInString:sql
                            options:0
                              range:NSMakeRange(0, sql.length)
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *columnName = [sql substringWithRange:result.range];
        
        // massage the column name a bit...
        
        if ( [columnName hasPrefix:@"["] )
            columnName = [columnName substringFromIndex:1];
        
        if ( [columnName hasSuffix:@"]"] )
            columnName = [columnName substringToIndex:columnName.length-1];
        
        // Ignore our row id, it's always available...
        
        if ( [columnName isEqualToString:NTJsonRowIdKey] )
            return ;
        
        // check existing column list...
        
        NTJsonColumn *column = [self.columns NTJsonStore_find:^BOOL(NTJsonColumn *column) { return [column.name isEqualToString:columnName]; }];
        
        // and pending columns...
        
        if ( !column )
            column = [_pendingColumns NTJsonStore_find:^BOOL(NTJsonColumn *column) { return [column.name isEqualToString:columnName]; }];
        
        if ( column )
            return ;    // found this column
        
        // We have a new column, add to pending list...
        
        column = [NTJsonColumn columnWithName:columnName];
        
        [_pendingColumns addObject:column];
        
        newColumnsAdded = YES;
    }];
    
    return newColumnsAdded;
}


-(void)addQueryableFields:(NSString *)fields
{
    [self.connection dispatchAsync:^{
        [self scanSqlForNewColumns:fields];
    }];
}


#pragma mark - Index Support


-(NSArray *)indexes
{
    __block NSArray *indexes;
    
    [self.connection dispatchSync:^{
        
        if ( !_indexes )
        {
            
            if ( [self validateEnvironment] )
            {
                NSMutableArray *indexes = [NSMutableArray array];
                
                sqlite3_stmt *statement = [self.connection statementWithSql:@"SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=?" args:@[self.name]];
                
                if ( !statement )
                {
                    _lastError = self.connection.lastError;
                    indexes = nil;
                    return ;
                }
                
                int status;
                
                while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
                {
                    NSString *sql = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)];
                    
                    if ( !sql.length )
                        continue ;
                    
                    NTJsonIndex *index = [NTJsonIndex indexWithSql:sql];
                    
                    if ( !index )
                    {
                        LOG_ERROR(@"Ignoring index we can't parse - %@", sql);
                        continue;
                    }
                    
                    [indexes addObject:index];
                }
                
                sqlite3_finalize(statement);
                
                _indexes = [indexes copy];
                
            } // if validate...
            
        } // if !indexes
        
        indexes = _indexes;
    }];
    
    return indexes;
}


-(NSString *)createIndexNameWithIsUnique:(BOOL)isUnique
{
    const int MAX_TRIES = 10;
    
    int base = (int)self.indexes.count + (int)_pendingIndexes.count;
    
    for(int index=0; index<MAX_TRIES; index++)
    {
        NSString *name = [NSString stringWithFormat:@"%@_%@_%d", (isUnique) ? @"UX" : @"IX", self.name, base+index];
        
        NTJsonIndex *existing = [self.indexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return [index.name isEqualToString:name]; }];
        
        if ( !existing )
            existing = [_pendingIndexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return [index.name isEqualToString:name]; }];
        
        if ( !existing )
            return name;
    }
    
    return nil;
}


-(void)addIndexWithKeys:(NSString *)keys isUnique:(BOOL)isUnique
{
    [self.connection dispatchAsync:^{
        // First off, let's see if it already exists...
        
        if ( [self.indexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return (index.isUnique == isUnique) && [index.keys isEqualToString:keys]; }] )
            return ;
        
        if ( [_pendingIndexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return (index.isUnique == isUnique) && [index.keys isEqualToString:keys]; }] )
            return ;
        
        [self scanSqlForNewColumns:keys];
        
        NSString *name = [self createIndexNameWithIsUnique:isUnique];
        
        NTJsonIndex *index = [NTJsonIndex indexWithName:name keys:keys isUnique:isUnique];
        
        [_pendingIndexes addObject:index];
    }];
}


-(void)addIndexWithKeys:(NSString *)keys
{
    [self addIndexWithKeys:keys isUnique:NO];
}


-(void)addUniqueIndexWithKeys:(NSString *)keys
{
    [self addIndexWithKeys:keys isUnique:YES];
}


#pragma mark - insert


-(NTJsonRowId)_insert:(NSDictionary *)json
{
    // Be careful of any side effects in this code impacting memory (caching, etc). It is used by
    // insertBatch which runs in a transaction so we need to be safe for rollbacks.
    
    if ( ![self _ensureSchema] )
        return 0;
    
    NSMutableArray *columnNames = [NSMutableArray arrayWithObject:@"__json__"];
    [columnNames addObjectsFromArray:[self.columns NTJsonStore_transform:^id(NTJsonColumn *column) { return [NSString stringWithFormat:@"[%@]", column.name]; }]];
    
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO [%@] (%@) VALUES (%@);",
                     self.name,
                     [columnNames componentsJoinedByString:@", "],
                     [@"" stringByPaddingToLength:columnNames.count*3-2 withString:@"?, " startingAtIndex:0]];
    
    NSMutableArray *values = [NSMutableArray array];
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    
    if ( !jsonData )
    {
        _lastError = error;
        return 0;
    }
    
    [values addObject:jsonData];
    
    [self extractValuesInColumns:self.columns fromJson:json intoArray:values];
    
    if ( ![self.connection execSql:sql args:values] )
    {
        _lastError = self.connection.lastError;
        return 0;
    }
    
    NTJsonRowId rowid = sqlite3_last_insert_rowid(self.connection.db);
    
    return rowid;
}


-(void)beginInsert:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        NTJsonRowId rowid = [self _insert:json];
        NSError *error = (rowid) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(rowid, error);
        }];
    }];
}


-(void)beginInsert:(NSDictionary *)json completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler
{
    [self beginInsert:json completionQueue:nil completionHandler:completionHandler];
}


-(NTJsonRowId)insert:(NSDictionary *)json error:(NSError **)error
{
    __block NTJsonRowId rowid;
    
    [self.connection dispatchSync:^{
        rowid = [self _insert:json];
        if ( error )
            *error = (rowid) ? nil : _lastError;
    }];
    
    return rowid;
}


-(NTJsonRowId)insert:(NSDictionary *)json
{
    return [self insert:json error:nil];
}


#pragma mark - insertBatch


-(BOOL)_insertBatch:(NSArray *)items
{
    if ( !items.count )
        return YES;
    
    if ( ![self validateEnvironment] )
        return NO;
    
    NSString *transactionId = [self.connection beginTransaction];
    
    if ( !transactionId )
        return NO;
    
    for(NSDictionary *item in items)
    {
        NTJsonRowId rowid = [self _insert:item];
        
        if ( !rowid )
        {
            [self.connection rollbackTransation:transactionId];
            return NO;
        }
    }
    
    [self.connection commitTransation:transactionId];
    
    return YES;
}


-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _insertBatch:items];
        NSError *error = (success) ? nil : _lastError;
       
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(error);
        }];
    }];
}


-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(NSError *error))completionHandler
{
    [self beginInsertBatch:items completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)insertBatch:(NSArray *)items error:(NSError **)error
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _insertBatch:items];

        if ( error )
            *error = (success) ? nil : _lastError;
    }];
    
    return success;
}


-(BOOL)insertBatch:(NSArray *)items
{
    return [self insertBatch:items error:nil];
}


#pragma mark - update


-(BOOL)_update:(NSDictionary *)json
{
    if ( ![self _ensureSchema] )
        return NO;
    
    NTJsonRowId rowid = [json[NTJsonRowIdKey] longLongValue];
    
    NSMutableArray *columnNames = [NSMutableArray arrayWithObject:@"__json__"];
    [columnNames addObjectsFromArray:[self.columns NTJsonStore_transform:^id(NTJsonColumn *column) { return column.name; }]];
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE [%@] = ?;",
                     self.name,
                     [[columnNames NTJsonStore_transform:^id(NSString *columnName) { return [NSString stringWithFormat:@"[%@] = ?", columnName]; }] componentsJoinedByString:@", "],
                     NTJsonRowIdKey];
    
    NSMutableArray *values = [NSMutableArray array];
    
    NSError *error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&error];
    
    if ( !jsonData )
    {
        _lastError = error;
        return NO;
    }
    
    [values addObject:jsonData];
    
    [self extractValuesInColumns:self.columns fromJson:json intoArray:values];
    
    [values addObject:@(rowid)];
    
    BOOL success = [self.connection execSql:sql args:values];
    
    if ( success )
        [_objectCache addJson:json withRowId:rowid];
    
    return success;
}


-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _update:json];
        NSError *error = (success) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(error);
        }];
    }];
}


-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler
{
    [self beginUpdate:json completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)update:(NSDictionary *)json error:(NSError **)error
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _update:json];
        if ( error )
            *error = (success) ? nil : _lastError;
    }];
    
    return success;
}


-(BOOL)update:(NSDictionary *)json
{
    return [self update:json error:nil];
}


#pragma mark - remove


-(BOOL)_remove:(NSDictionary *)json
{
    if( ![self _ensureSchema] )
        return NO;
    
    long long rowid = [json[NTJsonRowIdKey] longLongValue];

    BOOL success = [self.connection execSql:[NSString stringWithFormat:@"DELETE FROM [%@] WHERE [%@] = ?", self.name, NTJsonRowIdKey] args:@[@(rowid)]];
    
    if ( success )
        [_objectCache removeObjectWithRowId:rowid];
    
    return success;
}


-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^
    {
        BOOL success = [self _remove:json];
        NSError *error = (success) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(error);
        }];
    }];
}


-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler
{
    [self beginRemove:json completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)remove:(NSDictionary *)json error:(NSError **)error
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _remove:json];
        if ( error )
            *error = (success) ? nil : _lastError;
    }];
    
    return success;
}


-(BOOL)remove:(NSDictionary *)json
{
    return [self remove:json error:nil];
}


#pragma mark - count


-(int)_countWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];

    if ( ![self _ensureSchema] )
        return -1;
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT COUNT(*) FROM [%@]", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    id count = [self.connection execValueSql:sql args:args];
    
    return (count) ? [count intValue] : -1;
}


-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        int count = [self _countWhere:where args:args];
        NSError *error = (count != -1) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(count, error);
        }];
    }];
}


-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginCountWhere:where args:args completionQueue:nil completionHandler:completionHandler];
}


-(int)countWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error
{
    __block int count;
    
    [self.connection dispatchSync:^{
        count = [self _countWhere:where args:args];
        if ( error )
            *error = (count != -1) ? nil : _lastError;
    }];
    
    return count;
}


-(int)countWhere:(NSString *)where args:(NSArray *)args
{
    return [self countWhere:where args:args error:nil];
}


-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginCountWhere:nil args:nil completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginCountWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginCountWhere:nil args:nil completionQueue:nil completionHandler:completionHandler];
}


-(int)countWithError:(NSError **)error
{
    return [self countWhere:nil args:nil error:error];
}


-(int)count
{
    return [self countWhere:nil args:nil error:nil];
}


#pragma mark - find


-(NSArray *)_findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit
{
    [self scanSqlForNewColumns:where];
    [self scanSqlForNewColumns:orderBy];

    if ( ![self _ensureSchema] )
        return nil;
    
    // Ok, now we can actually do the query...
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT [%@], [__json__] FROM %@", NTJsonRowIdKey, self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( orderBy )
        [sql appendFormat:@" ORDER BY %@", orderBy];
    
    if ( limit > 0 )
        [sql appendFormat:@" LIMIT %d", limit];
    
    sqlite3_stmt *selectStatement = [self.connection statementWithSql:sql args:args];
    
    if ( !selectStatement )
        return nil;
    
    // Now we can extract our results!
    
    NSMutableArray *items = [NSMutableArray array];
    
    int status;
    
    while ( (status=sqlite3_step(selectStatement)) == SQLITE_ROW )
    {
        NTJsonRowId rowid = sqlite3_column_int64(selectStatement, 0);
        
        NSDictionary *json = [_objectCache jsonWithRowId:rowid];
        
        if ( !json )
        {
            NSData *jsonData = [NSData dataWithBytes:sqlite3_column_blob(selectStatement, 1) length:sqlite3_column_bytes(selectStatement, 1)];
            
            NSError *error;
            
            NSDictionary *rawJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
            
            if ( !rawJson )
            {
                _lastError = error;
                LOG_ERROR(@"Unable to parse JSON for %@:%lld - %@", self.name, rowid, error.localizedDescription);
                sqlite3_finalize(selectStatement);
                return nil;
            }
            
            // Make sure __rowid__ is valid and correct.
            
            if (  ![rawJson[NTJsonRowIdKey] isEqualToNumber:@(rowid)] )
            {
                NSMutableDictionary *mutableJson = [rawJson mutableCopy];
                mutableJson[NTJsonRowIdKey] = @(rowid);
                rawJson = [mutableJson copy];
            }
            
            json = (_objectCache) ? [_objectCache addJson:rawJson withRowId:rowid] : rawJson;
        }
        
        [items addObject:json];
    }
    
    if ( status != SQLITE_DONE )
    {
        _lastError = [NSError NTJsonStore_errorWithSqlite3:self.connection.db];
        items = nil; // failure
    }
    
    sqlite3_finalize(selectStatement);

    return [items copy];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        NSArray *items = [self _findWhere:where args:args orderBy:orderBy limit:limit];
        NSError *error = (items) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(items, error);
        }];
    }];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:limit completionQueue:nil completionHandler:completionHandler];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit error:(NSError **)error
{
    __block NSArray *items;
    
    [self.connection dispatchSync:^{
        items = [self _findWhere:where args:args orderBy:orderBy limit:limit];
        if ( error )
            *error = (items) ? nil : _lastError;
    }];
    
    return items;
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit
{
    return [self findWhere:where args:args orderBy:orderBy limit:limit error:nil];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:0 completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:0 completionQueue:nil completionHandler:completionHandler];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy error:(NSError **)error
{
    return [self findWhere:where args:args orderBy:orderBy limit:0 error:error];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy
{
    return [self findWhere:where args:args orderBy:orderBy limit:0 error:nil];
}


-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler
{
    [self beginFindWhere:where args:args orderBy:nil limit:1 completionQueue:completionQueue completionHandler:^(NSArray *items, NSError *error)
    {
        if ( completionHandler )
            completionHandler([items lastObject], error);
    }];
}


-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler
{
    [self beginFindWhere:where args:args orderBy:nil limit:1 completionQueue:nil completionHandler:^(NSArray *items, NSError *error) {
         if ( completionHandler )
             completionHandler([items lastObject], error);
     }];
}


-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error
{
    return [[self findWhere:where args:args orderBy:nil limit:1 error:error] lastObject];
}


-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args
{
    return [[self findWhere:where args:args orderBy:nil limit:1 error:nil] lastObject];
}


#pragma mark - removeWhere


-(int)_removeWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];
    
    if ( ![self _ensureSchema] )
        return -1;
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM [%@] ", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( ![self.connection execSql:sql args:args] )
        return -1;
    
    int count = sqlite3_changes(self.connection.db);
    
    // note: we may leave objects in the cache that were deleted, but the rowid will not be re-used (thanks to AUTOINCREMENT PK)
    // so it should be eventually cleaned out of the cache from lack of use.
    
    return count;
}


-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        int count = [self _removeWhere:where args:args];
        NSError *error = (count != -1) ? nil : _lastError;
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(count, error);
        }];
    }];
}


-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginRemoveWhere:where args:args completionQueue:nil completionHandler:completionHandler];
}


-(int)removeWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error
{
    __block int count;
    
    [self.connection dispatchSync:^{
        count = [self _removeWhere:where args:args];
        if ( error )
            *error = (count != -1) ? nil : _lastError;
    }];
    
    return count;
}


-(int)removeWhere:(NSString *)where args:(NSArray *)args
{
    return [self removeWhere:where args:args error:nil];
}


-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginRemoveWhere:nil args:nil completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler
{
    [self beginRemoveWhere:nil args:nil completionQueue:nil completionHandler:completionHandler];
}


-(int)removeAllWithError:(NSError **)error
{
    return [self removeWhere:nil args:nil error:error];
}


-(int)removeAll
{
    return [self removeAllWithError:nil];
}


#pragma mark - sync


-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    dispatch_async(self.connection.queue, ^{
        [self dispatchCompletionQueue:completionQueue completionHandler:completionHandler];
    });
}


-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler
{
    [self beginSyncWithCompletionQueue:nil completionHandler:completionHandler];
}


-(BOOL)syncWait:(dispatch_time_t)timeout
{
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, self.connection.queue, ^
    {
        // we don't actually need to do anything here specific...
    });
    
    return (dispatch_group_wait(group, timeout) == 0) ? YES : NO;
}


-(void)sync
{
    [self syncWait:DISPATCH_TIME_FOREVER];
}


@end


