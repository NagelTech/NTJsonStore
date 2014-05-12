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
@property (nonatomic,readonly) NSError *lastError;
@property (nonatomic) NSDictionary *defaultJson;

-(void)addIndexWithKeys:(NSString *)keys;
-(void)addUniqueIndexWithKeys:(NSString *)keys;
-(void)addQueryableFields:(NSString *)fields;

-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)ensureSchemaWithError:(NSError **)error;
-(BOOL)ensureSchema;

-(void)beginInsert:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler;
-(void)beginInsert:(NSDictionary *)json completionHandler:(void (^)(NTJsonRowId rowid, NSError *error))completionHandler;
-(NTJsonRowId)insert:(NSDictionary *)json error:(NSError **)error;
-(NTJsonRowId)insert:(NSDictionary *)json;

-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)insertBatch:(NSArray *)items error:(NSError **)error;
-(BOOL)insertBatch:(NSArray *)items;

-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)update:(NSDictionary *)json error:(NSError **)error;
-(BOOL)update:(NSDictionary *)json;

-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSError *error))completionHandler;
-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(NSError *error))completionHandler;
-(BOOL)remove:(NSDictionary *)json error:(NSError **)error;
-(BOOL)remove:(NSDictionary *)json;

-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)countWhere:(NSString *)where args:(NSArray *)args;
-(int)countWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;

-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginCountWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)countWithError:(NSError **)error;
-(int)count;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit error:(NSError **)error;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items, NSError *error))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy error:(NSError **)error;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;

-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;
-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item, NSError *error))completionHandler;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)removeWhere:(NSString *)where args:(NSArray *)args error:(NSError **)error;
-(int)removeWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count, NSError *error))completionHandler;
-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count, NSError *error))completionHandler;
-(int)removeAllWithError:(NSError **)error;
-(int)removeAll;

-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;
-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler;
-(BOOL)syncWait:(dispatch_time_t)duration;
-(void)sync;

-(NSString *)description;

@end

