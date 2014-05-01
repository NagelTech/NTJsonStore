//
//  NTJsonCollection.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonStore+Private.h"


dispatch_queue_t NTJsonCollectionSerialQueue = (id)@"NTJsonCollectionSerialQueue";


@interface NTJsonCollection ()
{
    NTJsonStore *_store;
    NTJsonSqlConnection *_connection;

    BOOL _isNewCollection;
    NSString *_name;
    NSArray *_columns;
    NSArray *_indexes;
    NTJsonObjectCache *_objectCache;
    NSDictionary *_defaultJson;
    
    NSMutableDictionary *_metadata;
    
    NSMutableArray *_pendingColumns;
    NSMutableArray *_pendingIndexes;
}

@property (nonatomic,readonly) NTJsonSqlConnection *connection;
@property (nonatomic,readonly) NSMutableDictionary *metadata;

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


#pragma mark - misc


-(NSString *)description
{
    return self.name;
}


-(dispatch_queue_t)getCompletionQueue:(dispatch_queue_t)completionQueue
{
    if ( (id)completionQueue == (id)NTJsonCollectionSerialQueue )
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


#pragma mark - metadata support


-(BOOL)createMetadataTable
{
    __block BOOL success;
    
    [self.store.connection dispatchSync:^{
        NSNumber *count = [self.store.connection execValueSql:@"SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = ?;" args:@[NTJsonStore_MetadataTableName]];
        
        if ( [count isKindOfClass:[NSNumber class]] && [count intValue] == 1 )
        {
            success = YES;
            return  ;   // table already exists
        }
        
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([collection] TEXT, [metadata] BLOB);", NTJsonStore_MetadataTableName];
        
        success = [self.store.connection execSql:sql args:nil];
        
        if ( !success )
            LOG_ERROR(@"Failed to create metadata table!");
        
        // we don't bother with an index on columnName
    }];
    
    return success;
}


-(NSMutableDictionary *)metadata
{
    [self.connection dispatchSync:^{
        if ( !_metadata )
        {
            NSString *value = [self.connection execValueSql:[NSString stringWithFormat:@"SELECT [metadata] FROM [%@] WHERE [collection] = ?", NTJsonStore_MetadataTableName] args:@[self.name]];
            
            NSDictionary *json = (value) ? [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
            
            _metadata = (json) ? [json mutableCopy] : [NSMutableDictionary dictionary];
        }
    }];

    return _metadata;
}


-(BOOL)_saveMetadata
{
    BOOL success;
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE [%@] SET [metadata] = ? WHERE [collection] = ?;", NTJsonStore_MetadataTableName];
    
    NSString *json = (_metadata) ? [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:_metadata options:0 error:nil] encoding:NSUTF8StringEncoding] : @"{}";
    
    if ( ![self.connection execSql:sql args:@[json, self.name]] )
    {
        // Hmm, this is most likely to happen because the table doesn't exist, so let's make sure that's all set.
        
        [self createMetadataTable];
        
        success = NO; // now try an insert
    }
    else
    {
        success = (sqlite3_changes(self.connection.connection) == 1) ? YES : NO; // try insert if
    }

    if ( !success )
    {
        sql = [NSString stringWithFormat:@"INSERT INTO [%@] ([collection], [metadata]) VALUES (?, ?);", NTJsonStore_MetadataTableName];
        
        success = [self.connection execSql:sql args:@[self.name, json]];
    }
    
    if ( !success )
        LOG_ERROR(@"Failed to update metadata for collection %@!", self.name);
    
    return success;
}


#pragma mark - defaultJson


-(NSDictionary *)defaultJson
{
    [self.connection dispatchSync:^{
        if ( !_defaultJson )
        {
            _defaultJson = self.metadata[@"defaultJson"] ?: [NSDictionary dictionary];
        }
    }];
    
    return _defaultJson;
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
    [self.connection dispatchSync:^{
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
        self.metadata[@"defaultJson"] = _defaultJson;
        
        // We need to save the new metadata, but that can happen asynchronously...
        
        [self.connection dispatchAsync:^
        {
            [self _saveMetadata];
        }];
    }];

}


#pragma mark - Schema Management


-(BOOL)schema_createCollection
{
    if ( !_isNewCollection )
        return YES;
    
    LOG_DBG(@"Adding table: %@", self.name);
    
    _isNewCollection = NO;
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([__rowid__] INTEGER PRIMARY KEY AUTOINCREMENT, [__json__] BLOB);", self.name];
    
    _columns = [NSArray array];
    _indexes = [NSArray array];
    
    return [self.connection execSql:sql args:nil];
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
        
        if ( ![self.connection execSql:alterSql args:nil] )
            return NO;  // oops
    }
    
    // Now we need to populate the data...
    
    sqlite3_stmt *selectStatement = [self.connection statementWithSql:[NSString stringWithFormat:@"SELECT [__rowid__], [__json__] FROM [%@]", self.name] args:nil];
    
    if ( !selectStatement )
        return NO;  // todo: cleanup here somehow? transaction?
    
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE [__rowid__] = ?;", self.name, [[_pendingColumns NTJsonStore_transform:^id(NTJsonColumn *column) {
        return [NSString stringWithFormat:@"[%@] = ?", column.name];
    }] componentsJoinedByString:@", "]];
    int status;
    
    
    while ( (status=sqlite3_step(selectStatement)) == SQLITE_ROW )
    {
        int rowid = sqlite3_column_int(selectStatement, 0);
        
        // todo: take advantage of any cached JSON... cache it to???
        
        NSData *jsonData = [NSData dataWithBytes:sqlite3_column_blob(selectStatement, 1) length:sqlite3_column_bytes(selectStatement, 1)];
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
        
        if ( !json )
        {
            LOG_ERROR(@"Error: Unable to parse JSON for %@:%d", self.name, rowid);
            continue; 
        }
        
        // Extract our data...
        
        NSMutableArray *values = [NSMutableArray array];
        
        [self extractValuesInColumns:_pendingColumns fromJson:json intoArray:values];
        [values addObject:@(rowid)];
        
        // Perform our update...
        
        BOOL success = [self.connection execSql:updateSql args:values];
        
        if ( !success )
        {
            LOG_ERROR(@"Error: Upate SQL failed!");
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
        if ( ![self.connection execSql:[index sqlWithTableName:self.name] args:nil])
            return NO;
    }
    
    _indexes = [self.indexes arrayByAddingObjectsFromArray:_pendingIndexes];

    [_pendingIndexes removeAllObjects];
    
    return YES;
}


-(BOOL)_ensureSchema
{
    if ( ![self schema_createCollection] )
        return NO;
    
    if ( ![self schema_addOrUpdatePendingColumns] )
        return NO;
    
    if ( ![self schema_addPendingIndexes] )
        return NO;
    
    return YES;
}


-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _ensureSchema];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(success);
        }];
    }];
}


-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    [self beginEnsureSchemaWithCompletionQueue:nil completionHandler:completionHandler];
}


-(BOOL)ensureSchema
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _ensureSchema];
    }];
    
    return success;
}


#pragma mark - Column Support


-(NSArray *)columns
{
    // if we don't have our list of columns, let's extract them...

    [self.connection dispatchSync:^{
        if ( !_columns )
        {
            [self.connection dispatchSync:^{
                NSMutableArray *columns = [NSMutableArray array];
                sqlite3_stmt *statement = [self.connection statementWithSql:[NSString stringWithFormat:@"PRAGMA table_info(%@);", self.name] args:nil];
                
                int status;
                
                while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
                {
                    NSString *columnName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
                    
                    if ( [columnName isEqualToString:@"__rowid__"] || [columnName isEqualToString:@"__json__"] )
                        continue;
                    
                    [columns addObject:[NTJsonColumn columnWithName:columnName]];
                }
                
                _columns = [columns copy];
            }];
        }
    }];
    
    return _columns;
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


-(BOOL)scanSqlForNewColumns:(NSString *)sql
{
    if ( !sql )
        return NO;
    
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
        
        if ( [columnName isEqualToString:@"__rowid__"] )
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
    [self.connection dispatchSync:^{
        if ( !_indexes )
        {
            [self.connection dispatchSync:^{
                NSMutableArray *indexes = [NSMutableArray array];
                
                sqlite3_stmt *statement = [self.connection statementWithSql:@"SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=?" args:@[self.name]];
                
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
                
                _indexes = [indexes copy];
            }];
        }
    }];
    
    return _indexes;
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
    [self _ensureSchema];
    
    NSMutableArray *columnNames = [NSMutableArray arrayWithObject:@"__json__"];
    [columnNames addObjectsFromArray:[self.columns NTJsonStore_transform:^id(NTJsonColumn *column) { return column.name; }]];
    
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO [%@] (%@) VALUES (%@);",
                     self.name,
                     [columnNames componentsJoinedByString:@", "],
                     [@"" stringByPaddingToLength:columnNames.count*3-2 withString:@"?, " startingAtIndex:0]];
    
    NSMutableArray *values = [NSMutableArray array];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    
    [values addObject:jsonData];
    
    [self extractValuesInColumns:self.columns fromJson:json intoArray:values];
    
    if ( ![self.connection execSql:sql args:values] )
        return 0;
    
    NTJsonRowId rowid = sqlite3_last_insert_rowid(self.connection.connection);
    
    return rowid;
}


-(void)beginInsert:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NTJsonRowId rowid))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        NTJsonRowId rowid = [self _insert:json];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(rowid);
        }];
    }];
}


-(void)beginInsert:(NSDictionary *)json completionHandler:(void (^)(NTJsonRowId rowid))completionHandler
{
    [self beginInsert:json completionQueue:nil completionHandler:completionHandler];
}


-(NTJsonRowId)insert:(NSDictionary *)json
{
    __block NTJsonRowId rowid;
    
    [self.connection dispatchSync:^{
        rowid = [self _insert:json];
    }];
    
    return rowid;
}


#pragma mark - insertBatch


-(BOOL)_insertBatch:(NSArray *)items
{
    // todo: put this all in a transaction.
    
    if ( !items )
        return YES;
    
    for(NSDictionary *item in items)
    {
        NTJsonRowId rowid = [self _insert:item];
        
        if ( !rowid )
        {
            // rollback
            return NO;
        }
    }
    
    return YES;
}


-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _insertBatch:items];
       
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(success);
        }];
    }];
}


-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(BOOL success))completionHandler
{
    [self beginInsertBatch:items completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)insertBatch:(NSArray *)items
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _insertBatch:items];
    }];
    
    return success;
}


#pragma mark - update


-(BOOL)_update:(NSDictionary *)json
{
    [self _ensureSchema];
    
    NTJsonRowId rowid = [json[@"__rowid__"] longLongValue];
    
    NSMutableArray *columnNames = [NSMutableArray arrayWithObject:@"__json__"];
    [columnNames addObjectsFromArray:[self.columns NTJsonStore_transform:^id(NTJsonColumn *column) { return column.name; }]];
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE [__rowid__] = ?;",
                     self.name,
                     [[columnNames NTJsonStore_transform:^id(NSString *columnName) { return [NSString stringWithFormat:@"[%@] = ?", columnName]; }] componentsJoinedByString:@", "]];
    
    NSMutableArray *values = [NSMutableArray array];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    
    [values addObject:jsonData];
    
    [self extractValuesInColumns:self.columns fromJson:json intoArray:values];
    
    [values addObject:@(rowid)];
    
    BOOL success = [self.connection execSql:sql args:values];
    
    if ( success )
        [_objectCache addJson:json withRowId:rowid];
    
    return success;
}


-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        BOOL success = [self _update:json];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(success);
        }];
    }];
}


-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(BOOL success))completionHandler
{
    [self beginUpdate:json completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)update:(NSDictionary *)json
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _update:json];
    }];
    
    return success;
}


#pragma mark - remove


-(BOOL)_remove:(NSDictionary *)json
{
    [self _ensureSchema];
    
    long long rowid = [json[@"__rowid__"] longLongValue];

    BOOL success = [self.connection execSql:[NSString stringWithFormat:@"DELETE FROM [%@] WHERE [__rowid__] = ?", self.name] args:@[@(rowid)]];
    
    if ( success )
        [_objectCache removeObjectWithRowId:rowid];
    
    return success;
}


-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^
    {
        BOOL success = [self _remove:json];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(success);
        }];
    }];
}


-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(BOOL success))completionHandler
{
    [self beginRemove:json completionQueue:nil completionHandler:completionHandler];
}


-(BOOL)remove:(NSDictionary *)json
{
    __block BOOL success;
    
    [self.connection dispatchSync:^{
        success = [self _remove:json];
    }];
    
    return success;
}


#pragma mark - count


-(int)_countWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];

    [self _ensureSchema];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT COUNT(*) FROM [%@]", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    id count = [self.connection execValueSql:sql args:args];
    
    return (count) ? [count intValue] : 0;
}


-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        int count = [self _countWhere:where args:args];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(count);
        }];
    }];
}


-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count))completionHandler
{
    [self beginCountWhere:where args:args completionQueue:nil completionHandler:completionHandler];
}


-(int)countWhere:(NSString *)where args:(NSArray *)args
{
    __block int count;
    
    [self.connection dispatchSync:^{
        count = [self _countWhere:where args:args];
    }];
    
    return count;
}


-(int)count
{
    return [self countWhere:nil args:nil];
}


-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler
{
    [self beginCountWhere:nil args:nil completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginCountWithCompletionHandler:(void (^)(int count))completionHandler
{
    [self beginCountWhere:nil args:nil completionQueue:nil completionHandler:completionHandler];
}


#pragma mark - find


-(NSArray *)_findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit
{
    [self scanSqlForNewColumns:where];
    [self scanSqlForNewColumns:orderBy];

    [self _ensureSchema];
    
    // Ok, now we can actually do the query...
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT [__rowid__], [__json__] FROM %@", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( orderBy )
        [sql appendFormat:@" ORDER BY %@", orderBy];
    
    if ( limit > 0 )
        [sql appendFormat:@" LIMIT %d", limit];
    
    sqlite3_stmt *selectStatement = [self.connection statementWithSql:sql args:args];
    
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
            
            NSDictionary *rawJson = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            
            if ( !rawJson )
            {
                LOG_ERROR(@"Error: Unable to parse JSON for %@:%lld", self.name, rowid);
                continue;
            }
            
            // Make sure __rowid__ is valid and correct.
            
            if (  ![rawJson[@"__rowId__"] isEqualToNumber:@(rowid)] )
            {
                NSMutableDictionary *mutableJson = [rawJson mutableCopy];
                mutableJson[@"__rowid__"] = @(rowid);
                rawJson = [mutableJson copy];
            }
            
            json = [_objectCache addJson:rawJson withRowId:rowid];
        }
        
        [items addObject:json];
    }
    
    sqlite3_finalize(selectStatement);

    return [items copy];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        NSArray *items = [self _findWhere:where args:args orderBy:orderBy limit:limit];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(items);
        }];
    }];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:limit completionQueue:nil completionHandler:completionHandler];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit
{
    __block NSArray *items;
    
    [self.connection dispatchSync:^{
        items = [self _findWhere:where args:args orderBy:orderBy limit:limit];
    }];
    
    return items;
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:0 completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items))completionHandler
{
    [self beginFindWhere:where args:args orderBy:orderBy limit:0 completionQueue:nil completionHandler:completionHandler];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy
{
    return [self findWhere:where args:args orderBy:orderBy limit:0];
}


-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item))completionHandler
{
    [self beginFindWhere:where args:args orderBy:nil limit:1 completionQueue:completionQueue completionHandler:^(NSArray *items)
    {
        if ( completionHandler )
            completionHandler([items lastObject]);
    }];
}


-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item))completionHandler
{
    [self beginFindWhere:where args:args orderBy:nil limit:1 completionQueue:nil completionHandler:^(NSArray *items) {
         if ( completionHandler )
             completionHandler([items lastObject]);
     }];
}


-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args
{
    return [[self findWhere:where args:args orderBy:nil limit:1] lastObject];
}


#pragma mark - removeWhere


-(int)_removeWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];
    
    [self _ensureSchema];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM [%@] ", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( ![self.connection execSql:sql args:args] )
        return 0;
    
    int count = sqlite3_changes(self.connection.connection);
    
    // note: we may leave objects in the cache that were deleted, but the rowid will not be re-used (thanks to AUTOINCREMENT PK)
    // so it should be eventually cleaned out of the cache from lack of use.
    
    return count;
}

-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    [self.connection dispatchAsync:^{
        int count = [self _removeWhere:where args:args];
        
        [self dispatchCompletionQueue:completionQueue completionHandler:^{
            completionHandler(count);
        }];
    }];
}


-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count))completionHandler
{
    [self beginRemoveWhere:where args:args completionQueue:nil completionHandler:completionHandler];
    
}


-(int)removeWhere:(NSString *)where args:(NSArray *)args
{
    __block int count;
    
    [self.connection dispatchSync:^{
        count = [self _removeWhere:where args:args];
    }];
    
    return count;
}


-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler
{
    [self beginRemoveWhere:nil args:nil completionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count))completionHandler
{
    [self beginRemoveWhere:nil args:nil completionQueue:nil completionHandler:completionHandler];
}

-(int)removeAll
{
    return [self removeWhere:nil args:nil];
}


#pragma mark - sync


-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler
{
    dispatch_async(self.connection.queue, completionHandler);
}


-(void)syncWait:(dispatch_time_t)timeout
{
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, self.connection.queue, ^
    {
        // we don't actually need to do anything here specific...
    });
    
    dispatch_group_wait(group, timeout);
}


-(void)sync
{
    [self syncWait:DISPATCH_TIME_FOREVER];
}


@end


