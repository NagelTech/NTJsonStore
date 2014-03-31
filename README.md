NTJsonStore
===========

[In development] A No-SQL-like JSON data store, transparently leveraging SQLITE for storage and indexing.

To Do
=====

 - Cache JSON objects. Only deserialize and return an object once. (While in memory, we can always return the same object.)
   Cache disposed objects as well for a defined amount of time. Update the cache on insert/update.
   
 - Threading.
 
 - Error returns/handling.

 - Optimized JSON format. Store JSON in a binary format that can be searched and deserialized very quickly.
   Take advantage of the fact we have a collection of tems to maintain a master list of keys.
   
 - Cache query responses. cache Query responses (array of __rowid__'s) and avoid making unnecessary calls. Flush cache on insert/update.
 
 - Cache sqlite queries. (Well maybe. Are we caching enough already?)
 
 - Fucking dates in JSON. What to do?

 - Add a way to return mutable JSON data. Return immutable by default to make caching work better.
 
 - Aggregate returns, ie "sum(user.age)"
 

Don't Do
========

 - Support partial responses (return subset of JSON.) This will complicate caching and may actually degrade performance overall.

