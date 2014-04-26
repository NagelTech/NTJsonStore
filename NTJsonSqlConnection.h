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
@property (nonatomic,readonly) sqlite3 *connection;

-(id)initWithFilename:(NSString *)filename;

-(sqlite3_stmt *)statementWithSql:(NSString *)sql args:(NSArray *)args;
-(BOOL)execSql:(NSString *)sql args:(NSArray *)args;

@end
