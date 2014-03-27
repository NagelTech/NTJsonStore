//
//  NTJsonStore+Private.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/26/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>

#import "NSArray+NTJsonStore.h"
#import "NSDictionary+NTJsonStore.h"

#import "NTJsonStore.h"

#import "NTJsonCollection+Private.h"
#import "NTJsonColumn+Private.h"


@interface NTJsonStore (Private)

@property (readonly,assign)         sqlite3 *connection;

-(sqlite3_stmt *)statementWithSql:(NSString *)sql args:(NSArray *)args;
-(BOOL)execSql:(NSString *)sql args:(NSArray *)args;


@end
