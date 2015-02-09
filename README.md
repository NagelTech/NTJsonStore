# NTJsonStore

NTJsonStore is a schemaless document-oriented data store that will be immediately familiar of you have used MongoDB or similar systems. Key features include:
 
 - **Document-oriented JSON storage.** Values are stored as JSON-compliant NSDictionaries. (Anything that could be returned by `NSJSONSerialization` is supported - `NSNull`, `NSString`, `NSNumber`, `NSArray` and `NSDictionary`.)
 - **Full index support.** Data is ultimately stored in SQLITE, so you get the full performance and flexibility of SQLITE indexes. Unique and non-unique indexes, multiple keys and keys that are nested in the JSON are all supported.
 - **Flexible queries.** Queries may contain any value that appears in your JSON document, including nested values using dot notation. Anything that is allowed in a SQLITE WHERE clause is allowed, as long as you stick to a single collection (TABLE.)
 - **No upgrade headaches.** Because the data is essentially schemaless, you are not required to "upgrade" the data store with application updates. Of course this might put an additional burden on the code that is using the data because you may encounter old or new data, but it's usually easy enough to work around.
 - **Simple multi-threading support.** Any call may be performed synchronously or asynchronously. The system will make sure operations for each collection happen in the same order. There is no concept of multiple contexts to deal with.


## [API Overview](id:api-overview)
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

Each query method has a synchronous and asychronous flavor. Additionally, there are several asynchronous calls, passing defaults for different parameters. The big workhorse is `-find`, here are all the possibe ways to call it:

	-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
	-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
	-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit error:(NSError **)error;
	-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;
	-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
	-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
	-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy error:(NSError **)error;
	-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;

For each method the default for `completionQueue` is the main queue if the method is called on the main queue, otherwise it is a background queue.

The remaining methods (in adition to `find`) shouldn't surprise you:

 - `findOne` - A wrapper around `find` that returns a single object or nil of it was not found.
 - `count` Returns the count of items with an optional where clause.
 - `insert` - Inserts the passed JSON into the collection. The new rowid is returned. Note the original JSON is not modified, but when you read it back the `__rowid__` key will always be populated.
 - `insertBatch` - Insert mutiple items in a single transaction. If any insert fails, no changes will be made.
 - `update` - Update an existing JSON document. The passed JSON *must* have the `__rowid__` key populated. (All JSON values returned from the system will have this pre-populated.)
  - `remove` - Remove a single item from the collection. The passed JSON *must* have the `__rowid__` key populated.
  - `removeWhere` - Remove multiple items from the collection.
  
Additionally there are methods to [configure](#configuration) each collection and [synchronize](#threading-and-synchronization) queues.

## [Configuration](id:configuration)
---

The Store encapsulates the database and allows access to the array of collections. The `storePath` defaults to the caches directory and the `storeName	 defaults to 'NTJsonStore.db'. These properties can be change any time before the store is first accessed.

There are several configuration settings for each collection:
    
 - **Indexes.** The system supports both unique an non-unique indexes. Add a unique index with `-addUniqueIndexWithKeys` or a non-uniue index with `-addIndexWithKeys:`. In both cases the "keys" is a single string with a comma-separated list of fields to be indexed. Each field *must* be enclosed in square braces. Additionally you may append `DESC` or `ASC` to any field to define the sort order.

  - **Queryable Fields.** Queryable fields tells the systems the fields you plan on using. If you make this call when the collection is empty it is very low cost. (Once there are records the system will extract the field from each JSON record and create columns for you.) The `-addQueryableFields:` message accepts a comma-separated list of field names, *each enclosed in square braces*. This call is totally optional and is used to improve performance -- if you use a field that has not been materialized the system will do transparently for you.

 - **Default JSON.** The defauls JSON defines default values for fields when performing queries. 
 
 - **Cache Size.** The system caches JSON results for you to minimize the overhead of parsing the JSON our of the data store as well as to reduce your memory footprint (by returning the same `NSDictionary` each time it is requested.) By default the system will track objects that are in use by your application (using some reference counting magic) and will cache up to 0 additional items. `setCacheSize:` is used to change the default, setting it to 0 will only track in use items while -1 will disable all caching so a new object is returned each time. Any other value inidcates the cache size. You can also flush the cache by calling `-flushCache`
 
 - **Aliases.** Aliases are essentially macros that are maintained per collection. They are a great way to map model object property names to JSON fields in queries. For instance, you might have a JSON field such as `[user.first_name]` that unltimately maps to a model object property `firstName`.

These values are persisted between starts of the app (except for cache size which should be set on start-up.) It is recommended you set them on each start of the application, so any changes (due to an upgrade, for instance), will be immediately reflected. Setting these values when when they are already in effect has no effect.

 
## [Query Strings](id:query-strings)
---

Query strings are a subset of the SQLITE WHERE clause where JSON fields are enclosed in square braces. Values may be used by inserting a ? in the query string and adding the value in the `args` array. (Parameterized SQL.) The major limitation to keep in mind that NTJsonStore, like most documented-orieted systems, is not a relational store, so **queries are limited to a single collection**.

 - Aliases (which work like per-collection macros) are expanded immediately and are *not* enclosed in square braces. Common practice is to add aliases that map high level model object property names to JSON fields.
 - All JSON fields must be enclosed in square braces. Nested JSON fields are allowed using "." notation.
 - Cross-table queries are *not* supported.
 - The store automatically  maintains columns for you in SQL to perform the queries. The first time a new field is used the column must be "materialized" - if the collection is large this can cause a performance impact.
 - You can tell the system which columns you plan on accessing by setting the "QueryableFields" for each collection using `-addQueryableFields:`. This will materialize any missing columns immediately. 
 - Any other time you reference columns, such as in an order by clause, defining indexes or queryable fields, square braces are required enclosing the field names (aliases are always processed in these instances.)
 - If a value is not present in the JSON, then any corresponding value in the `defaultValues` NSDictionary will be used when processing queries. This is very useful if you have a value such as a boolean that you want to treat as `false` when it is not present.
 

## [NTJsonRowId](id:ntjsonrowid)
---

Each record returned from NTJsonStore has a row id that is guaranteed to be unique per collection. (This id increments for each new record and is not re-used.) This is returned in the JSON as `__rowid__` (`NTjsonRowIdKey`)


## [Threading & Synchronization](id:threading-and-synchronization)
---

`NTJsonStore` uses libdispatch for threading. Each collection maintains it's own serial queue for all operations. Operations may be performed synchronously with the calling thread or asynchrounously. For asynchrounous calls you may define a specific queue to run on. You may also force the completion handler to run on the internal queue for a collection by passing `NTJsonStoreSerialQueue` - this can be useful when coordinating multiple actions. 

Each collection has methods that allow synchronizing the collections queue with your own. This can be useful when you begin several asynchronous calls and want to perform an action only when they are all completed, for instance.

Additionally, the `NTJsonStore` has synchronization methods that allow you to synchronize the queues across multiple collections.

## [Caching](id:caching)
---

By default the system maintains two caches for each collection:
 - *In use items.* Some magic is used in the background to determine if a JSON document s still in use by the application (a reference count is maintained) For these items, the same value is always returned.
  - *Cached items.* Once items fall out of the "in use" cache, they are collected into an LRU cache. By default, 40 entries are maintained in the cache
  
Set the `cacheSize` to a positive value to set the size of the LRU cache or 0 to disable it. Set `cacheSize` to -1 to disable all caching, including in use item caching.

 
## [Metadata Store](id:metadata-store)
---

A key-value collection is maintained to store metatadata items for the store by `NTJsonStore`. This is used interally to store the [configuration](#configuration) information for each collection, but may be used for your own purposes as well. `-metadataWithKey:` returns the metadata with the associated key (the query will be run on a store-wide thread, but will return synchronously.) You can set metadata with `-saveMetadataWithKey:value`.


