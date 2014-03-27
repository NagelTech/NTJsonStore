//
//  NSDictionary+NTJsonStore.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NSDictionary+NTJsonStore.h"


@implementation NSDictionary (NTJsonStore)


-(id)NTJsonStore_objectForKeyPath:(NSString *)keyPath
{
    // If we find a path, "x.y", parse the element and call ourselves recursively...
    
    int dotPos = [keyPath rangeOfString:@"."].location;
    
    if ( dotPos != NSNotFound)
    {
        NSString *key = [keyPath substringToIndex:dotPos];
        NSString *remainingKeyPath = [keyPath substringFromIndex:dotPos+1];
        
        NSDictionary *value = [self objectForKey:key];
        
        if ( !value || ![value isKindOfClass:[NSDictionary class]] )
            return nil; // key path not found
        
        return [value NTJsonStore_objectForKeyPath:remainingKeyPath];   // recursive
    }
    
    // If we get here, it's a simple key...
    
    id value = [self objectForKey:keyPath];
    
    return (value) ? value : nil;
}


@end
