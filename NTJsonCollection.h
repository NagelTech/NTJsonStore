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

-(void)beginInsert:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NTJsonRowId rowid))completionHandler;
-(void)beginInsert:(NSDictionary *)json completionHandler:(void (^)(NTJsonRowId rowid))completionHandler;
-(NTJsonRowId)insert:(NSDictionary *)json;

-(void)beginInsertBatch:(NSArray *)items completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler;
-(void)beginInsertBatch:(NSArray *)items completionHandler:(void (^)(BOOL success))completionHandler;
-(BOOL)insertBatch:(NSArray *)items;

-(void)beginUpdate:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler;
-(void)beginUpdate:(NSDictionary *)json completionHandler:(void (^)(BOOL success))completionHandler;
-(BOOL)update:(NSDictionary *)json;

-(void)beginRemove:(NSDictionary *)json completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(BOOL success))completionHandler;
-(void)beginRemove:(NSDictionary *)json completionHandler:(void (^)(BOOL success))completionHandler;
-(BOOL)remove:(NSDictionary *)json;

-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler;
-(void)beginCountWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count))completionHandler;
-(int)countWhere:(NSString *)where args:(NSArray *)args;

-(void)beginCountWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler;
-(void)beginCountWithCompletionHandler:(void (^)(int count))completionHandler;
-(int)count;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit completionHandler:(void (^)(NSArray *items))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy limit:(int)limit;

-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *items))completionHandler;
-(void)beginFindWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy completionHandler:(void (^)(NSArray *items))completionHandler;
-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;

-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSDictionary *item))completionHandler;
-(void)beginFindOneWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(NSDictionary *item))completionHandler;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler;
-(void)beginRemoveWhere:(NSString *)where args:(NSArray *)args completionHandler:(void (^)(int count))completionHandler;
-(int)removeWhere:(NSString *)where args:(NSArray *)args;

-(void)beginRemoveAllWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(int count))completionHandler;
-(void)beginRemoveAllWithCompletionHandler:(void (^)(int count))completionHandler;
-(int)removeAll;

-(NSString *)description;

@end

