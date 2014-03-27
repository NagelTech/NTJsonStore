//
//  NSArray+NTJsonStore.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (NTJsonStore)

-(NSArray *)NTJsonStore_transform:(id (^)(id item))block;
-(id)NTJsonStore_find:(BOOL (^)(id item))block;

@end
