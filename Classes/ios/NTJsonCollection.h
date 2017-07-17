//
//  NTJsonCollection.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"
#import "NTJsonLiveQuery.h"


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

/// The error from the last operation. Useful when using synchronous API methods.
@property (nonatomic,readonly) NSError *lastError;

/// Dictionary of default values for JSON keys. Default values are used in queries when the associated value does not exist in a JSON record.
@property (nonatomic) NSDictionary *defaultJson;

/// Dictionary of string aliases (macros) to be replaced in any query string.
@property (nonatomic) NSDictionary *aliases;

/// the number of items to cache internally. Set to 0 to disable caching of items (the system will still track items that are in use and return the
/// same instance.) Set to -1 to disable ALL caching - in this configuration a new NSDictionary will be deserialized and returned for each request. Default: 50.
@property (nonatomic) int cacheSize;

/// Add a unique index with the key string if it doesn't already exist. Calling this has no effect if the index already exists.
/// @param keys a comma-separated list of JSON paths paths to index on.
-(void)addIndexWithKeys:(NSString *)keys;

/// Add an index with the key string if it doesn't already exist. Calling this has no effect if the index already exists.
/// @param keys a comma-separated list of JSON paths paths to index on.
-(void)addUniqueIndexWithKeys:(NSString *)keys;

/// Ensure that the passed JSON paths are queryable. This is a performance optionization and is optional. If queryable fields are pre-declared they will be added the first time they are used in a query.
/// @param fields a comma-separated list of JSON paths paths.
-(void)addQueryableFields:(NSString *)fields;

/// replace any aliases in string with the values from self.aliases. Useful for testing.
-(NSString *)replaceAliasesIn:(NSString *)string;

-(void)applyConfig:(NSDictionary *)config;
-(BOOL)applyConfigFile:(NSString *)filename;

/**
 *  Flushes any items in the LRU cache.
 */
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

/**
 *   Insert a group of items into the collection. This is a transactional operation -- either all items are inserted or none are.
 *
 *  @param items             the items to insert
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *      serial queue used for collection operations.
 *      Passing nil will cause the system to select the correct queue for you:
 *      if running on the UI thread then the completion handler will run on the UI thread,
 *      otherwise the completionHandler will run on a background thread.
 */
-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *   Insert a group of items into the collection. This is a transactional operation -- either all items are inserted or none are.
 *
 *  @param items             the items to insert
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on 
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *   Insert a group of items into the collection. This is a transactional operation -- either all items are inserted or none are.
 *
 *  @param items             the items to insert
 *  @param error             a pointer to the error which is set on failure (0 is returned). May be nil.
 *  @return                  YES on success or NO on failure (error is set)
 */

-(BOOL)insertBatch:(NSArray *)items error:(NSError **)error;
/**
 *   Insert a group of items into the collection. This is a transactional operation -- either all items are inserted or none are.
 *
 *  @param items             the items to insert
 *  @return                  YES on success or NO on failure (self.error is set)
 */
-(BOOL)insertBatch:(NSArray *)items;

/**
 *  Update an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to update (__rowid__ must be set)
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 */
-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *  Update an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to update (__rowid__ must be set)
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *  Update an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to update (__rowid__ must be set)
 *  @param error             a pointer to the error which is set on failure (0 is returned). May be nil.
 *  @return                  YES on success or NO on failure (error is set)
 */
-(BOOL)update:(NSDictionary *)json error:(NSError **)error;

/**
 *  Update an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to update (__rowid__ must be set)
 *  @return                  YES on success or NO on failure (self.error is set)
 */
-(BOOL)update:(NSDictionary *)json;

/**
 *  Remove an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to remove (__rowid__ must be set)
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 */
-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *  Remove an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to remove (__rowid__ must be set)
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;

/**
 *  Remove an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to remove (__rowid__ must be set)
 *  @param error             a pointer to the error which is set on failure (0 is returned). May be nil.
 *  @return                  YES on success or NO on failure (error is set)
 */
-(BOOL)remove:(NSDictionary *)json error:(NSError **)error;

/**
 *  Remove an existing item in the collection. The item *must* have a property with the __rowid__ set, which is returned with any
 *  item returned by the collection API.
 *
 *  @param json              the item to remove (__rowid__ must be set)
 *  @return                  YES on success or NO on failure (self.error is set)
 */
-(BOOL)remove:(NSDictionary *)json;

/**
 *  Returns the count of items matching the query string.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ? 
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Returns the count of items matching the query string.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Returns the count of items matching the query string.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  the count of items or -1 on error (error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(int)countWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;

/**
 *  Returns the count of items matching the query string.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @return                  the count of items or -1 on error (self.error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(int)countWhere:(NSString *)where args:(NSArray *)args;

/**
 *  Returns the count of items in the collection.
 *
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 */
-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Returns the count of items in the collection.
 *
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginCountWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Returns the count of items in the collection.
 *
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  the count of items or -1 on error (error is set)
 */
-(int)countWithError:(NSError **)error;

/**
 *  Returns the count of items in the collection.
 *
 *  @return                  the count of items or -1 on error (self.error is set)
 */
-(int)count;

/**
 *  Returns at most limit items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param limit             return at most limit items. Pass zero to return all items matching the query.
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;

/**
 *  Returns at most limit items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param limit             return at most limit items. Pass zero to return all items matching the query.
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;

/**
 *  Returns at most limit items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param limit             return at most limit items. Pass zero to return all items matching the query.
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  An array of the matching items or nil on error (error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit error:(NSError **)error;

/**
 *  Returns at most limit items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param limit             return at most limit items. Pass zero to return all items matching the query.
 *  @return                  An array of the matching items or nil on error (self.error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

/**
 *  Returns all items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;

/**
 *  Returns all items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;

/**
 *  Returns all items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  An array of the matching items or nil on error (error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy error:(NSError **)error;

/**
 *  Returns all items matching the where clause, ordered by the orderBy clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param orderBy           A comma-separated list of JSON field names to order the results by. All JSON field names must be enclosed
 *                           in square braces. Items may be ordered descending by append "DESC" to the field name. May be nil.
 *  @return                  An array of the matching items or nil on error (self.error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;

/**
 *  Returns a single item matching the where clause, or nil of no match is found.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;

/**
 *  Returns a single item matching the where clause, or nil of no match is found.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;

/**
 *  Returns a single item matching the where clause, or nil of no match is found.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  the matching item or nil on error or not found (if there was is an eror, then error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;

/**
 *  Returns a single item matching the where clause, or nil of no match is found.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @return                  the matching item or nil on error or not found (if there was is an eror, then self.error is set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

/**
 *  Remove all items matching the where clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Remove all items matching the where clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Remove all items matching the where clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return                  the number of items deleted or -1 on error (error will be set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(int)removeWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;

/**
 *  Remove all items matching the where clause.
 *
 *  @param where             the SQLITE WHERE clause to execute. may be nil. See notes.
 *  @param args              arguments to the where clause, may be nil.
 *  @return                  the number of items deleted or -1 on error (self.error will be set)
 *  @note Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ?
 *        in the query string and adding the value in the `args` array. (Parameterized SQL.) All JSON fields must be enclosed in square braces.
 *        Nested JSON fields are allowed using "." notation.
 */
-(int)removeWhere:(NSString *)where args:(NSArray *)args;

/**
 *  Remove all items in the collection.
 *
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 */
-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Remove all items in the collection.
 *
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;

/**
 *  Remove all items in the collection.
 *
 *  @param error             a pointer to the error which is set on failure (-1 is returned). May be nil.
 *  @return the number of items removed or -1 on error (error will be set)
 */
-(int)removeAllWithError:(NSError **)error;

/**
 *  Remove all items in the collection.
 *
 *  @return the number of items removed or -1 on error (self.error will be set)
 */
-(int)removeAll;

/**
 *  execute the completionHandler once all currently pending operations have completed for the collection.
 *
 *  @param completionQueue   the queue to execute the completion handler in. Passing nil will cause a default to be selected for you. See notes.
 *  @param completionHandler the completionHandler to run on completion. May not be nil.
 *  @note completionQueue may be a speficic queue, nil or the special queue 'NTJsonStoreSerialQueue'. NTJsonStoreSerialQueue is an alias for the internal
 *        serial queue used for collection operations.
 *        Passing nil will cause the system to select the correct queue for you:
 *        if running on the UI thread then the completion handler will run on the UI thread,
 *        otherwise the completionHandler will run on a background thread.
 */
-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;

/**
 *  execute the completionHandler once all currently pending operations have completed for the collection.
 *
 *  @param completionHandler completionHandler the completionHandler to run on completion. May not be nil. The completionHandler is run on
 *                           the UI thread if the call is made from the UI thread, otherwise the call is made from a background thread.
 */
-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler;

/**
 *  block the current thread until all currently pending operations have been completed or the timeout has elapsed.
 *
 *  @param duration the maximum number of MS to wait for pending operations to complete.
 *
 *  @return YES if pending operations completed before the timeout, NO if a timeout occurred.
 */
-(BOOL)syncWait:(dispatch_time_t)duration;

/**
 *  block the current thread until all currently pending operations have been completed.
 */
-(void)sync;

/**
 *  returns the name of the collection
 *
 *  @return the name of the collection.
 */
-(NSString *)description;

-(NTJsonLiveQuery *)liveQueryWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

- (BOOL)pushChanges;

@end

