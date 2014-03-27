//
//  NTJsonIndex+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/27/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import "NTJsonIndex.h"


@interface NTJsonIndex (Private)

@property (nonatomic,readonly) BOOL isUnique;
@property (nonatomic,readonly) NSString *name;
@property (nonatomic,readonly) NSString *keys;

+(NTJsonIndex *)indexWithName:(NSString *)name keys:(NSString *)keys isUnique:(BOOL)isUnique;
+(NTJsonIndex *)indexWithSql:(NSString *)sql;

-(NSString *)sqlWithTableName:(NSString *)tableName;

@end
