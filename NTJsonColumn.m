//
//  NTJsonColumn.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonStore+Private.h"

@interface NTJsonColumn ()
{
    NSString *_name;
}

@end


@implementation NTJsonColumn


-(NSString *)name
{
    return _name;
}


+(NTJsonColumn *)columnWithName:(NSString *)name
{
    NTJsonColumn *column = [[NTJsonColumn alloc] init];
    
    column->_name = name;
    
    return column;
}


@end
