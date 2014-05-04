//
//  NTJsonColumn+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//


@interface NTJsonColumn : NSObject

@property (nonatomic,readonly) NSString *name;

+(NTJsonColumn *)columnWithName:(NSString *)name;

@end
