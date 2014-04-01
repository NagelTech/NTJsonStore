//
//  NTJsonObjectCache.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/31/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


#import "NTJsonStore+Private.h"


//#define DEBUG_CACHE


#ifdef DEBUG_CACHE
#   define CACHE_LOG(format, ...) LOG_DBG(format, ##__VA_ARGS__)
#else
#   define CACHE_LOG(format, ...)
#endif



static const int DEFAULT_CACHE_SIZE = 50;


@class  NTJsonObjectCacheItem;


@interface NTJsonObjectProxy : NSProxy
{
    NTJsonObjectCacheItem __weak *_cacheItem;
}

-(id)initWithCacheItem:(NTJsonObjectCacheItem *)cacheItem;

@end


@interface NTJsonObjectCacheItem : NSObject
{
    NTJsonObjectCache __weak *_cache;
    NTJsonRowId _rowId;
    NSDictionary *_json;
    
    BOOL _isInUse;

    NTJsonObjectProxy __weak *_proxyObject;
}

@property (nonatomic,readonly) NTJsonObjectCache *cache;
@property (nonatomic,readonly) NTJsonRowId rowId;
@property (nonatomic,readonly) NSDictionary *json;

@property (nonatomic,readwrite) BOOL isInUse;

@property (nonatomic,readonly) NSDictionary *proxyObject;

-(id)initWithCache:(NTJsonObjectCache *)cache rowId:(NTJsonRowId)rowId json:(NSDictionary *)json;

@end


@interface NTJsonObjectCache ()
{
    NSMutableDictionary *_items;
    NSMutableArray *_cachedItems;
}

-(void)proxyDeallocedForCacheItem:(NTJsonObjectCacheItem *)cacheItem;

@end


#pragma mark - NTJsonObjectProxy


@implementation NTJsonObjectProxy


-(id)initWithCacheItem:(NTJsonObjectCacheItem *)cacheItem
{
    _cacheItem = cacheItem;
    
    return self;
}


-(void)forwardInvocation:(NSInvocation *)invocation
{
    [invocation setTarget:_cacheItem.json];
    [invocation invoke];
}


-(NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    return [_cacheItem.json methodSignatureForSelector:sel];
}


-(void)dealloc
{
    [_cacheItem.cache proxyDeallocedForCacheItem:_cacheItem];
}


@end


#pragma mark - NTJsonObjectCacheItem


@implementation NTJsonObjectCacheItem


-(NSDictionary *)proxyObject
{
    NTJsonObjectProxy *proxyObject = _proxyObject;
    
    if ( !proxyObject )
    {
        proxyObject = [[NTJsonObjectProxy alloc] initWithCacheItem:self];
        _proxyObject = proxyObject;
    }
    
    return (NSDictionary *)proxyObject;
}


-(id)initWithCache:(NTJsonObjectCache *)cache rowId:(NTJsonRowId)rowId json:(NSDictionary *)json
{
    self = [super init];
    
    if ( self )
    {
        _cache = cache;
        _rowId = rowId;
        _json = json;
        _isInUse = NO;
    }
    
    return self;
}


@end


#pragma mark - NTJsonObjectCache


@implementation NTJsonObjectCache


-(id)initWithCacheSize:(int)cacheSize
{
    self = [super init];
    
    if ( self )
    {
        _cacheSize = cacheSize;
        _items = [NSMutableDictionary dictionary];
        _cachedItems = [NSMutableArray array];
    }
    
    return self;
}


-(id)init
{
    return [self initWithCacheSize:DEFAULT_CACHE_SIZE];
}


-(void)proxyDeallocedForCacheItem:(NTJsonObjectCacheItem *)cacheItem
{
    CACHE_LOG(@"Caching - %d", (int)cacheItem.rowId);
    
    cacheItem.isInUse = NO;
    [_cachedItems addObject:cacheItem]; // newest are at end of the list.
    
    if ( !_cachedItems.count > _cacheSize )
        [self purgeCacheWithFlushAll:NO];
}


-(NSDictionary *)jsonWithRowId:(NTJsonRowId)rowId
{
    NTJsonObjectCacheItem *item = _items[@(rowId)];
    
    if ( !item )
    {
        CACHE_LOG(@"Cache miss - %d", (int)rowId);
        return nil;
    }
    
    if ( !item.isInUse )
    {
        CACHE_LOG(@"Cache Hit (not in use) - %d", (int)rowId);
        // coming back into action!
        item.isInUse = YES;
        [_cachedItems removeObjectIdenticalTo:item];    // it is no longer in our cache, since it's active
    }
    else
    {
        CACHE_LOG(@"Cache Hit (already in use) - %d", (int)rowId);
    }
    
    return item.proxyObject;
}


-(NSDictionary *)addJson:(NSDictionary *)json withRowId:(NTJsonRowId)rowId
{
    NTJsonObjectCacheItem *item = [[NTJsonObjectCacheItem alloc] initWithCache:self rowId:rowId json:json];
    
    CACHE_LOG(@"adding - %d", (int)rowId);
    
    _items[@(rowId)] = item;
    item.isInUse = YES;
    
    return item.proxyObject;
}


-(void)purgeCacheWithFlushAll:(BOOL)flushAll
{
    int cacheSize = (flushAll) ? 0 : _cacheSize;
    
    // clear any unused values from the cache...
    
    while (_cachedItems.count > cacheSize )
    {
        NTJsonObjectCacheItem *item = _cachedItems[0];  // grab oldest...
        
        CACHE_LOG(@"purging - %d", (int)item.rowId);
        
        // remove it...
        
        [_cachedItems removeObjectAtIndex:0];
        [_items removeObjectForKey:@(item.rowId)];
    }
}


-(void)flush
{
    [self purgeCacheWithFlushAll:YES];
}


@end
