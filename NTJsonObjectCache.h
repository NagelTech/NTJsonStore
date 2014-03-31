//
//  NTJsonObjectCache.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/31/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"


@interface NTJsonObjectCache : NSObject

@property (nonatomic) int cacheSize;

-(id)initWithCacheSize:(int)cacheSize;
-(id)init;

-(NSDictionary *)jsonWithRowId:(NTJsonRowId)rowId;
-(NSDictionary *)addJson:(NSDictionary *)json withRowId:(NTJsonRowId)rowId;

-(void)flush;

@end
