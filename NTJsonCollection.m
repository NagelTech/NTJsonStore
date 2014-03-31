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
    NTJsonStore *_store;

    BOOL _isNewCollection;
    NSString *_name;
    NSArray *_columns;
    NSArray *_indexes;
    NTJsonObjectCache *_objectCache;
    
    NSMutableArray *_pendingColumns;
    NSMutableArray *_pendingIndexes;
}

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
        
        _pendingColumns = [NSMutableArray array];
        _pendingIndexes = [NSMutableArray array];
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
    }
    
    return self;
}


#pragma mark - misc


-(NSString *)description
{
    return self.name;
}


#pragma mark - Schema Management


-(BOOL)schema_createCollection
{
    if ( !_isNewCollection )
        return YES;
    
    LOG_DBG(@"Adding table: %@", self.name);
    
    _isNewCollection = NO;
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([__rowid__] integer primary key, __json__ blob);", self.name];
    
    _columns = [NSArray array];
    _indexes = [NSArray array];
    
    return [self.store execSql:sql args:nil];
}


-(BOOL)schema_addPendingColumns
{
    if ( !_pendingColumns.count )
        return YES;
    
    // First, we need to add the columns to the table...
    // (SQLITE only allows you to add one at a time)
    
    for(NTJsonColumn *column in _pendingColumns)
    {
        LOG_DBG(@"Adding column: %@.%@", self.name, column.name);

        NSString *alterSql = [NSString stringWithFormat:@"ALTER TABLE [%@] ADD COLUMN [%@];", self.name, column.name];
        
        if ( ![self.store execSql:alterSql args:nil] )
            return NO;  // oops
    }
    
    // Now we need to populate the data...
    
    sqlite3_stmt *selectStatement = [self.store statementWithSql:[NSString stringWithFormat:@"SELECT __rowid__, __json__ FROM [%@]", self.name] args:nil];
    
    if ( !selectStatement )
        return NO;  // todo: cleanup here somehow? transaction?
    
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE __rowid__ = ?;", self.name, [[_pendingColumns NTJsonStore_transform:^id(NTJsonColumn *column)
                                                                                                              {
                                                                                                                  return [NSString stringWithFormat:@"[%@] = ?", column.name];
                                                                                                              }] componentsJoinedByString:@", "]];
    int status;
    
    while ( (status=sqlite3_step(selectStatement)) == SQLITE_ROW )
    {
        int rowid = sqlite3_column_int(selectStatement, 0);
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
        
        BOOL success = [self.store execSql:updateSql args:values];
        
        if ( !success )
        {
            LOG_ERROR(@"Error: Upate SQL failed!");
        }
    }
    
    sqlite3_finalize(selectStatement);
    
    // now we can append them to our column list...
    
    _columns = [self.columns arrayByAddingObjectsFromArray:_pendingColumns];
    
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
        if ( ![self.store execSql:[index sqlWithTableName:self.name] args:nil])
            return NO;
    }
    
    _indexes = [self.indexes arrayByAddingObjectsFromArray:_pendingIndexes];

    [_pendingIndexes removeAllObjects];
    
    return YES;
}


-(BOOL)ensureSchema
{
    if ( ![self schema_createCollection] )
        return NO;
    
    if ( ![self schema_addPendingColumns] )
        return NO;
    
    if ( ![self schema_addPendingIndexes] )
        return NO;
    
    return YES;
}


#pragma mark - Column Support


-(NSArray *)columns
{
    // if we don't have our list of columns, let's extract them...

    if ( !_columns )
    {
        NSMutableArray *columns = [NSMutableArray array];
        sqlite3_stmt *statement = [self.store statementWithSql:[NSString stringWithFormat:@"PRAGMA table_info(%@);", self.name] args:nil];
        
        int status;
        
        while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
        {
            NSString *columnName = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 1)];
            
            if ( [columnName isEqualToString:@"__rowid__"] || [columnName isEqualToString:@"__json__"] )
                continue;
            
            [columns addObject:[NTJsonColumn columnWithName:columnName]];
        }
        
        _columns = [columns copy];
    }
    
    return _columns;
}


-(void)extractValuesInColumns:(NSArray *)columns fromJson:(NSDictionary *)json intoArray:(NSMutableArray *)values
{
    for(NTJsonColumn *column in columns)
    {
        id value = [json NTJsonStore_objectForKeyPath:column.name];
        
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
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
    {
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
    [self scanSqlForNewColumns:fields];
}


#pragma mark - Index Support


-(NSArray *)indexes
{
    if ( !_indexes )
    {
        NSMutableArray *indexes = [NSMutableArray array];
        
        sqlite3_stmt *statement = [self.store statementWithSql:@"SELECT sql FROM sqlite_master WHERE type='index' AND tbl_name=?" args:@[self.name]];
        
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
    }
    
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
    
    // First off, let's see if it already exists...
    
    if ( [self.indexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return (index.isUnique == isUnique) && [index.keys isEqualToString:keys]; }] )
        return ;
    
    if ( [_pendingIndexes NTJsonStore_find:^BOOL(NTJsonIndex *index) { return (index.isUnique == isUnique) && [index.keys isEqualToString:keys]; }] )
        return ;
    
    [self scanSqlForNewColumns:keys];
    
    NSString *name = [self createIndexNameWithIsUnique:isUnique];
    
    NTJsonIndex *index = [NTJsonIndex indexWithName:name keys:keys isUnique:isUnique];
    
    [_pendingIndexes addObject:index];
}


-(void)addIndexWithKeys:(NSString *)keys
{
    [self addIndexWithKeys:keys isUnique:NO];
}


-(void)addUniqueIndexWithKeys:(NSString *)keys
{
    [self addIndexWithKeys:keys isUnique:YES];
}


#pragma mark - Data Access Methods


-(NTJsonRowId)insert:(NSDictionary *)json
{
    [self ensureSchema];
    
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
    
    if ( ![self.store execSql:sql args:values] )
        return 0;
    
    NTJsonRowId rowid = sqlite3_last_insert_rowid(self.store.connection);
    
    return rowid;
}


-(BOOL)insertBatch:(NSArray *)items
{
    // todo: put this all in a transaction.
    
    if ( !items )
        return YES;
    
    for(NSDictionary *item in items)
    {
        NTJsonRowId rowid = [self insert:item];
        
        if ( !rowid )
        {
            // rollback
            return NO;
        }
    }
    
    return YES;
}


-(BOOL)update:(NSDictionary *)json
{
    [self ensureSchema];
    
    long long rowid = [json[@"__rowid__"] longLongValue];
    
    NSMutableArray *columnNames = [NSMutableArray arrayWithObject:@"__json__"];
    [columnNames addObjectsFromArray:[self.columns NTJsonStore_transform:^id(NTJsonColumn *column) { return column.name; }]];
    
    NSString *sql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE __rowid__ = ?;",
                     self.name,
                     [[columnNames NTJsonStore_transform:^id(NSString *columnName) { return [NSString stringWithFormat:@"[%@] = ?", columnName]; }] componentsJoinedByString:@", "]];
    
    NSMutableArray *values = [NSMutableArray array];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    
    [values addObject:jsonData];
    
    [self extractValuesInColumns:self.columns fromJson:json intoArray:values];
    
    [values addObject:@(rowid)];
    
    return [self.store execSql:sql args:values];
}


-(BOOL)remove:(NSDictionary *)json
{
    [self ensureSchema];
    
    long long rowid = [json[@"__rowid__"] longLongValue];

    return [self.store execSql:[NSString stringWithFormat:@"DELETE FROM [%@] WHERE __rowid__ = ?", self.name] args:@[@(rowid)]];
}


-(int)countWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];

    [self ensureSchema];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT COUNT(*) FROM [%@] ", self.name];
    
    if ( where )
        [sql appendString:where];
    
    sqlite3_stmt *statement = [self.store statementWithSql:sql args:args];
    
    int count = 0;
    
    if ( sqlite3_step(statement) == SQLITE_ROW )
        count = sqlite3_column_int(statement, 0);
    
    sqlite3_finalize(statement);
    
    return count;
}


-(int)count
{
    return [self countWhere:nil args:nil];
}


-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy
{
    [self scanSqlForNewColumns:where];
    [self scanSqlForNewColumns:orderBy];

    [self ensureSchema];
    
    // Ok, now we can actually do the query...
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT __rowid__, __json__ FROM %@", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( orderBy )
        [sql appendFormat:@" ORDER BY %@", orderBy];
    
    sqlite3_stmt *selectStatement = [self.store statementWithSql:sql args:args];
    
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


-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args
{
    NSArray *items = [self findWhere:where args:args orderBy:nil];
    
    return (items.count == 1) ? items[0] : nil;
}


-(int)removeWhere:(NSString *)where args:(NSArray *)args
{
    [self scanSqlForNewColumns:where];
    
    [self ensureSchema];
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM [%@] ", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( ![self.store execSql:sql args:args] )
        return 0;
    
    return sqlite3_changes(self.store.connection);
}


-(int)removeAll
{
    return [self removeWhere:nil args:nil];
}


@end


