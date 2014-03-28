//
//  NTJsonCompressor.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/27/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>


@class NTJsonStore;


@interface NTJsonCompressor : NSObject

-(id)initWithStore:(NTJsonStore *)store collectionName:(NSString *)collectionName;

-(NSData *)compressJson:(NSDictionary *)json;
-(NSMutableDictionary *)uncompressData:(NSData *)data;


@end

