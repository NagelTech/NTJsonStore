NTJsonStore
===========

[In development] A No-SQL-like JSON data store, transparently leveraging SQLITE for storage and indexing.


To Do
=====

 - Threading.
 
 - Error returns/handling.

 - Optimized JSON format. Store JSON in a binary format that can be searched and deserialized very quickly.
   Take advantage of the fact we have a collection of similar items to maintain a master list of keys.
   
 - Cache query responses. cache Query responses (array of __rowid__'s) and avoid making unnecessary calls. Flush cache on insert/update/delete.
 
 - Add simple local query support, integrated into query cache. Simple queries, such as get an object by a key can be handled without going to SQLIITE
   each time. (Load a hash of keys -> rowid's once then do a lookup.)
   
 - intelligent query cache clearing. Notice what columns have changed and only clear impacted queries. (Maybe not necesary?)
 
 - Fucking dates in JSON. What to do?

 - Add a way to return mutable JSON data. Return immutable by default to make caching work better.
 
 - Aggregate returns, ie "sum(user.age)"
 
 - Add method to determine if JSON is the current value. (NTJsonCollection isJsonCurrent:) This will enable higher-level caching (Model level)
 
 - Add notifications when collections or objects are modified. This also enables caching.
 
 - Add notifications when query results are changed. (This becomes possible with robus query caching.)
 

Don't Do
========

 - Support partial responses (return subset of JSON.) This will complicate caching and may actually degrade performance overall.
 
 
Done
====

 - Cache JSON objects. Only deserialize and return an object once. (While in memory, we can always return the same object.)
   Cache disposed objects as well for a defined amount of time. Update the cache on insert/update.
   
