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
    NSString *_name;
    NSArray *_columns;
}

@end


@implementation NTJsonCollection


-(id)initWithStore:(NTJsonStore *)store name:(NSString *)name
{
    self = [super init];
    
    if ( self )
    {
        _store = store;
        _name = name;
        _columns = nil; // these are lazy loaded
    }
    
    return self;
}


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


-(BOOL)createCollection
{
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([__rowid__] integer primary key, __json__ blob);", self.name];

    _columns = [NSArray array];
    
    return [self.store execSql:sql args:nil];
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


-(BOOL)addColumns:(NSArray *)columns
{
    // First, we need to add the columns to the table...
    // (SQLITE only allows you to add one at a time.
    
    for(NTJsonColumn *column in columns)
    {
        NSString *alterSql = [NSString stringWithFormat:@"ALTER TABLE [%@] ADD COLUMN [%@];", self.name, column.name];
    
        if ( ![self.store execSql:alterSql args:nil] )
            return NO;  // oops
    }
    
    // Now we need to populate the data...
    
    sqlite3_stmt *selectStatement = [self.store statementWithSql:[NSString stringWithFormat:@"SELECT __rowid__, __json__ FROM [%@]", self.name] args:nil];
    
    if ( !selectStatement )
        return NO;  // todo: cleanup here somehow? transaction?
    
    NSString *updateSql = [NSString stringWithFormat:@"UPDATE [%@] SET %@ WHERE __rowid__ = ?;", self.name, [[columns NTJsonStore_transform:^id(NTJsonColumn *column)
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
            NSLog(@"Error: Unable to parse JSON for %@:%d", self.name, rowid);
            continue;
        }
        
        // Extract our data...
        
        NSMutableArray *values = [NSMutableArray array];
        
        [self extractValuesInColumns:columns fromJson:json intoArray:values];
        [values addObject:@(rowid)];
        
        // Perform our update...
        
        BOOL success = [self.store execSql:updateSql args:values];
        
        if ( !success )
        {
            NSLog(@"Error: Upate SQL failed!");
        }
    }
    
    sqlite3_finalize(selectStatement);
    
    // now we can append them to our column list...

    _columns = [self.columns arrayByAddingObjectsFromArray:columns];
    
    return YES;
}


-(void)addNewColumnsInSql:(NSString *)sql toArray:(NSMutableArray *)newColumns
{
    if ( !sql )
        return ;
    
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
        
        NTJsonColumn *column = [self.columns NTJsonStore_find:^BOOL(NTJsonColumn *column) { return [column.name isEqualToString:columnName]; }];
        
        if ( column )
            return ;    // found this column
        
        column = [NTJsonColumn columnWithName:columnName];
        
        [newColumns addObject:column];
    }];
}


-(NSDictionary *)insert:(NSDictionary *)json
{
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
        return nil;
    
    long long rowid = sqlite3_last_insert_rowid(self.store.connection);
    
    NSMutableDictionary *newJson = [json mutableCopy];
    
    newJson[@"__rowid__"] = @(rowid);
    
    return [newJson copy];
}


-(BOOL)update:(NSDictionary *)json
{
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


-(BOOL)remove:(int)rowid
{
    return [self.store execSql:[NSString stringWithFormat:@"DELETE [%@] WHERE __rowid__ = ?", self.name] args:@[@(rowid)]];
}


-(int)countWhere:(NSString *)where args:(NSArray *)args
{
    NSMutableArray *newColumns = [NSMutableArray array];
    
    [self addNewColumnsInSql:where toArray:newColumns];
    
    if ( newColumns.count > 0 )
    {
        [self addColumns:newColumns];
    }
    
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
    NSMutableArray *newColumns = [NSMutableArray array];
    
    [self addNewColumnsInSql:where toArray:newColumns];
    [self addNewColumnsInSql:orderBy toArray:newColumns];
    
    if ( newColumns.count > 0 )
    {
        [self addColumns:newColumns];
    }
    
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
        long long rowid = sqlite3_column_int64(selectStatement, 0);
        NSData *jsonData = [NSData dataWithBytes:sqlite3_column_blob(selectStatement, 1) length:sqlite3_column_bytes(selectStatement, 1)];
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingAllowFragments error:nil];
        
        if ( !json )
        {
            NSLog(@"Error: Unable to parse JSON for %@:%lld", self.name, rowid);
            continue;
        }
        
        // Make sure __rowid__ is valid and correct.
        
        NSNumber *jsonRowId = json[@"__rowid__"];
        
        if ( !jsonRowId || ![jsonRowId isKindOfClass:[NSNumber class]] || ![jsonRowId isEqualToNumber:@(rowid)] )
        {
            NSMutableDictionary *newJson = [json mutableCopy];
            
            newJson[@"__rowid__"] = @(rowid);
            
            json = [newJson copy];
        }
        
        [items addObject:json];
    }
    
    sqlite3_finalize(selectStatement);

    return items;
}


-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args
{
    NSArray *items = [self findWhere:where args:args orderBy:nil];
    
    return (items.count == 1) ? items[0] : nil;
}


-(int)removeWhere:(NSString *)where args:(NSArray *)args
{
    NSMutableArray *newColumns = [NSMutableArray array];
    
    [self addNewColumnsInSql:where toArray:newColumns];
    
    if ( newColumns.count > 0 )
    {
        [self addColumns:newColumns];
    }
    
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE [%@] ", self.name];
    
    if ( where )
        [sql appendFormat:@" WHERE %@", where];
    
    if ( ![self.store execSql:sql args:args] )
        return 0;
    
    return sqlite3_changes(self.store.connection);
}



@end
