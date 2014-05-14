//
//  NTJsonDictionary.m
//  NTJsonStoreTests
//
//  Created by Ethan Nagel on 5/13/14.
//
//


#import "NTJsonStore+Private.h"


#define dict ((NSDictionary *)_cacheItem->_json)


@interface NTJsonDictionary ()
{
    NTJsonObjectCacheItem *_cacheItem;
}

@end


@implementation NTJsonDictionary


#pragma mark - Our Stuff


-(id)initWithCacheItem:(NTJsonObjectCacheItem *)cacheItem
{
    if ( (self=[super init]) )
    {
        _cacheItem = cacheItem;
    }
    
    return self;
}


-(BOOL)NTJson_isCurrent
{
    return (_cacheItem.cache) ? YES : NO;
}


-(void)dealloc
{
    [_cacheItem.cache proxyDeallocedForCacheItem:_cacheItem];
}


#pragma mark - Required Methods


-(NSUInteger)count
{
    return [dict count];
}


-(id)objectForKey:(id)aKey
{
    return [dict objectForKey:aKey];
}


-(NSEnumerator *)keyEnumerator
{
    return [dict keyEnumerator];
}


#pragma mark - Selected Optional Methods


// (These are not required but are added here to improve performance)


-(NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len
{
    return [dict countByEnumeratingWithState:state objects:buffer count:len];
}


-(BOOL)isEqualToDictionary:(NSDictionary *)otherDictionary
{
    return [dict isEqualToDictionary:otherDictionary];
}


-(NSArray *)allKeys
{
    return [dict allKeys];
}


-(NSArray *)allValues
{
    return [dict allValues];
}


-(NSEnumerator *)objectEnumerator
{
    return [dict objectEnumerator];
}


-(void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block
{
    return [dict enumerateKeysAndObjectsUsingBlock:block];
}


-(void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id, id, BOOL *))block
{
    return [dict enumerateKeysAndObjectsWithOptions:opts usingBlock:block];
}



@end
