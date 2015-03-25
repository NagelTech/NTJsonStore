To Do 1.0
=========

 - documentation

 - sample application (freebase?)

 - General thread safety validation pass

 - Consider removing NTJsonDictionary all together in favor of plain vanilla NSDictionaries. (May impact cache performance.)

 - Investigate multi-process access to Stores (iOS 8 extensions.) Do we need to use (or enable) a NSFileCoordinator to manage the cache? Does SQLITE work multi-process already? Can we add a presenter for the existing sqlite file? Maybe not? http://www.atomicbird.com/blog/sharing-with-app-extensions

 - Even if sqlite can handle multi-process stores, we need to deal with cache invalidation between processes somehow.


To Do Later Versions
====================

- Allow returned items to be model objects, conforming to a protocol `NTJsonStorable`. Configuration value to set the "model" class for a collection which would be returned instead of the NSDictionary. NTJsonStorable objects are expected to (1) be immutable and (2) implement initWithJson: and (3) implement asJson which should return the original JSON. This task is easier if we remove support for used cach entry detection (NTJsonDictionary), otherwise we will need to create a proxy wrapper for this class.

 - Consider a SQLite database per collection. May impact performance or memory significantly but would allow concurrent writes on multiple collections (which SQLITE doesn't actully support)

 - maintain count in memory when we know it.
 
 - research: getCompletionQueue to continue using the collection or store queue if already in that context? Does that makes sense?
 
 - Optimized JSON format. Store JSON in a binary format that can be searched and deserialized very quickly.
   Take advantage of the fact we have a collection of similar items to maintain a master list of keys.
   
 - Cache query responses. cache Query responses (array of `__rowid__`'s) and avoid making unnecessary calls. Flush cache on insert/update/delete.
 
 - Add simple local query support, integrated into query cache. Simple queries, such as get an object by a key can be handled without going to SQLIITE
   each time. (Load a hash of keys -> rowid's once then do a lookup.)
   
 - intelligent query cache clearing. Notice what columns have changed and only clear impacted queries. (Maybe not necesary?)

 - Aggregate returns, ie "sum(user.age)"
 
 - Add notifications when collections or objects are modified. This also enables caching.
 
 - Add notifications when query results are changed. (This becomes possible with robust query caching.)

 - eliminate ensureSchema support in favor of starting tasks immediately?
 
  - Transaction support causes lots of issues with caching and concurrency. It's probably not a good idea to complicate the codebase with it.
   If we did, here are some ideas:  - Transactions will be a block - return true to commit, false to rollback. They should work at the store level, across 
   collections. -(BOOL)performTransaction:(BOOL (^)())transactionBlock error:(NSError **)error; and -(void)beginTransaction:(BOOL (^)())transactionBlock completionQueue:(dispatch_queue_t)completionQueue completionBlock:(void (^)(BOOL success, NSError *error))completionBlock; Caching would either be
    read only or have transaction support.
   
 - More Transaction Ideas - Support only synchronous calls within a transaction. Maybe they are limited to a single collection only? Limits the complexity and the usefulness ;) The entire transaction should run as a single item in the serial queue (store or collection.) Perhaps flush the cache in the event of a failed transaction?
 

Don't Do
========

 - Support partial responses (return subset of JSON.) This will complicate caching and may actually degrade performance overall.
 
 - Fucking dates in JSON. What to do? We support the pure JSON format.

 - Add a way to return mutable JSON data. Return immutable by default to make caching work better.
 
 - Support either an NSDictionary or NSArray as the root of a JSON object. We can't support array's as the root currently because we tore the rowid in the root
   of the object.

