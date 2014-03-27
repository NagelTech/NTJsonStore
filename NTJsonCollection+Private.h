//
//  NTJsonCollection+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonCollection.h"

@class NTJsonStore;


@interface NTJsonCollection (Private)

@property (nonatomic,readonly) NSArray *columns;
@property (nonatomic,readonly) NSArray *indexes;

-(id)initWithStore:(NTJsonStore *)store name:(NSString *)name;
-(id)initNewCollectionWithStore:(NTJsonStore *)store name:(NSString *)name;

@end
