//
//  NTJsonCollection.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"


@class NTJsonStore;

///
/// Topics:
///     defaults
///     caching
///     query string format
///     threading model
@interface NTJsonCollection : NSObject

/// The name of the collection. Not case sensitive.
@property (nonatomic,readonly) NSString *name;

/// The store this collection is a member of.
@property (nonatomic,readonly) NTJsonStore *store;

/// The error from the last operation. Useful when using synchroous API methods.
@property (nonatomic,readonly) NSError *lastError;

/// Dictionary of default values for JSON keys. Default values are used in queries when the associated value does not exist in a JSON record.
@property (nonatomic) NSDictionary *defaultJson;

/// the number of items to cache internally. Set to 0 to disable caching of items (the system will still track items that are in use and return the
/// same instance.) Set to -1 to disable ALL caching - in this configuration a new NSDIctionary will be deserialized and returned for each request. Default: 50.
@property (nonatomic) int cacheSize;

/// Add an index with the key string if it doesn't already exist. Calling this has no effect if the index already exists.
/// @param keys a comma-separated list of JSON paths paths to index on. All
-(void)addIndexWithKeys:(NSString *)keys;
-(void)addUniqueIndexWithKeys:(NSString *)keys;
-(void)addQueryableFields:(NSString *)fields;

-(void)applyConfig:(NSDictionary *)config;
-(BOOL)applyConfigFile:(NSString *)filename;

-(void)flushCache;

/// ensure all pending schema changes this collection have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes.
/// @param completionQueue the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
/// @param completionHandler the completionHandler to run on completion. May not be nil.
/// @note Schema changes are guaranteed to be completed before the next operation completes on a given colletion, so calling ensureSchema is totally optional.
/// @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
/// serial queue used for collection operations.
/// Passing nil will cause the system to select the correct queue for you:
/// if running on the UI thread then the completion handler will run on the UI thread,
/// otherwise the completionHandler will run on a background thread.
-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;

/// ensure all pending schema changes this collection have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes.
/// @param completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on the UI thread if the call is made
/// from the UI thread, otherwise the call is made from a background thread.
/// @note Schema changes are guaranteed to be completed before the next operation completes on a given colletion, so calling ensureSchema is totally optional.
-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSError *error))completionHandler;

/// ensure all pending schema changes this collection have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes.
/// @param error a pointer to the error which is set on failure (NO is returned). May be nil.
/// @returns YES on success. On failure NO is returned and error is set.
-(BOOL)ensureSchemaWithError:(NSError **)error;

/// ensure all pending schema changes this collection have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes.
/// @returns YES on success. On failure NO is returned. You may check lastError to get ore information on the error.
-(BOOL)ensureSchema;


/// Insert the json as a new record into the collection. On success the rowid of the new record is passed to the completion handler.
/// @param json the JSON dictionary to insert.
/// @param completionQueue the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
/// @param completionHandler the completionHandler to run on completion. May not be nil.
/// @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
/// serial queue used for collection operations.
/// Passing nil will cause the system to select the correct queue for you:
/// if running on the UI thread then the completion handler will run on the UI thread,
/// otherwise the completionHandler will run on a background thread.
-(void)beginInsert:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler;

/// Insert the json as a new record into the collection. On success the rowid of the new record is passed to the completion handler.
/// @param json the JSON dictionary to insert.
/// @param completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on the UI thread if the call is made
/// from the UI thread, otherwise the call is made from a background thread.
-(void)beginInsert:(NSDictionary *)json completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler;

/// Insert the json as a new record into the collection. On success the rowid of the new record is passed to the completion handler, on failure 0 is returned.
/// @param json the JSON dictionary to insert.
/// @param error a pointer to the error which is set on failure (0 is returned). May be nil.
/// @returns 0 on failure (error is set) or the new rowid.
-(NTJsonRowId)insert:(NSDictionary *)json error:(NSError **)error;

/// Insert the json as a new record into the collection. On success the rowid of the new record is passed to the completion handler, on failure 0 is returned.
/// @param json the JSON dictionary to insert.
/// @returns 0 on failure or the new rowid.
-(NTJsonRowId)insert:(NSDictionary *)json;

-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)insertBatch:(NSArray *)items error:(NSError **)error;
-(BOOL)insertBatch:(NSArray *)items;

-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)update:(NSDictionary *)json error:(NSError **)error;
-(BOOL)update:(NSDictionary *)json;

-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)remove:(NSDictionary *)json error:(NSError **)error;
-(BOOL)remove:(NSDictionary *)json;

-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)countWhere:(NSString *)where args:(NSArray *)args;
-(int)countWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;

-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginCountWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)countWithError:(NSError **)error;
-(int)count;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit error:(NSError **)error;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy error:(NSError **)error;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;

-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;
-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)removeWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;
-(int)removeWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)removeAllWithError:(NSError **)error;
-(int)removeAll;

-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;
-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler;
-(BOOL)syncWait:(dispatch_time_t)duration;
-(void)sync;

-(NSString *)description;

@end

