//
//  NTJsonCollection.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>


@class NTJsonStore;


@interface NTJsonCollection : NSObject

@property (nonatomic,readonly) NSString *name;
@property (nonatomic,readonly) NTJsonStore *store;

-(NSDictionary *)insert:(NSDictionary *)json;
-(BOOL)update:(NSDictionary *)json;
-(BOOL)remove:(int)rowid;

-(int)countWhere:(NSString *)where args:(NSArray *)args;
-(int)count;

-(NSArray *)findWhere:(NSString *)where args:(NSArray *)args orderBy:(NSString *)orderBy;
-(NSDictionary *)findOneWhere:(NSString *)where args:(NSArray *)args;

-(int)removeWhere:(NSString *)where args:(NSArray *)args;

@end

