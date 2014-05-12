NTJsonStore
===========

[In development] A No-SQL-like JSON data store, transparently leveraging SQLITE for storage and indexing.


To Do 1.0
=========

 - allow path for store to be set.
 
 - Support either an NSDictionary or NSArray as the root of a JSON object.
 
 - Investgate replacing NSProxy objects with native implementations to improve performance. Or, implement "Fast global proxy forwarding"? NTFastProxy
 
 - Allow setting size of cache or disabling it entirely. Value = cache size, 0 = no caching but track used objects, -1 = no caching at all.
 
 - getCompletionQueue to continue using the collection or store queue if already in that context? Does that makes sense?
 
 - tests
 
 - documentation

 - sample application (freebase?)


To Do Later Versions
====================

 - maintain count in memory when we know it.

 - Optimized JSON format. Store JSON in a binary format that can be searched and deserialized very quickly.
   Take advantage of the fact we have a collection of similar items to maintain a master list of keys.
   
 - Cache query responses. cache Query responses (array of __rowid__'s) and avoid making unnecessary calls. Flush cache on insert/update/delete.
 
 - Add simple local query support, integrated into query cache. Simple queries, such as get an object by a key can be handled without going to SQLIITE
   each time. (Load a hash of keys -> rowid's once then do a lookup.)
   
 - intelligent query cache clearing. Notice what columns have changed and only clear impacted queries. (Maybe not necesary?)

 - Aggregate returns, ie "sum(user.age)"
 
 - Add notifications when collections or objects are modified. This also enables caching.
 
 - Add notifications when query results are changed. (This becomes possible with robus query caching.)


Don't Do
========

 - Support partial responses (return subset of JSON.) This will complicate caching and may actually degrade performance overall.
 
 - Fucking dates in JSON. What to do? We support the pure JSON format.

 - Add a way to return mutable JSON data. Return immutable by default to make caching work better.
 
 - Transaction support causes lots of issues with caching and concurrency. It's probably not a good idea to complicate the codebase with it.
   If we did, here are some ideas:  - Transactions will be a block - return true to commit, false to rollback. They should work at the store level, across 
   collections. -(BOOL)transaction:(BOOL (^)())transactionBlock error:(NSError **)error; and -(void)beginTransaction:(BOOL (^)())transactionBlock completionQueue:(dispatch_queue_t)completionQueue completionBlock:(void (^)(BOOL success, NSError *error))completionBlock; Caching would ither beread only or have
   transaction support.

Done
====

 - Cache JSON objects. Only deserialize and return an object once. (While in memory, we can always return the same object.)
   Cache disposed objects as well for a defined amount of time. Update the cache on insert/update.
   
 - Threading.
 
  - Add method to determine if JSON is the current value. (NTJsonCollection isJsonCurrent:) This will enable higher-level caching (Model level)
 
  - Error returns/handling.
 
 - transaction support for insertBatch
 
  - deal with retain cycle between Store and Collections appropriately. Best idea so far: Collections maintain weak links to the Store. Application must
   maintain an explicit reference to thet store to keep it open. Add an explicit command to close a store which would close all collections as well.


 

