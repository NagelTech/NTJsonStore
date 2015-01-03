# NTJsonStore

NTJsonStore is a schemaless document-oriented data store that will be immediately familiar of you have used MongoDB or similar systems. Key features include:
 
 - **Document-oriented JSON storage.** Values are stored as JSON-compliant NSDictionaries. (The data that could be returned by `NSJSONSerialization` is supported.)
 - **Full index support.** Data is ultimately stored in SQLITE, so you get the full performance and flexibility of SQLITE indexes. Unique and non-unique indexes, multiple keys and keys that are nested in the JSON are all supported.
 - **Flexible queries.** Queries may contain any value that appears in your JSON document, including nested values using dot notation. Anything that is allowed in a SQLITE WHERE clause is allowed, as long as you stick to a single collection (TABLE.)
 - **No upgrade headaches.** Because the data is essentially schemaless, you are not required to "upgrade" the data store with application updates. Of course this might put an additional burden on the code that is using the data because you may encounter old or new data, but it's usually easy enough to work around.
 - **Simple multi-threading support.** Any call may be performed synchronously or asynchronously. The system will make sure operations for each collection happen in the same order. There is no concept of multiple contexts to deal with.


## API Overview
---

The `NTJsonStore` is a container for a group of `NTJsonCollections`. It owns the underlying SQLITE store and has methods to assist in synchronizing operations across collections. Each store has a global key-value collection of metadata which can be used to store aditional data about the store or collections. Collections are created as they are first accessed, so there is no explicit process to create a collection.

Each collection is represented by a `NTJsonCollection` object which is responsible for all access to an individual collection. Collections are created when they are first accessed and are schema-less.

### A Simple Example

	NTJsonStore *store = [[NTJsonStore alloc] initWithName:@"sample.db"];
	NSJsonCollection *collection = [store collectionWithName:@"users"];
	
	// these are optional but improve performance...
	[collection addIndex:@"[last_name], [first_name]"];
	[collection addQueryableFields:@"[address.country]"];
	
	NSString *country = @"US";
	NSArray *users = [collection findWhere:@"[address.country] = ?" args:@[country] orderBy:@"[last_name], [first_name]"];
	
	for(NSDictionary *user in users)
		NSLog(@"%@, %@", user[@"last_name"], user[@"first_name"]);


## Configuration
---

The Store encapsulates the database and allows access to the array of collections. The `storePath` defaults to the caches directory and the `storeName	 defaults to 'NTJsonStore.db'. These properties can be change any time before the store is first accessed.

There are several configuration settings for each collection:
    
 - **Indexes.** The system supports both unique an non-unique indexes. Add a unique index with `-addUni ueIndexWithKeys` or a non-uniue index with `-addIndexWithKeys:`. In both cases the "keys" is a single string with a comma-separated list of fields to be indexed. Each field *must* be enclosed in square braces. Additionally you may append `DESC` or `ASC` to any field to define the sort order.

  - **Queryable Fields.** Queryable fields tells the systems the fields you plan on using. If you make this call when the collection is empty it is very low cost. (Once there are records the system will extract the field from each JSON record and create columns for you.) The `-addQueryableFields:` message accepts a comma-separated list of field names, *each enclosed in square braces*. This call is totally optional and is used to improve performance -- if you use a field that has not been materialized the system will do transparently for you.

 - **Default JSON.** The defauls JSON defines default values for fields when performing queries. 
 
 - **Cache Size.** The system caches JSON results for you to minimize the overhead of parsing the JSON our of the data store as well as to reduce your memory footprint (by returning the same `NSDictionary` each time it is requested.) By default the system will track objects that are in use by your application (using some reference counting magic) and will cache up to 0 additional items. `setCacheSize:` is used to change the default, setting it to 0 will only track in use items while -1 will disable all caching so a new object is returned each time. Any other value inidcates the cache size. You can also flush the cache by calling `-flushCache`

These values are persisted between starts of the app (except for cache size which should be set on start-up.) It is recommended you set them on each start of the application, so any changes ( due to an upgrade, for instance), will be immediately reflected. Setting these values when when they are already in effect has no effect.

In addition to coniguring the values manually  by calling the methods above, items can be configured by passing a JSON configuration to `-applyJson:'.

 
## Query Strings
---

Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ? in the query string and adding the value in the `args` array. (Parameterized SQL.) The major limitation to keep in mind that NTJsonStore, like most documented-orieted systems, is not a relational store, so **queries are limited to a single collection**.

 - All JSON fields must be enclosed in square braces. Nested JSON fields are allowed using "." notation.
 - Cross-table queries are *not* allowed.
 - The store automatically  maintains columns for you in SQL to perform the queries. The first time a new field is used the column must be "materialized" - if the collection is large this can cause a performance impact.
 - You can tell the system which columns you plan on accessing by setting the "QuerableFields" either in the config or by calling the method. This will materialize any missing columns immediately.
 - Any other time you reference columns, such as in an order by clause, defining indexes or queryable fields, square braces are required enclosing the field names.
 

## NTJsonRowId
---

Each record returned from NTJsonStore has a row id that is guaranteed to be unique per collection. (This id increments for each new record and is not re-used.) This is returned in the JSON as "__rowid__" (`NTjsonRowIdKey`)


## Threading & Synchronization
---

`NTJsonStore` uses libdispatch for threading. Each collection maintains it's own serial queue for all operations. Operations may be performed synchronously with the calling thread or asynchrounously. For asynchrounous calls you may define a specific queue to run on. You may also force the completion handler to run on the internal queue for a collection by passing `NTJsonStoreSerialQueue` - this can be useful when coordinating multiple actions.

Additionally, the `NTJsonStore` has synchronization methods that allow you to synchronize the queues across multiple collections.


## Default JSON
---

Each collection has a `defaultJson` property which has any defaults used during queries when a value is not present in the JSON document. This is very handy when, say you want to treat a boolean value as false if it is not present.


## Caching
---

 - LRU cache
 - set cache size, default is 40 records
 - set cache to 0 to only track used JSON objects
 - sett cache to -1 to disable all caching, including tracking of used JSON objects.
 
 
## Metadata store
---

fsdf


---
---
---
---


To Do 1.0
=========

 - documentation

 - sample application (freebase?)

 - ensure thread safety when deallocing NTJsonDictionary instances

 - General thread safety clean-up (flushCache for instance is not protected.)

 - Consider removing NTJsonDictionary all together in favor of plain vanilla NSDictionaries. (May impact cache performance.)

 - Investgate multi-process access to Stores (iOS 8 extensions.) Do we need to use (or enable) a NSFileCoordinator to manage the cache? Does SQLITE work multi-process already? Can we add a presenter for the existing sqlite file? Maybe not? http://www.atomicbird.com/blog/sharing-with-app-extensions



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

