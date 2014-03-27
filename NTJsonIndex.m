//
//  NTJsonIndex.m
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/27/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonIndex.h"


@interface NTJsonIndex ()
{
    BOOL _isUnique;
    NSString *_name;
    NSString *_keys;
}

@end


@implementation NTJsonIndex


-(BOOL)isUnique
{
    return _isUnique;
}


-(NSString *)name
{
    return _name;
}


-(NSString *)keys
{
    return _keys;
}


-(id)initWithName:(NSString *)name keys:(NSString *)keys isUnique:(BOOL)isUnique
{
    self = [super init];
    
    if ( self )
    {
        _isUnique = isUnique;
        _name = name;
        _keys = keys;

    }
    
    return self;
}


+(NTJsonIndex *)indexWithName:(NSString *)name keys:(NSString *)keys  isUnique:(BOOL)isUnique
{
    return [[NTJsonIndex alloc] initWithName:name keys:keys isUnique:isUnique];
}


+(NTJsonIndex *)indexWithSql:(NSString *)sql
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@".*?\\[(.*?)\\].*?\\((.*?)\\)" options:0 error:0];
    
    NSTextCheckingResult *match = [regex firstMatchInString:sql options:0 range:NSMakeRange(0, sql.length)];
    
    if ( !match || match.numberOfRanges != 3 )
        return nil;
    
    NSString *name = [sql substringWithRange:[match rangeAtIndex:1]];
    NSString *keys = [sql substringWithRange:[match rangeAtIndex:2]];
    
    return [[NTJsonIndex alloc] initWithName:name keys:keys isUnique:[name hasPrefix:@"U"] ? YES : NO];
}


-(NSString *)sqlWithTableName:(NSString *)tableName
{
    return [NSString stringWithFormat:@"CREATE %@INDEX [%@] ON [%@] (%@);", (_isUnique) ? @"UNIQUE " : @"", _name, tableName, _keys];
}


@end

