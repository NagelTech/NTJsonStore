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


dispatch_queue_t NTJsonStoreSerialQueue = (id)@"NTJsonStoreSerialQueue";


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
        _connection = [[NTJsonSqlConnection alloc] initWithFilename:self.storeFilename connectionName:@"[system]"];
    }
    
    return _connection;
}


-(BOOL)exists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.storeFilename];
}


-(NSMutableDictionary *)internalCollections
{
    @synchronized(self)
    {
        if ( !_internalCollections )
        {
            _internalCollections = [NSMutableDictionary dictionary];
            
            [self.connection dispatchSync:^
            {
                sqlite3_stmt *statement = [self.connection statementWithSql:@"SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY 1;" args:nil];
                
                int status;
                
                while ( (status=sqlite3_step(statement)) == SQLITE_ROW )
                {
                    NSString *collectionName = [[NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, 0)] lowercaseString];
                    
                    NTJsonCollection *collection = [[NTJsonCollection alloc] initWithStore:self name:collectionName];
                    
                    _internalCollections[collectionName] = collection;
                }
                
                sqlite3_finalize(statement);
            }];
        }
        
        return _internalCollections;
    }
}


-(NSArray *)collections
{
    return [self.internalCollections allValues];
}


-(NTJsonCollection *)collectionWithName:(NSString *)collectionName
{
    @synchronized(self)
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
}


+(BOOL)isJsonCurrent:(NSDictionary *)json
{
    if ( ![json isKindOfClass:[NTJsonObjectProxy class]] )
        return NO;
    
    NTJsonObjectProxy *proxy = (id)json;
    
    return proxy.NTJsonObjectProxy_isCurrent;
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


#pragma mark - ensureSchema


-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler
{
    __block BOOL allSuccess = YES;
    
    for(NTJsonCollection *collection in self.collections)
    {
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonCollectionSerialQueue completionHandler:^(BOOL success)
         {
             if ( !success )
                 allSuccess = NO;
         }];
    }
    
    [self beginSyncWithCompletionQueue:completionQueue completionHandler:^
     {
         completionHandler(allSuccess);
     }];
}


-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    [self beginEnsureSchemaWithCompletionQueue:nil completionHandler:completionHandler];
}


-(BOOL)ensureSchema
{
    __block BOOL allSuccess = YES;
    
    for(NTJsonCollection *collection in self.collections)
    {
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonCollectionSerialQueue completionHandler:^(BOOL success)
         {
             if ( !success )
                 allSuccess = NO;
         }];
    }
    
    [self sync];
    
    return allSuccess;
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
