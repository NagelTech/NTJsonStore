//
//  NSArray+NTJsonStore.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NSArray+NTJsonStore.h"


@implementation NSArray (NTJsonStore)


-(NSArray *)NTJsonStore_transform:(id (^)(id item))block
{
    NSMutableArray *transformedArray = [NSMutableArray arrayWithCapacity:self.count];
    
    for(id item in self)
    {
        id transformed = block(item);
        
        if ( transformed )
            [transformedArray addObject:transformed];
    }
    
    return [transformedArray copy];
}


-(id)NTJsonStore_find:(BOOL (^)(id))block
{
    for(id item in self)
    {
        if ( block(item) )
            return item;
    }
    
    return nil;
}


@end
