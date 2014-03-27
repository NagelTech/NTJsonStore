//
//  NSDictionary+NTJsonStore.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (NTJsonStore)

-(id)NTJsonStore_objectForKeyPath:(NSString *)keyPath;

@end
