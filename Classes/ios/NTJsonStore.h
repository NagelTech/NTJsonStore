//
//  NTJsonStore.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"
#import "NTJsonCollection.h"


extern dispatch_queue_t NTJsonStoreSerialQueue;


@interface NTJsonStore : NSObject

@property (nonatomic)               NSString *storePath;
@property (nonatomic)               NSString *storeName;

@property (nonatomic,readonly)      NSString *storeFilename;
@property (readonly,nonatomic)      BOOL exists;

@property (nonatomic,readonly)      NSArray *collections;


-(id)initWithName:(NSString *)storeName;

-(NTJsonCollection *)collectionWithName:(NSString *)collectionName;

-(void)beginEnsureSchemaWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)(NSArray *errors))completionHandler;
-(void)beginEnsureSchemaWithCompletionHandler:(void (^)(NSArray *errors))completionHandler;
-(NSArray *)ensureSchema;

+(BOOL)isJsonCurrent:(NSDictionary *)json;

-(void)beginSyncCollections:(NSArray *)collections withCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;
-(void)beginSyncWithCompletionQueue:(dispatch_queue_t)completionQueue completionHandler:(void (^)())completionHandler;
-(void)beginSyncWithCompletionHandler:(void (^)())completionHandler;
-(void)syncCollections:(NSArray *)collections wait:(dispatch_time_t)timeout;
-(void)syncWait:(dispatch_time_t)timeout;
-(void)sync;


@end

