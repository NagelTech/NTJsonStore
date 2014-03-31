//
//  NTJsonStore.h
//  NTJsonStoreSample
//
//  Created by Ethan Nagel on 3/25/14.
//  Copyright (c) 2014 NagelTech. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NTJsonStoreTypes.h"
#import "NTJsonCollection.h"


@interface NTJsonStore : NSObject

@property (nonatomic)               NSString *storePath;
@property (nonatomic)               NSString *storeName;

@property (nonatomic)               NSString *storeFilename;
@property (readonly,nonatomic)      BOOL exists;

@property (nonatomic,readonly)      NSArray *collections;


-(id)initWithName:(NSString *)storeName;

-(NTJsonCollection *)collectionWithName:(NSString *)collectionName;

-(BOOL)ensureSchema;

@end


