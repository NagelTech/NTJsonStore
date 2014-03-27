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

-(id)initWithStore:(NTJsonStore *)store name:(NSString *)name;

-(BOOL)createCollection;

@end
