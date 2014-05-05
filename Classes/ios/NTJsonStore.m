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


-(NSString *)storeFilename
{
    return [NSString stringWithFormat:@"%@%@", self.storePath, self.storeName];
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


-(BOOL)validateEnvironment
{
    if ( _isClosed || _isClosing )
        return NO;
    
    return YES;
}


#pragma mark - ensureSchema


-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *errors))completionHandler
{
    __block NSMutableArray *errors = nil;
    
    for(NTJsonCollection *collection in self.collections)
    {
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonCollectionSerialQueue completionHandler:^(NSError *error)
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
        [collection beginEnsureSchemaWithCompletionQueue:NTJsonCollectionSerialQueue completionHandler:^(NSError *error)
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