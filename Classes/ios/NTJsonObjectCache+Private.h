//
//  NTJsonObjectCache.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/31/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"


@class NTJsonObjectCache;
@class NTJsonDictionary;


@interface NTJsonObjectCacheItem : NSObject
{
@public // allow direct access for performance
    NTJsonObjectCache __weak *_cache;
    NTJsonRowId _rowId;
    NSDictionary *_json;
    
    BOOL _isInUse;
    
    NTJsonDictionary __weak *_proxyObject;
}

@property (nonatomic,readwrite,weak) NTJsonObjectCache *cache;
@property (nonatomic,readonly) NTJsonRowId rowId;
@property (nonatomic,readonly) NSDictionary *json;

@property (nonatomic,readwrite) BOOL isInUse;

@property (nonatomic,readonly) NTJsonDictionary *proxyObject;

-(id)initWithCache:(NTJsonObjectCache *)cache rowId:(NTJsonRowId)rowId json:(NSDictionary *)json;

@end


@interface NTJsonObjectCache : NSObject
{
    NSMutableDictionary *_items;
    NSMutableArray *_cachedItems;
}


@property (nonatomic) int cacheSize;

-(id)initWithCacheSize:(int)cacheSize;
-(id)init;

-(NSDictionary *)jsonWithRowId:(NTJsonRowId)rowId;
-(id)addJson:(NSDictionary *)json withRowId:(NTJsonRowId)rowId;
-(void)removeObjectWithRowId:(NTJsonRowId)rowId;

-(void)flush;
-(void)removeAll;

-(void)proxyDeallocedForCacheItem:(NTJsonObjectCacheItem *)cacheItem;


@end
