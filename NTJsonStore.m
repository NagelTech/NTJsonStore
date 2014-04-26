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
    NTJsonSqlConnection *_connection;
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


-(NTJsonSqlConnection *)connection
{
    if ( !_connection )
    {
        _connection = [[NTJsonSqlConnection alloc] initWithFilename:self.storeFilename];
    }
    
    return _connection;
}


-(BOOL)exists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.storeFilename];
}


-(NSMutableDictionary *)internalCollections
{
    if ( !_internalCollections )
    {
        _internalCollections = [NSMutableDictionary dictionary];

        sqlite3_stmt *statement = [self.connection statementWithSql:@"SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY 1;" args:nil];
        
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
