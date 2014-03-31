//
//  NTJsonCollection.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"


@class NTJsonStore;


@interface NTJsonCollection : NSObject

@property (nonatomic,readonly) NSString *name;
@property (nonatomic,readonly) NTJsonStore *store;

-(void)addIndexWithKeys:(NSString *)keys;
-(void)addUniqueIndexWithKeys:(NSString *)keys;
-(void)addQueryableFields:(NSString *)fields;
-(BOOL)ensureSchema;

-(NTJsonRowId)insert:(NSDictionary *)json;
-(BOOL)update:(NSDictionary *)json;
-(BOOL)remove:(NSDictionary *)json;

-(BOOL)insertBatch:(NSArray *)items;

-(int)countWhere:(NSString *)where args:(NSArray *)args;
-(int)count;

-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

-(int)removeWhere:(NSString *)where args:(NSArray *)args;
-(int)removeAll;

-(NSString *)description;

@end

