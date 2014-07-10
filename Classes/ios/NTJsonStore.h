//
//  NTJsonStore.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"
#import "NTJsonCollection.h"


/// NTJsonStore is a container for a group of NTJsonCollections. It owns the underlying SQLITE store and has methods
/// to assist in synchronizing operations across collections.
@interface NTJsonStore : NSObject

/// path to the JsonStore file, defaults to the Cache folder
@property (nonatomic,readonly)      NSString *storePath;

/// the filename of the JsonStore, defaults to NTJsonStore.db
@property (nonatomic,readonly)      NSString *storeName;

/// the full filename of the JsonStore file, storePath + storeName
@property (nonatomic,readonly)      NSString *storeFilename;

/// YES if storeFilename exists.
@property (nonatomic,readonly)      BOOL exists;

/// An array of all NTJsonCollections that exist in this store. The first time this is accessed, it will read the list of stores from the db.
@property (nonatomic,readonly)      NSArray *collections;

-(id)init;
-(id)initWithName:(NSString *)storeName;
-(id)initWithPath:(NSString *)storePath name:(NSString *)storeName;

/// Close the underlying store and any underlying collections. Once explicitly closed, the store instance cannot be re-opened.
-(void)close;

/// returns a collection with the indicated name. If the collection doesn't exist a new one will be created when it is first accessed.
/// @param collectionName the name of the collection (collection names are not case sensitive.)
/// @return a new or existing NTJsonCollection
/// @note If the list of collections hasn't been read yet, this call will block while they are loaded into memory.
-(NTJsonCollection *)collectionWithName:(NSString *)collectionName;

/// ensure all pending schema changes for all collections have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes. Any errors encountered in an array to the completion handler upon completion.
/// @param completionQueue the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
/// @param completionHandler the completionHandler to run on completion. May not be nil.
/// @note Schema changes are guaranteed to be completed before the next operation completes on a given colletion, so calling ensureSchema is totally optional.
/// @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
/// serial queue used for store-wide operations.
/// Passing nil will cause the system to select the correct queue for you:
/// if running on the UI thread then the completion handler will run on the UI thread,
/// otherwise the completionHandler will run on a background thread.
-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *errors))completionHandler;

/// ensure all pending schema changes for all collections have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes. Any errors encountered in an array to the completion handler upon completion.
/// @param completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on the UI thread if the call is made
/// from the UI thread, otherwise the call is made from a background thread.
/// @note Schema changes are guaranteed to be completed before the next operation completes on a given colletion, so calling ensureSchema is totally optional.
-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSArray *errors))completionHandler;

/// ensure all pending schema changes for all collections have been committed to the data store. Changes to indexes, queryable fields and
/// defaults will all be written when this call completes. Any errors encountered are returned an array upon completion.
/// @param completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on the UI thread if the call is made
/// @returns nil on success or an array of NSErrors encountered.
-(NSArray *)ensureSchema;

/// Returns YES if the dictionary passed is guaranteed to match the value currrently stored in a collection.
/// @note This is a very fast call and is appropriate to use for caching decisions - it works by inspecting the internal state of the cache record assciated
/// with this NSDictionary. This method will return YES for NSDictionaries returned through any NSJsonCollection method as long as the underlying record has not
/// changed. If the NSDIctionary has been copied, the method will return NO. If caching has been disabled for the underlying collection (NTJsonCollection.cacheSize = -1), this methos will always return NO.
+(BOOL)isJsonCurrent:(NSDictionary *)json;

/// Executes the completionHandler once all pending operations for the passed collections have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first.
/// @param collections an array of collections to synchronize. Pass nil to sync all collections.
/// @param completionQueue the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
/// @param completionHandler the completionHandler to run on completion. May not be nil.
/// @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
/// serial queue used for store-wide operations.
/// Passing nil will cause the system to select the correct queue for you:
/// if running on the UI thread then the completion handler will run on the UI thread,
/// otherwise the completionHandler will run on a background thread.
-(void)beginSyncCollections:(NSArray *)collections withCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;

/// Executes the completionHandler once all pending operations all collections in the store have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first.
/// @param completionQueue the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
/// @param completionHandler the completionHandler to run on completion. May not be nil.
/// @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
/// serial queue used for store-wide operations.
/// Passing nil will cause the system to select the correct queue for you:
/// if running on the UI thread then the completion handler will run on the UI thread,
/// otherwise the completionHandler will run on a background thread.
-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;

/// Executes the completionHandler once all pending operations all collections in the store have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first.
/// @param completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on the UI thread if the call is made
/// from the UI thread, otherwise the call is made from a background thread.
-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler;

/// Pauses the current thread until all pending operations for the passed collections have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first.
/// @param collections an array of collections to synchronize. Pass nil to sync all collections.
/// @param timeout the length of time to wait for the sync to complete. Pass DISPATCH_TIME_FOREVER to pause the current thread until all pending operations complete.
-(void)syncCollections:(NSArray *)collections wait:(dispatch_time_t)timeout;

/// Pauses the current thread until all pending operations for all collections in the store have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first.
/// @param timeout the length of time to wait for the sync to complete. Pass DISPATCH_TIME_FOREVER to pause the current thread until all pending operations complete.
-(void)syncWait:(dispatch_time_t)timeout;

/// Pauses the current thread until all pending operations for all collections in the store have been completed. This is a convenient way to perform an
/// operation that requires several operations across collections to be completed first. This method will block until all pending operations have been completed.
-(void)sync;

@end

