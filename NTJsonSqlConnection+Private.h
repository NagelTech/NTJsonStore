//
//  NTJsonSqlConnection.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 4/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <sqlite3.h>

#import <Foundation/Foundation.h>


@interface NTJsonSqlConnection : NSObject

@property (nonatomic,readonly) NSString *filename;
@property (nonatomic,readonly) dispatch_queue_t queue;
@property (nonatomic,readonly) NSString *connectionName;
@property (nonatomic,readonly) NSError *lastError;

-(sqlite3 *)db;

-(id)initWithFilename:(NSString *)filename connectionName:(NSString *)connectionName;

-(sqlite3_stmt *)statementWithSql:(NSString *)sql args:(NSArray *)args;
-(BOOL)execSql:(NSString *)sql args:(NSArray *)args;
-(id)execValueSql:(NSString *)sql args:(NSArray *)args;

-(void)dispatchSync:(void (^)())block;
-(void)dispatchAsync:(void (^)())block;

@end
