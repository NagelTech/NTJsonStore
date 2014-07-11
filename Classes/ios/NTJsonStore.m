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
    BOOL _isClosing;
    BOOL _isClosed;
}

@property (nonatomic,readonly) NSMutableDictionary *internalCollections;

@end


NSString *NTJsonStore_MetadataTableName = @"NTJsonStore_metadata";


@implementation NTJsonStore


-(id)initWithPath:(NSString *)storePath name:(NSString *)storeName
{
    self = [super init];
    
    if ( self )
    {
        _storeName = storeName;
        _storePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]; // default to Caches
    }
    
    return self;
}


-(id)initWithName:(NSString *)storeName
{
    return [self initWithPath:[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] name:storeName];
}


-(id)init
{
    return [self initWithName:@"NTJsonStore.db"];
}


-(void)close
{
    if ( _isClosed || _isClosing )
        return ;
    
    if ( !_connection && !_internalCollections )
    {
        _isClosed = YES;
        return ;    // never initialized
    }
    
    _isClosing = YES;
    
    [self.connection dispatchSync:^
    {
        if ( _internalCollections )
        {
            for(NTJsonCollection *collection in _internalCollections.allValues)
                [collection close];
        }
        
        [self.connection close];
        
        _connection = nil;
        _internalCollections = nil;
        
        _isClosed = YES;
        _isClosing = NO;
    }];
}


-(void)setStoreName:(NSString *)storeName
{
    if ( _connection )
        @throw [NSException exceptionWithName:@"StoreOpen" reason:@"Cannot set storeName when store is already open." userInfo:nil];
    
    _storeName = storeName;
}


-(void)setStorePath:(NSString *)storePath
{
    if ( _connection )
        @throw [NSException exceptionWithName:@"StoreOpen" reason:@"Cannot set storePath when store is already open." userInfo:nil];
    
    _storePath = storePath;
}


-(NSString *)storeFilename
{
    return [self.storePath stringByAppendingPathComponent:self.storeName];
}


-(NTJsonSqlConnection *)connection
{
    if ( !_connection )
    {
        _connection = [[NTJsonSqlConnection alloc] initWithFilename:self.storeFilename connectionName:@"__store__"];
    }
    
    return _connection;
}


-(BOOL)exists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.storeFilename];
}


-(NSMutableDictionary *)internalCollections
{
    __block NSMutableDictionary *internalCollections;

    [self.connection dispatchSync:^{
        if ( !_internalCollections )
        {
            if ( [self validateEnvironment] )
            {
                _internalCollections = [NSMutableDictionary dictionary];

                sqlite3_stmt *statement = [self.connection statementWithSql:@"SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'  AND name <> ? ORDER BY 1;" args:@[NTJsonStore_MetadataTableName]];
                    
                int status;
                
                while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
                {
                    NSString *collectionName = [[NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)] lowercaseString];
                    
                    NTJsonCollection *collection = [[NTJsonCollection alloc] initWithStore:self name:collectionName];
                    
                    _internalCollections[collectionName] = collection;
                }
                
                sqlite3_finalize(statement);
            }
        }
        
        internalCollections = _internalCollections;
    }];
     
    return internalCollections;
}


-(NSArray *)collections
{
    return [self.internalCollections allValues];
}


-(NTJsonCollection *)collectionWithName:(NSString *)collectionName
{
    __block NTJsonCollection *collection;
    
    [self.connection dispatchSync:^{
        NSString *name = [collectionName lowercaseString];
        
        collection = self.internalCollections[name];
        
        if ( !collection )
        {
            // If collection was not found, create it...
            
            LOG(@"Creating collection: %@", name);
            
            collection = [[NTJsonCollection alloc] initNewCollectionWithStore:self name:name];
            
            self.internalCollections[name] = collection;
        }
    }];
    
    return collection;
}


+(BOOL)isJsonCurrent:(NSDictionary *)json
{
    if ( ![json respondsToSelector:@selector(NTJson_isCurrent)] )
        return NO;
    
    return [(id)json NTJson_isCurrent];
}


#pragma mark - misc


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


-(BOOL)validateEnvironment
{
    if ( _isClosed || _isClosing )
        return NO;
    
    return YES;
}


#pragma mark - metadata


-(BOOL)createMetadataTable
{
    __block BOOL success;
    
    // NOTE: This is using the Store's queue, so it is serialized across all collections...
    
    [self.connection dispatchSync:^{
        NSNumber *count = [self.connection execValueSql:@"SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = ?;" args:@[NTJsonStore_MetadataTableName]];
        
        if ( [count isKindOfClass:[NSNumber class]] && [count intValue] == 1 )
        {
            success = YES;
            return  ;   // table already exists
        }
        
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE [%@] ([key] TEXT, [value] BLOB);", NTJsonStore_MetadataTableName];
        
        success = [self.connection execSql:sql args:nil];
        
        if ( !success )
            LOG_ERROR(@"Failed to create metadata table: %@", self.connection.lastError.localizedDescription);
        
        // we don't bother with an index on columnName
    }];
    
    return success;
}


-(NSDictionary *)metadataWithKey:(NSString *)key
{
    __block NSDictionary *metadata = nil;
    
    [self.connection dispatchSync:^{
        NSString *value = [self.connection execValueSql:[NSString stringWithFormat:@"SELECT [value] FROM [%@] WHERE [key] = ?", NTJsonStore_MetadataTableName] args:@[key]];
        
        metadata = (value) ? [NSJSONSerialization JSONObjectWithData:[value dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    }];
    
    return metadata;
}


-(BOOL)saveMetadataWithKey:(NSString *)key value:(NSDictionary *)value
{
    __block BOOL success = NO;
    
    [self.connection dispatchSync:^{
        
        if ( value ) // insert or update
        {
            NSString *sql = [NSString stringWithFormat:@"UPDATE [%@] SET [value] = ? WHERE [key] = ?;", NTJsonStore_MetadataTableName];
            
            NSString *json = (value) ? [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] encoding:NSUTF8StringEncoding] : @"{}";
            
            if ( ![self.connection execSql:sql args:@[json, key]] )
            {
                // Hmm, this is most likely to happen because the table doesn't exist, so let's make sure that's all set.
                
                [self createMetadataTable];
                
                success = NO; // now try an insert
            }
            else
            {
                success = (sqlite3_changes(self.connection.db) == 1) ? YES : NO; // try insert if
            }
            
            if ( !success )
            {
                sql = [NSString stringWithFormat:@"INSERT INTO [%@] ([key], [value]) VALUES (?, ?);", NTJsonStore_MetadataTableName];
                
                success = [self.connection execSql:sql args:@[key, json]];
            }
        }
        
        else // delete
        {
            [self.connection execSql:[NSString stringWithFormat:@"DELETE FROM [%@] WHERE [key] = ?;", NTJsonStore_MetadataTableName] args:@[key]];
            
            success = YES;  // pretty much always consider this successful
        }
        
        if ( !success )
            LOG_ERROR(@"Failed to update metadata for key %@: %@", key, self.connection.lastError.localizedDescription);
    }];
    
    return success;
}



#pragma mark - config


+(NSDictionary *)loadConfigFile:(NSString *)filename
{
    NSString *path;
    
    if ( [filename pathComponents].count > 1 )
        path = filename;    // it's already a path
    
    else // otherwise find a resource in the bundle
    {
        NSString *type = [filename pathExtension];
        NSString *resource = [filename stringByDeletingPathExtension];
        
        path = [[NSBundle mainBundle] pathForResource:resource ofType:type];
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    if ( !data )
        return nil;
    
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}


-(void)applyConfig:(NSDictionary *)config
{
    if ( ![config isKindOfClass:[NSDictionary class]] )
        return ;
    
    NSString *storePath = config[@"storePath"];
    NSString *storeName = config[@"storeName"];
    NSDictionary *collections = config[@"collections"];
    
    if ( [storePath isKindOfClass:[NSString class]] && storePath.length )
    {
        if ( [storePath isEqualToString:@"CACHES"] )
            storePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        
        else if ( [storePath isEqualToString:@"TEMP"] )
            storePath = NSTemporaryDirectory();
        
        else if ( [storePath isEqualToString:@"DOCS"] )
            storePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        
        self.storePath = storePath;
    }
    
    if ( [storeName isKindOfClass:[NSString class]] && storeName.length )
    {
        self.storeName = storeName;
    }
    
    if ( [collections isKindOfClass:[NSDictionary class]] )
    {
        for(NSString *collectionName in collections.allKeys)
        {
            NSDictionary *collectionConfig = collections[collectionName];
            
            if ( [collectionConfig isKindOfClass:[NSDictionary class]] )
            {
                NTJsonCollection *collection = [self collectionWithName:collectionName];
                
                [collection applyConfig:collectionConfig];
            }
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


#pragma mark - ensureSchema


-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *errors))completionHandler
{
    __block NSMutableArray *errors = nil;
    
    for(NTJsonCollection *collection in self.collections)
    {
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonStoreSerialQueue completionHandler:^(NSError *error)
         {
             if ( error )
             {
                 if (!errors )
                     errors = [NSMutableArray array];
                 
                 [errors addObject:errors];
             }
         }];
    }
    
    [self beginSyncWithCompletionQueue:completionQueue completionHandler:^
     {
         completionHandler([errors copy]);
     }];

}


-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSArray *errors))completionHandler
{
    [self beginEnsureSchemaWithCompletionQueue:nil completionHandler:completionHandler];
}


-(NSArray *)ensureSchema
{
    __block NSMutableArray *errors = nil;
 
    for(NTJsonCollection *collection in self.collections)
    {
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonStoreSerialQueue completionHandler:^(NSError *error)
         {
             if ( error )
             {
                 if ( !errors )
                     errors = [NSMutableArray array];
                 
                 [errors addObject:error];
             }
         }];
    }
    
    [self sync];
 
    return [errors copy];
}


#pragma mark - sync


-(void)beginSyncCollections:(NSArray *)collections withCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler
{
    completionQueue = [self getCompletionQueue:completionQueue];
    
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_async(group, self.connection.queue, ^{
        // this space intentionally left blank
    });
    
    for (NTJsonCollection *collection in collections)
    {
        dispatch_group_async(group, collection.connection.queue, ^{
            // we don't actually need to do anything here specific...
        });
    }
    
    dispatch_group_notify(group, completionQueue, completionHandler);
}


-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler
{
    [self beginSyncCollections:self.collections withCompletionQueue:completionQueue completionHandler:completionHandler];
}


-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler
{
    [self beginSyncCollections:self.collections withCompletionQueue:nil completionHandler:completionHandler];
}


-(void)syncCollections:(NSArray *)collections wait:(dispatch_time_t)timeout
{
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, self.connection.queue, ^{
        // this space intentionally left blank
    });
    
    for (NTJsonCollection *collection in collections)
    {
        dispatch_group_async(group, collection.connection.queue, ^{
            // we don't actually need to do anything here specific...
        });
    }
    
    dispatch_group_wait(group, timeout);
}


-(void)syncWait:(dispatch_time_t)timeout
{
    [self syncCollections:self.collections wait:timeout];
}


-(void)sync
{
    [self syncCollections:self.collections wait:DISPATCH_TIME_FOREVER];
}


@end
