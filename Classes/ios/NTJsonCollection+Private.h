//
//  NTJsonCollection+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonCollection.h"

@class NTJsonStore;
@class NTJsonSqlConnection;


@interface NTJsonCollection (Private)

@property (nonatomic,readonly) NSArray *columns;
@property (nonatomic,readonly) NSArray *indexes;

@property (nonatomic,readonly) NTJsonSqlConnection *connection;

-(id)initWithStore:(NTJsonStore *)store name:(NSString *)name;
-(id)initNewCollectionWithStore:(NTJsonStore *)store name:(NSString *)name;

-(void)close;

-(void)closeLiveQuery:(NTJsonLiveQuery *)liveQuery;

+(void)enumerateFieldsInSql:(NSString *)sql block:(void (^)(NSString *fieldName, BOOL *stop))block;

@end
